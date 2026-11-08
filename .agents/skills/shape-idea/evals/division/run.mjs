#!/usr/bin/env node
// Runner for shape-idea's folder-division eval in the llm-evals layout. See README.md.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { collectFolders, judgeAssignment, readStream, scoreDivision } from './grade.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const skillsRoot = resolve(here, '../../../..');
const repoRoot = resolve(skillsRoot, '..');
const usage = `usage: run.mjs --variant baseline|v<N> --access api|subscription [options]
  --skill-ref <git-ref>   take shape-idea's SKILL.md from this ref (required for baseline)
  --skill-file <path>     take SKILL.md from this file (default: the working tree's)
  --set held_out|train|regression   case set (default: held_out)
  --cases a,b             run only these case ids
  --reps <n>              runs per case (default: 2)
  --workers <n>           runs in parallel (default: 4)
  --model <id>            agent model (default: claude-opus-5-5)
  --judge-model <id>      judge model (default: claude-sonnet-5-5)
  --flow <dir>            flow folder (default: .claude/hillclimb/shape-idea-division)
  --timeout-s <n>         wall-clock ceiling per turn (default: 900)
  --max-budget-usd <n>    per-turn budget passed to claude (default: 4)
  --dry-run               print the resolved scope and stop`;

const { values: opts } = parseArgs({
  options: {
    variant: { type: 'string' },
    access: { type: 'string' },
    'skill-ref': { type: 'string' },
    'skill-file': { type: 'string' },
    set: { type: 'string', default: 'held_out' },
    cases: { type: 'string' },
    reps: { type: 'string', default: '2' },
    workers: { type: 'string', default: '4' },
    model: { type: 'string', default: 'claude-opus-5-5' },
    'judge-model': { type: 'string', default: 'claude-sonnet-5-5' },
    flow: { type: 'string' },
    'timeout-s': { type: 'string', default: '900' },
    'max-budget-usd': { type: 'string', default: '4' },
    'dry-run': { type: 'boolean', default: false },
    help: { type: 'boolean', default: false },
  },
});

function fail(message) {
  console.error(`${message}\n\n${usage}`);
  process.exit(2);
}
if (opts.help) { console.log(usage); process.exit(0); }
if (!/^(baseline|v\d+)$/.test(opts.variant ?? '')) fail('--variant must be baseline or v<N>');
if (!['api', 'subscription'].includes(opts.access)) fail('--access must be api or subscription');
if (opts.variant === 'baseline' && !opts['skill-ref'] && !opts['skill-file']) fail('baseline needs --skill-ref or --skill-file');
const caseFile = JSON.parse(readFileSync(join(here, 'cases.json'), 'utf8'));
if (!caseFile[opts.set]) fail(`unknown set: ${opts.set}`);
let cases = caseFile[opts.set];
if (opts.cases) {
  const wanted = opts.cases.split(',').map((c) => c.trim());
  for (const id of wanted) if (!cases.some((c) => c.id === id)) fail(`unknown case in ${opts.set}: ${id}`);
  cases = cases.filter((c) => wanted.includes(c.id));
}
if (opts.set === 'regression') {
  const shapeEvals = JSON.parse(readFileSync(join(here, '..', 'evals.json'), 'utf8')).evals;
  cases = cases.map((c) => ({ ...c, prompt: shapeEvals.find((e) => e.id === c.eval_id).prompt }));
}
const reps = Number(opts.reps);
const workers = Number(opts.workers);
const timeoutMs = Number(opts['timeout-s']) * 1000;

// The shape-idea text under test.
let skillText;
let skillSource;
if (opts['skill-ref']) {
  const shown = spawnSync('git', ['-C', repoRoot, 'show', `${opts['skill-ref']}:skills/workflow/shape-idea/SKILL.md`], { encoding: 'utf8' });
  if (shown.status !== 0) fail(`cannot read shape-idea SKILL.md at ${opts['skill-ref']}: ${shown.stderr.trim()}`);
  skillText = shown.stdout;
  const sha = spawnSync('git', ['-C', repoRoot, 'rev-parse', '--short', opts['skill-ref']], { encoding: 'utf8' }).stdout.trim();
  skillSource = `git ${opts['skill-ref']} (${sha})`;
} else {
  const file = resolve(opts['skill-file'] ?? join(skillsRoot, 'workflow/shape-idea/SKILL.md'));
  skillText = readFileSync(file, 'utf8');
  skillSource = `file ${file}`;
}
const skillSha = createHash('sha256').update(skillText).digest('hex').slice(0, 12);

