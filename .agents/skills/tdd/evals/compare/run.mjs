#!/usr/bin/env node
// Runner for tdd's eval in the llm-evals layout. See README.md beside this file.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import {
  compareRoot, gradeTests, originalTestNames, readTrace, scoreSteps, scoreWorkspace, tasks,
} from './score.mjs';

const repoRoot = resolve(compareRoot, '../../../../..');
const usage = `usage: run.mjs --variant baseline|v<N> --access api|subscription [options]
  --skill-ref <git-ref>   take tdd's SKILL.md from this ref (required for baseline)
  --skill-file <path>     take SKILL.md from this file (default: the working tree's)
  --cases feature,bug     cases to run (default: both)
  --reps <n>              runs per case (default: 3)
  --workers <n>           runs in parallel (default: 4)
  --model <id>            pin the agent and judge model
  --flow <dir>            flow folder (default: .claude/hillclimb/tdd under the repo root)
  --timeout-s <n>         wall-clock ceiling per run (default: 1200)
  --max-budget-usd <n>    per-run budget passed to claude (default: 5)
  --no-grade              skip the judge that labels tests protecting nothing
  --dry-run               print the resolved scope and stop`;

const { values: opts } = parseArgs({
  options: {
    variant: { type: 'string' },
    access: { type: 'string' },
    'skill-ref': { type: 'string' },
    'skill-file': { type: 'string' },
    cases: { type: 'string', default: 'feature,bug' },
    reps: { type: 'string', default: '3' },
    workers: { type: 'string', default: '4' },
    model: { type: 'string' },
    flow: { type: 'string' },
    'timeout-s': { type: 'string', default: '1200' },
    'max-budget-usd': { type: 'string', default: '5' },
    'no-grade': { type: 'boolean', default: false },
    'dry-run': { type: 'boolean', default: false },
    help: { type: 'boolean', default: false },
  },
});

function fail(message) {
  console.error(`${message}\n\n${usage}`);
  process.exit(2);
}

if (opts.help) {
  console.log(usage);
  process.exit(0);
}
if (!/^(baseline|v\d+)$/.test(opts.variant ?? '')) fail('--variant must be baseline or v<N>');
if (!['api', 'subscription'].includes(opts.access)) fail('--access must be api or subscription');
if (opts.variant === 'baseline' && !opts['skill-ref'] && !opts['skill-file']) {
  fail('baseline needs --skill-ref or --skill-file: the previous tdd text');
}
const cases = opts.cases.split(',').map((c) => c.trim()).filter(Boolean);
for (const c of cases) if (!tasks[c]) fail(`unknown case: ${c}`);
const reps = Number(opts.reps);
const workers = Number(opts.workers);
const timeoutMs = Number(opts['timeout-s']) * 1000;
if (!(reps >= 1) || !(workers >= 1) || !(timeoutMs > 0)) fail('--reps, --workers, and --timeout-s must be positive');

const flowDir = resolve(opts.flow ?? join(repoRoot, '.claude/hillclimb/tdd'));
const variantDir = join(flowDir, opts.variant);

// The skill text under test, and where it came from.
let skillText;
let skillSource;
if (opts['skill-ref']) {
  const shown = spawnSync('git', ['-C', repoRoot, 'show', `${opts['skill-ref']}:skills/workflow/tdd/SKILL.md`], { encoding: 'utf8' });
  if (shown.status !== 0) fail(`cannot read tdd SKILL.md at ${opts['skill-ref']}: ${shown.stderr.trim()}`);
  skillText = shown.stdout;
  const sha = spawnSync('git', ['-C', repoRoot, 'rev-parse', '--short', opts['skill-ref']], { encoding: 'utf8' }).stdout.trim();
  skillSource = `git ${opts['skill-ref']} (${sha})`;
} else {
  const file = resolve(opts['skill-file'] ?? join(repoRoot, 'skills/workflow/tdd/SKILL.md'));
  skillText = readFileSync(file, 'utf8');
  skillSource = `file ${file}`;
}
const skillSha = createHash('sha256').update(skillText).digest('hex').slice(0, 12);