// Model access: the key goes to the child for api, and is cleared for a subscription.
const childEnv = { ...process.env };
if (opts.access === 'api') {
  if (!childEnv.ANTHROPIC_API_KEY && existsSync(join(repoRoot, '.env.local'))) {
    const m = readFileSync(join(repoRoot, '.env.local'), 'utf8').match(/^\s*ANTHROPIC_API_KEY\s*=\s*['"]?([^'"\n]+)/m);
    if (m) childEnv.ANTHROPIC_API_KEY = m[1];
  }
  if (!childEnv.ANTHROPIC_API_KEY) { console.error('API access needs ANTHROPIC_API_KEY in the environment or .env.local.'); process.exit(3); }
} else {
  delete childEnv.ANTHROPIC_API_KEY;
  delete childEnv.ANTHROPIC_AUTH_TOKEN;
}

const approval = '좋아, 제안한 대로 승인할게. 남은 질문이 있었다면 네 추천안대로 정하고, 이제 spec을 써줘.';
const flowDir = resolve(opts.flow ?? join(repoRoot, '.claude/hillclimb/shape-idea-division'));
const variantDir = join(flowDir, opts.variant);
const resultsFile = join(variantDir, 'results.jsonl');
const errorsFile = join(variantDir, 'errors.jsonl');
const readRows = (file) => (existsSync(file) ? readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)) : []);

// One flow keeps one access and one model so its variants compare.
const stateFile = join(flowDir, '_state.json');
if (existsSync(stateFile)) {
  const state = JSON.parse(readFileSync(stateFile, 'utf8'));
  if (state.access !== opts.access) { console.error(`this flow runs on ${state.access}; use the same access or another --flow.`); process.exit(2); }
  if (state.model !== opts.model) { console.error(`this flow runs on model ${state.model}; use the same --model or another --flow.`); process.exit(2); }
}
const done = new Set(readRows(resultsFile).map((r) => `${r.prompt_id}#${r.rep}`));
const todo = [];
for (let rep = 0; rep < reps; rep += 1) for (const c of cases) if (!done.has(`${c.id}#${rep}`)) todo.push({ c, rep });

console.log(`variant ${opts.variant}: shape-idea SKILL.md from ${skillSource} (sha ${skillSha})`);
console.log(`access ${opts.access}, model ${opts.model}, judge ${opts['judge-model']}; set ${opts.set}: ${cases.length} cases × ${reps} reps; ${done.size} done, ${todo.length} to run`);
const priced = readRows(resultsFile).filter((r) => typeof r.meta?.cost_usd === 'number');
if (priced.length) {
  const mean = priced.reduce((n, r) => n + r.meta.cost_usd, 0) / priced.length;
  console.log(`estimate from ${priced.length} finished runs: ~$${(mean * todo.length).toFixed(2)} ${opts.access === 'api' ? 'billed' : 'API equivalent, drawn from the subscription'}`);
}
if (opts['dry-run'] || todo.length === 0) process.exit(0);

mkdirSync(join(variantDir, 'traces'), { recursive: true });
const summaryFile = join(variantDir, 'summary.json');
if (existsSync(summaryFile)) {
  const previous = JSON.parse(readFileSync(summaryFile, 'utf8'));
  if (previous.skill_sha !== skillSha) { console.error(`${opts.variant} already holds runs of skill sha ${previous.skill_sha}; this run is ${skillSha}. Use a new variant.`); process.exit(2); }
} else {
  writeFileSync(summaryFile, `${JSON.stringify({ description: `shape-idea from ${skillSource}`, target: 'skill', skill_source: skillSource, skill_sha: skillSha, access: opts.access }, null, 2)}\n`);
}
if (!existsSync(stateFile)) {
  writeFileSync(stateFile, `${JSON.stringify({
    goal: 'shape-idea divides a shaped change into spec folders and Blocked by edges exactly as expected; target 9 of 10 held-out cases and no over-division',
    split: { train: caseFile.train.map((c) => c.id), test: caseFile.held_out.map((c) => c.id), regression: caseFile.regression.map((c) => c.id) },
    access: opts.access,
    model: opts.model,
    judge_model: opts['judge-model'],
    metrics: [
      { id: 'exact', kind: 'float', label: 'Exact division' },
      { id: 'over_split', kind: 'float', label: 'Over-division', better: 'lower' },
      { id: 'wrote_before_approval', kind: 'float', label: 'Wrote several before approval', better: 'lower' },
      { id: 'single_folder', kind: 'float', label: 'Regression: one folder' },
    ],
    perf_fields: [{ id: 'turns', label: 'Turns' }, { id: 'latency_s', label: 'Latency', unit: 's' }],
  }, null, 2)}\n`);
}

const skillDirs = ['project-knowledge', 'add-stack-context', 'explain-visually', 'build-prototype', 'shape-idea'];

function prepareWorkspace(id) {
  // Outside any .claude/ folder: headless Claude Code denies writes under one.
  const ws = mkdtempSync(join(tmpdir(), `shape-division-${opts.variant}-${id}-`));
  writeFileSync(join(ws, 'README.md'), '# Product repository\n\nThe product code lives in other repositories. This repository holds product decisions and specs.\n');
  for (const name of skillDirs) {
    const target = join(ws, '.claude/skills', name);
    cpSync(join(skillsRoot, 'workflow', name), target, {
      recursive: true,
      filter: (src) => !/\/(evals|agents)(\/|$)/.test(src.slice(join(skillsRoot, 'workflow', name).length)),
    });
  }
  writeFileSync(join(ws, '.claude/skills/shape-idea/SKILL.md'), skillText);
  for (const step of [['init', '-q'], ['add', '-A'], ['-c', 'user.name=eval', '-c', 'user.email=eval@example.com', 'commit', '-q', '-m', 'fixture']]) {
    spawnSync('git', ['-C', ws, ...step]);
  }
  return ws;
}

function runClaude(workspace, prompt, sessionId, rawFile) {
  const args = ['-p', prompt, '--setting-sources', 'project', '--output-format', 'stream-json', '--verbose',
    '--max-budget-usd', opts['max-budget-usd'], '--permission-mode', 'acceptEdits', '--model', opts.model,
    '--allowedTools', 'Read', 'Edit', 'Write', 'Glob', 'Grep', 'Skill',
    'Bash(ls:*)', 'Bash(cat:*)', 'Bash(mkdir:*)', 'Bash(git:*)', 'Bash(find:*)', 'Bash(grep:*)'];
  if (sessionId) args.push('--resume', sessionId);
  return new Promise((settle) => {
    const child = spawn('claude', args, { cwd: workspace, env: childEnv, stdio: ['ignore', 'pipe', 'pipe'] });
    const out = [];
    const err = [];
    child.stdout.on('data', (c) => out.push(c));
    child.stderr.on('data', (c) => err.push(c));
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); setTimeout(() => child.kill('SIGKILL'), 10_000).unref(); }, timeoutMs);
    child.on('close', (code) => {
      clearTimeout(timer);
      const raw = Buffer.concat(out).toString('utf8');
      writeFileSync(rawFile, raw);
      settle({ code, timedOut, info: readStream(raw), stderr: Buffer.concat(err).toString('utf8') });
    });
  });
}

function toTurns(rawFiles, prompts) {
  const turns = [];
  rawFiles.forEach((file, i) => {
    turns.push({ role: 'user', content: prompts[i] });
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      let e;
      try { e = JSON.parse(line); } catch { continue; }
      if (e.type === 'assistant') {
        for (const p of e.message?.content ?? []) {
          if (p.type === 'text') turns.push({ role: 'assistant', content: p.text });
          if (p.type === 'tool_use') turns.push({ role: 'tool_call', name: p.name, content: JSON.stringify(p.input, null, 2).slice(0, 20_000) });
        }
      } else if (e.type === 'user') {
        for (const p of e.message?.content ?? []) {
          if (p.type === 'tool_result') {
            const text = typeof p.content === 'string' ? p.content : (p.content ?? []).map((x) => x.text ?? '').join('\n');
            turns.push({ role: 'tool_result', content: text.slice(0, 20_000) });
          }
        }
      }
    }
  });
  return turns;
}