// Model access: the API key goes to the child for api, and is cleared for a subscription.
function readEnvFile(path) {
  if (!existsSync(path)) return {};
  const found = {};
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (match) found[match[1]] = match[2].replace(/^(['"])(.*)\1$/, '$2');
  }
  return found;
}
const childEnv = { ...process.env };
if (opts.access === 'api') {
  if (!childEnv.ANTHROPIC_API_KEY) {
    const key = readEnvFile(join(repoRoot, '.env.local')).ANTHROPIC_API_KEY;
    if (key) childEnv.ANTHROPIC_API_KEY = key;
  }
  if (!childEnv.ANTHROPIC_API_KEY) {
    console.error('API access needs ANTHROPIC_API_KEY in the environment or in .env.local at the repo root.\nRun with --access subscription to use a logged-in Claude Code instead.');
    process.exit(3);
  }
} else {
  delete childEnv.ANTHROPIC_API_KEY;
  delete childEnv.ANTHROPIC_AUTH_TOKEN;
}

const prompts = {
  feature: '/tdd docs/spec.md에 적힌 배송비 계산 기능을 구현해줘.',
  bug: '/tdd docs/bug.md에 보고된 버그를 고쳐줘.',
};

function readRows(file) {
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
}

// One flow keeps one access and one model so its variants compare, including
// resumed runs; _state.json records both.
const stateFile = join(flowDir, '_state.json');
const pinnedModel = opts.model ?? null;
if (existsSync(stateFile)) {
  const state = JSON.parse(readFileSync(stateFile, 'utf8'));
  if (state.access && state.access !== opts.access) {
    console.error(`this flow runs on ${state.access}; this run asks for ${opts.access}. Use the same access or another --flow.`);
    process.exit(2);
  }
  if ('model' in state && state.model !== pinnedModel) {
    console.error(`this flow runs on model ${state.model ?? 'unpinned'}; this run asks for ${pinnedModel ?? 'unpinned'}. Use the same --model or another --flow.`);
    process.exit(2);
  }
  if (!('model' in state) && !opts['dry-run']) {
    writeFileSync(stateFile, `${JSON.stringify({ ...state, model: pinnedModel }, null, 2)}\n`);
  }
}
const resultsFile = join(variantDir, 'results.jsonl');
const errorsFile = join(variantDir, 'errors.jsonl');
const done = new Set(readRows(resultsFile).map((r) => `${r.prompt_id}#${r.rep}`));
const todo = [];
for (let rep = 0; rep < reps; rep += 1) {
  for (const c of cases) if (!done.has(`${c}#${rep}`)) todo.push({ c, rep });
}

console.log(`variant ${opts.variant}: tdd SKILL.md from ${skillSource} (sha ${skillSha})`);
console.log(`access ${opts.access}${opts.model ? `, model ${opts.model}` : ''}; ${cases.length} cases × ${reps} reps; ${done.size} done, ${todo.length} to run`);
const priced = readRows(resultsFile).filter((r) => typeof r.meta?.reported_cost_usd === 'number');
if (priced.length) {
  const mean = priced.reduce((n, r) => n + r.meta.reported_cost_usd, 0) / priced.length;
  console.log(`estimate from ${priced.length} finished runs: ~$${(mean * todo.length).toFixed(2)} ${opts.access === 'api' ? 'billed' : 'API equivalent, drawn from the subscription'}`);
}
if (opts['dry-run'] || todo.length === 0) process.exit(0);

// Comparing a text with itself spends a full run and proves nothing.
const baselineSummary = join(flowDir, 'baseline', 'summary.json');
if (opts.variant !== 'baseline' && existsSync(baselineSummary)) {
  const base = JSON.parse(readFileSync(baselineSummary, 'utf8'));
  if (base.skill_sha === skillSha) {
    console.error(`${opts.variant} has the same tdd SKILL.md as baseline (sha ${skillSha}); nothing to compare.`);
    process.exit(2);
  }
}
// A variant keeps one skill text so resumed rows stay comparable.
mkdirSync(join(variantDir, 'traces'), { recursive: true });
const summaryFile = join(variantDir, 'summary.json');
if (existsSync(summaryFile)) {
  const previous = JSON.parse(readFileSync(summaryFile, 'utf8'));
  if (previous.skill_sha !== skillSha) {
    console.error(`${opts.variant} already holds runs of skill sha ${previous.skill_sha}; this run is ${skillSha}. Use a new variant.`);
    process.exit(2);
  }
} else {
  writeFileSync(summaryFile, `${JSON.stringify({
    description: opts.variant === 'baseline' ? `baseline tdd from ${skillSource}` : `tdd from ${skillSource}`,
    target: 'skill',
    skill_source: skillSource,
    skill_sha: skillSha,
    access: opts.access,
  }, null, 2)}\n`);
}
if (!existsSync(stateFile)) {
  writeFileSync(stateFile, `${JSON.stringify({
    goal: 'tdd SKILL.md revision does not get worse than the baseline on any signal',
    split: 'none: two cases, scores are directional',
    access: opts.access,
    model: pinnedModel,
    reps,
    metrics: [
      { id: 'criteria_met', kind: 'float', label: 'Criteria met' },
      { id: 'mutants_caught', kind: 'float', label: 'Mutants caught' },
      { id: 'final_suite_passes', kind: 'float', label: 'Suite green' },
      { id: 'reproduced_before_fix', kind: 'float', label: 'Repro first' },
      { id: 'fake_red', kind: 'float', label: 'Fake reds', better: 'lower' },
      { id: 'never_seen_failing', kind: 'float', label: 'Unseen reds', better: 'lower' },
      { id: 'reasonless', kind: 'float', label: 'Reasonless', better: 'lower' },
    ],
    perf_fields: [
      { id: 'turns', label: 'Turns' },
      { id: 'latency_s', label: 'Latency', unit: 's' },
    ],
  }, null, 2)}\n`);
}

// Converts Claude Code's stream-json trace into llm-evals trace turns.
function toTurns(rawTrace, prompt) {
  const turns = [{ role: 'user', content: prompt }];
  const text = (content) => (typeof content === 'string' ? content
    : (content ?? []).map((part) => part.text ?? JSON.stringify(part)).join('\n'));
  for (const line of readFileSync(rawTrace, 'utf8').split('\n')) {
    let event;
    try { event = JSON.parse(line); } catch { continue; }
    if (event.type === 'assistant') {
      for (const part of event.message?.content ?? []) {
        if (part.type === 'text') turns.push({ role: 'assistant', content: part.text });
        if (part.type === 'tool_use') turns.push({ role: 'tool_call', name: part.name, content: JSON.stringify(part.input, null, 2) });
      }
    } else if (event.type === 'user') {
      for (const part of event.message?.content ?? []) {
        if (part.type === 'tool_result') turns.push({ role: 'tool_result', content: text(part.content).slice(0, 20_000) });
      }
    }
  }
  return turns;
}

function runAgent(workspace, prompt, rawTrace, stderrFile) {
  const args = [
    '-p', prompt, '--setting-sources', 'project', '--output-format', 'stream-json', '--verbose',
    '--max-budget-usd', opts['max-budget-usd'],
    '--allowedTools', 'Read', 'Edit', 'Write', 'Glob', 'Grep',
    'Bash(node:*)', 'Bash(npm:*)', 'Bash(ls:*)', 'Bash(cat:*)', 'Bash(mkdir:*)',
  ];
  if (opts.model) args.push('--model', opts.model);
  return new Promise((settle) => {
    const child = spawn('claude', args, { cwd: workspace, env: childEnv, stdio: ['ignore', 'pipe', 'pipe'] });
    const out = [];
    const err = [];
    child.stdout.on('data', (chunk) => out.push(chunk));
    child.stderr.on('data', (chunk) => err.push(chunk));
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
      setTimeout(() => child.kill('SIGKILL'), 10_000).unref();
    }, timeoutMs);
    child.on('close', (code) => {
      clearTimeout(timer);
      writeFileSync(rawTrace, Buffer.concat(out));
      writeFileSync(stderrFile, Buffer.concat(err));
      settle({ code, timedOut });
    });
  });
}

const originals = Object.fromEntries(cases.map((c) => [c, originalTestNames(c)]));

async function runCase({ c, rep }) {
  const id = `${c}_rep${rep}`;
  const runDir = join(variantDir, 'runs', id);
  // The workspace lives in the temp folder: under any .claude/ folder, headless
  // Claude Code treats every write as sensitive and denies it.
  const workspace = mkdtempSync(join(tmpdir(), `tdd-eval-${opts.variant}-${id}-`));
  // A run folder left by a crash is redone from scratch.
  rmSync(runDir, { recursive: true, force: true });
  mkdirSync(runDir, { recursive: true });
  rmSync(workspace, { recursive: true, force: true });
  cpSync(join(compareRoot, c, 'workspace'), workspace, { recursive: true });
  mkdirSync(join(workspace, '.claude/skills/tdd'), { recursive: true });
  writeFileSync(join(workspace, '.claude/skills/tdd/SKILL.md'), skillText);
  const stepsLog = join(runDir, 'steps.log');
  writeFileSync(join(workspace, '.claude/settings.json'), `${JSON.stringify({
    hooks: { PostToolUse: [{ matcher: 'Bash|Edit|Write|MultiEdit',
      hooks: [{ type: 'command', command: `bash '${join(compareRoot, 'record-step.sh')}' '${stepsLog}'` }] }] },
  }, null, 2)}\n`);
  for (const step of [['init', '-q'], ['add', '-A'], ['-c', 'user.name=eval', '-c', 'user.email=eval@example.com', 'commit', '-q', '-m', 'fixture']]) {
    spawnSync('git', ['-C', workspace, ...step]);
  }

  const rawTrace = join(runDir, 'trace.jsonl');
  const started = Date.now();
  const { code, timedOut } = await runAgent(workspace, prompts[c], rawTrace, join(runDir, 'stderr.txt'));
  const latency = (Date.now() - started) / 1000;
  const trace = readTrace(rawTrace);
  writeFileSync(join(variantDir, 'traces', `${id}.json`), `${JSON.stringify(toTurns(rawTrace, prompts[c]), null, 2)}\n`);

  writeFileSync(join(runDir, 'workspace.txt'), `${workspace}\n`);
  const errorRow = (failureClass, detail) => appendFileSync(errorsFile, `${JSON.stringify({
    prompt_id: c, rep, class: failureClass, detail, exit_code: code, latency_s: latency, workspace,
    model: trace.model, usage: trace.usage, reported_cost_usd: trace.costUsd, at: new Date().toISOString(),
  })}\n`);
  if (timedOut) return errorRow('timeout', `no result within ${opts['timeout-s']}s`);
  if (trace.resultSubtype !== 'success') return errorRow('harness', `result ${trace.resultSubtype}`);
  // A denied file write means the agent could not work at all, which is the
  // harness's fault. Shell commands outside the allowlist are the same
  // constraint for every variant, so those runs are scored.
  const deniedWrites = trace.permissionDenials.filter((d) => /^(Write|Edit|MultiEdit|NotebookEdit)$/.test(d.tool_name));
  if (deniedWrites.length) {
    return errorRow('harness', `file writes denied: ${deniedWrites.map((d) => d.tool_input?.file_path).join(', ')}`);
  }
  if (opts.model && !trace.model?.startsWith(opts.model)) {
    return errorRow('served-model-mismatch', `asked ${opts.model}, served ${trace.model ?? 'unknown'}`);
  }
  const expectedKeySource = opts.access === 'api' ? 'ANTHROPIC_API_KEY' : 'none';
  if (trace.apiKeySource !== expectedKeySource) {
    return errorRow('access-mismatch', `asked ${opts.access}, Claude Code reported key source ${trace.apiKeySource ?? 'unknown'}`);
  }

  const scored = scoreWorkspace(workspace, c, originals[c]);
  const steps = scoreSteps(stepsLog, c, scored.newTests, originals[c]);
  const graded = opts['no-grade'] ? null : gradeTests(workspace, c, scored.newTests, { env: childEnv, model: opts.model });
  const criteriaIds = Object.keys(scored.criteria);
  const grade = {
    criteria_met: criteriaIds.length ? criteriaIds.filter((k) => scored.criteria[k]).length / criteriaIds.length : 0,
    mutants_caught: scored.mutants.length ? scored.mutants.filter((m) => m.caught).length / scored.mutants.length : 0,
    final_suite_passes: scored.finalFailing.length === 0 ? 1 : 0,
    fake_red: scored.fakeRed.length,
    never_seen_failing: steps.newTestsNeverSeenFailing.length,
  };
  if (c === 'bug') grade.reproduced_before_fix = steps.failedOnAssertionBeforeSourceEdit ? 1 : 0;
  if (graded && graded.reasonless != null) grade.reasonless = graded.reasonless;
  appendFileSync(resultsFile, `${JSON.stringify({
    prompt_id: c,
    rep,
    prompt: prompts[c],
    tags: [c, c === 'feature' ? 'new behavior' : 'bug fix'],
    grade,
    status: 'ok',
    stop_reason: trace.resultSubtype,
    model: trace.model,
    usage: trace.usage,
    judge_usage: graded?.usage ?? null,
    turns: trace.turns,
    latency_s: latency,
    meta: { ...scored, steps, denied_commands: trace.permissionDenials.length, labels: graded?.labels ?? null, grading_error: graded?.error ?? null, reported_cost_usd: trace.costUsd },
  })}\n`);
  console.log(`${id}: criteria ${grade.criteria_met.toFixed(2)}, mutants ${grade.mutants_caught.toFixed(2)}, unseen reds ${grade.never_seen_failing}, ${latency.toFixed(0)}s`);
}

let next = 0;
await Promise.all(Array.from({ length: Math.min(workers, todo.length) }, async () => {
  while (next < todo.length) {
    const item = todo[next];
    next += 1;
    try {
      await runCase(item);
    } catch (error) {
      appendFileSync(errorsFile, `${JSON.stringify({ prompt_id: item.c, rep: item.rep, class: 'harness', detail: String(error?.stack ?? error).slice(0, 2000), at: new Date().toISOString() })}\n`);
      console.error(`${item.c}_rep${item.rep}: harness error, see errors.jsonl`);
    }
  }
}));
console.log(`results: ${resultsFile}`);