async function runCase({ c, rep }) {
  const id = `${c.id}_rep${rep}`;
  const runDir = join(variantDir, 'runs', id);
  rmSync(runDir, { recursive: true, force: true });
  mkdirSync(runDir, { recursive: true });
  const workspace = prepareWorkspace(id);
  writeFileSync(join(runDir, 'workspace.txt'), `${workspace}\n`);
  const started = Date.now();
  const errorRow = (cls, detail, info) => appendFileSync(errorsFile, `${JSON.stringify({
    prompt_id: c.id, rep, class: cls, detail, workspace, model: info?.model ?? null, usage: info?.usage ?? null, at: new Date().toISOString(),
  })}\n`);

  const raw1 = join(runDir, 'turn1.jsonl');
  const t1 = await runClaude(workspace, c.prompt, null, raw1);
  if (t1.timedOut) return errorRow('timeout', 'turn 1', t1.info);
  if (t1.info.resultSubtype !== 'success') return errorRow('harness', `turn 1 result ${t1.info.resultSubtype}: ${t1.stderr.slice(0, 300)}`, t1.info);
  if (!t1.info.model?.startsWith(opts.model)) return errorRow('served-model-mismatch', `asked ${opts.model}, served ${t1.info.model}`, t1.info);
  const expectedKey = opts.access === 'api' ? 'ANTHROPIC_API_KEY' : 'none';
  if (t1.info.apiKeySource !== expectedKey) return errorRow('access-mismatch', `key source ${t1.info.apiKeySource}`, t1.info);
  const deniedWrites = t1.info.permissionDenials.filter((d) => /^(Write|Edit|MultiEdit)$/.test(d.tool_name));
  if (deniedWrites.length) return errorRow('harness', `file writes denied: ${deniedWrites.map((d) => d.tool_input?.file_path).join(', ')}`, t1.info);

  const afterTurn1 = collectFolders(workspace);
  const rawFiles = [raw1];
  const prompts = [c.prompt];
  let last = t1;
  let cost = t1.info.costUsd ?? 0;
  if (afterTurn1.length === 0) {
    const raw2 = join(runDir, 'turn2.jsonl');
    const t2 = await runClaude(workspace, approval, t1.info.sessionId, raw2);
    rawFiles.push(raw2);
    prompts.push(approval);
    if (t2.timedOut) return errorRow('timeout', 'turn 2', t2.info);
    if (t2.info.resultSubtype !== 'success') return errorRow('harness', `turn 2 result ${t2.info.resultSubtype}: ${t2.stderr.slice(0, 300)}`, t2.info);
    const denied2 = t2.info.permissionDenials.filter((d) => /^(Write|Edit|MultiEdit)$/.test(d.tool_name));
    if (denied2.length) return errorRow('harness', `file writes denied: ${denied2.map((d) => d.tool_input?.file_path).join(', ')}`, t2.info);
    last = t2;
    cost += t2.info.costUsd ?? 0;
  }
  const latency = (Date.now() - started) / 1000;
  writeFileSync(join(variantDir, 'traces', `${id}.json`), `${JSON.stringify(toTurns(rawFiles, prompts), null, 2)}\n`);

  const folders = collectFolders(workspace);
  const grade = {};
  let meta = { turns_used: rawFiles.length, folders: folders.map((f) => ({ slug: f.slug, blocked_by: f.blockedBy })), turn1_folders: afterTurn1.map((f) => f.slug), cost_usd: cost };
  if (opts.set === 'regression') {
    grade.single_folder = folders.length === 1 ? 1 : 0;
  } else {
    grade.wrote_before_approval = afterTurn1.length > 1 ? 1 : 0;
    if (folders.length === 0) {
      Object.assign(grade, { exact: 0, over_split: 0 });
      meta.problems = ['no spec folder written'];
    } else {
      const judged = judgeAssignment(c, folders, { env: childEnv, model: opts['judge-model'] });
      if (judged.error) return errorRow('judge', judged.error, last.info);
      const scored = scoreDivision(c, folders, judged.assignment);
      grade.exact = scored.exact;
      grade.over_split = scored.over_split;
      meta = { ...meta, ...scored, judge_model: judged.model, judge_usage: judged.usage, judge_cost_usd: judged.cost };
    }
  }
  appendFileSync(resultsFile, `${JSON.stringify({
    prompt_id: c.id, rep, prompt: c.prompt, tags: c.tags, grade, status: 'ok', stop_reason: last.info.resultSubtype,
    model: t1.info.model, usage: last.info.usage, turns: (t1.info.turns ?? 0) + (last === t1 ? 0 : last.info.turns ?? 0), latency_s: latency, meta,
  })}\n`);
  console.log(`${id}: ${JSON.stringify(grade)} folders=${folders.map((f) => f.slug).join(',') || '-'} ${latency.toFixed(0)}s`);
}

let next = 0;
await Promise.all(Array.from({ length: Math.min(workers, todo.length) }, async () => {
  while (next < todo.length) {
    const item = todo[next];
    next += 1;
    try {
      await runCase(item);
    } catch (error) {
      appendFileSync(errorsFile, `${JSON.stringify({ prompt_id: item.c.id, rep: item.rep, class: 'harness', detail: String(error?.stack ?? error).slice(0, 2000), at: new Date().toISOString() })}\n`);
      console.error(`${item.c.id}_rep${item.rep}: harness error, see errors.jsonl`);
    }
  }
}));
console.log(`results: ${resultsFile}`);
