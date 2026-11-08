// Scoring library for tdd's eval: run.mjs scores each finished agent run with it.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

export const compareRoot = dirname(fileURLToPath(import.meta.url));
export const tasks = {
  feature: { module: 'src/shipping.js', brief: 'docs/spec.md', criterionPattern: /^(C\d+):/ },
  bug: { module: 'src/cart.js', brief: 'docs/bug.md', criterionPattern: /^(B\d+):/ },
};

// Runs node:test with the TAP reporter and returns its leaf tests.
export function runTests(dir, files = []) {
  const result = spawnSync('node', ['--test', '--test-reporter=tap', ...files], {
    cwd: dir,
    encoding: 'utf8',
    timeout: 120_000,
  });
  return parseTap(`${result.stdout}\n${result.stderr}`);
}

export function parseTap(text) {
  const lines = text.split('\n');
  const tests = [];
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(/^\s*(ok|not ok) \d+ - (.*?)(?: # .*)?$/);
    if (!match) continue;
    const block = [];
    for (let j = i + 1; j < lines.length && !/^\s*(ok|not ok) \d+ - /.test(lines[j]); j += 1) {
      block.push(lines[j]);
      if (/^\s*\.\.\.\s*$/.test(lines[j])) break;
    }
    const yaml = block.join('\n');
    if (!/type: 'test'/.test(yaml)) continue;
    tests.push({
      name: match[2],
      ok: match[1] === 'ok',
      assertion: /name: 'AssertionError'|code: 'ERR_ASSERTION'/.test(yaml),
    });
  }
  return tests;
}

function withModule(workspace, task, implementation, extra = () => {}) {
  const dir = mkdtempSync(join(tmpdir(), 'tdd-score-'));
  cpSync(workspace, dir, {
    recursive: true,
    filter: (p) => !/(^|\/)(node_modules|\.git|\.claude)(\/|$)/.test(relative(workspace, p)),
  });
  if (implementation) cpSync(implementation, join(dir, tasks[task].module));
  extra(dir);
  return dir;
}

export function scoreWorkspace(workspace, task, originalNames) {
  const hidden = join(compareRoot, task, 'hidden');
  const finalDir = withModule(workspace, task, null);
  const final = runTests(finalDir);
  rmSync(finalDir, { recursive: true, force: true });
  const newTests = final.filter((t) => !originalNames.has(t.name));
  const passingOnFinal = new Set(final.filter((t) => t.ok).map((t) => t.name));

  const stubDir = withModule(workspace, task, join(hidden, 'stub.js'));
  const onStub = new Map(runTests(stubDir).map((t) => [t.name, t]));
  rmSync(stubDir, { recursive: true, force: true });
  const fakeRed = [];
  let reproductions = 0;
  for (const test of newTests) {
    const seen = onStub.get(test.name);
    if (seen && !seen.ok && seen.assertion) {
      reproductions += 1;
      continue;
    }
    // In the bug task a new test may pass on the unfixed code: it guards existing behavior.
    if (task === 'bug' && seen?.ok) continue;
    fakeRed.push({ name: test.name, onStub: seen ? (seen.ok ? 'passed' : 'non-assertion failure') : 'did not run' });
  }

  const mutantsDir = join(hidden, 'mutants');
  const mutants = readdirSync(mutantsDir).map((file) => {
    const dir = withModule(workspace, task, join(mutantsDir, file));
    // Only tests that pass on the agent's own code can catch a mutant.
    const caught = runTests(dir).some((t) => !t.ok && passingOnFinal.has(t.name));
    rmSync(dir, { recursive: true, force: true });
    return { mutant: basename(file, '.js'), caught };
  });

  const probeDir = withModule(workspace, task, null, (dir) => {
    mkdirSync(join(dir, 'probe'), { recursive: true });
    cpSync(join(hidden, 'criteria.test.js'), join(dir, 'probe', 'criteria.test.js'));
  });
  const criteria = {};
  for (const test of runTests(probeDir, ['probe/criteria.test.js'])) {
    const id = test.name.match(tasks[task].criterionPattern)?.[1];
    if (id) criteria[id] = (criteria[id] ?? true) && test.ok;
  }
  rmSync(probeDir, { recursive: true, force: true });

  return {
    finalTests: final.length,
    finalFailing: final.filter((t) => !t.ok).map((t) => t.name),
    newTests: newTests.map((t) => t.name),
    fakeRed,
    reproductions,
    mutants,
    criteria,
  };
}

const isTestFile = (path) => /(^|\/)(test|tests|__tests__)\/|\.test\.[cm]?[jt]s$/.test(path);

// Reads the final result event from the agent's stream for cost and model.
export function readTrace(tracePath) {
  let model = null;
  let apiKeySource = null;
  let final = null;
  for (const line of readFileSync(tracePath, 'utf8').split('\n')) {
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      continue;
    }
    if (event.type === 'system' && event.subtype === 'init') {
      model = event.model;
      apiKeySource = event.apiKeySource ?? null;
    }
    if (event.type === 'result') final = event;
  }
  return {
    model,
    apiKeySource,
    turns: final?.num_turns ?? null,
    costUsd: final?.total_cost_usd ?? null,
    usage: final?.usage ?? null,
    resultSubtype: final?.subtype ?? 'missing',
    permissionDenials: final?.permission_denials ?? [],
  };
}

// Reads the hook log: each test run's full TAP result and each edit, in order.
export function scoreSteps(stepsPath, task, newTests, originalNames) {
  const steps = [];
  const text = existsSync(stepsPath) ? readFileSync(stepsPath, 'utf8') : '';
  for (const chunk of text.split(/^=== /m).filter(Boolean)) {
    const [header, ...body] = chunk.split('\n');
    if (header === 'test-run') steps.push({ kind: 'run', tests: parseTap(body.join('\n')) });
    else if (header.startsWith('edit ')) steps.push({ kind: 'edit', file: header.slice(5) });
  }
  const runs = steps.filter((s) => s.kind === 'run');
  const firstRun = steps.findIndex((s) => s.kind === 'run');
  const seenFailing = newTests.filter((name) => runs.some((run) => run.tests.some((t) => t.name === name && !t.ok && t.assertion)));
  const sourceEdit = steps.findIndex((s) => s.kind === 'edit' && s.file.endsWith(tasks[task].module));
  const runsBeforeFix = steps.slice(0, sourceEdit === -1 ? steps.length : sourceEdit).filter((s) => s.kind === 'run');
  return {
    testRuns: runs.length,
    testEditsAfterFirstRun: firstRun === -1 ? 0
      : steps.slice(firstRun).filter((s) => s.kind === 'edit' && isTestFile(s.file)).length,
    newTestsSeenFailingOnAssertion: seenFailing.length,
    newTestsNeverSeenFailing: newTests.filter((name) => !seenFailing.includes(name)),
    failedOnAssertionBeforeSourceEdit: runsBeforeFix.some((run) => run.tests.some((t) => !t.ok && t.assertion && !originalNames.has(t.name))),
  };
}

// A grader that sees no skill name labels what each new test protects.
export function gradeTests(workspace, task, newTests, { env = process.env, model } = {}) {
  if (newTests.length === 0) return { reasonless: 0, labels: [] };
  const testFiles = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (['node_modules', '.git', '.claude'].includes(entry.name)) continue;
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (isTestFile(path.slice(workspace.length + 1))) testFiles.push(path);
    }
  };
  walk(workspace);
  const brief = readFileSync(join(workspace, tasks[task].brief), 'utf8');
  const sources = testFiles.map((f) => `--- ${f.slice(workspace.length + 1)}\n${readFileSync(f, 'utf8')}`).join('\n');
  const prompt = [
    'You grade tests written for the brief below. For each listed test name, say what it protects:',
    'a numbered acceptance criterion ("criterion N"), "bug" for reproducing the reported bug,',
    '"risk" for a real risk in logic the brief does not spell out, "existing" for existing behavior the change touches,',
    'or "none" when it protects nothing the brief or the code needs.',
    'Reply with only a JSON array of {"test": name, "label": label}.',
    `\nBrief:\n${brief}`,
    `\nTest files:\n${sources}`,
    `\nTests to label:\n${newTests.map((n) => `- ${n}`).join('\n')}`,
  ].join('\n');
  const cwd = mkdtempSync(join(tmpdir(), 'tdd-grade-'));
  const args = ['-p', prompt, '--output-format', 'json', '--setting-sources', 'project', '--tools', '', '--max-turns', '1'];
  if (model) args.push('--model', model);
  const result = spawnSync('claude', args, { cwd, env, encoding: 'utf8', timeout: 300_000 });
  rmSync(cwd, { recursive: true, force: true });
  try {
    const text = JSON.parse(result.stdout).result;
    const labels = JSON.parse(text.slice(text.indexOf('['), text.lastIndexOf(']') + 1));
    let usage = null;
    try { usage = JSON.parse(result.stdout).usage ?? null; } catch {}
    return { reasonless: labels.filter((l) => l.label === 'none').length, labels, usage };
  } catch {
    return { reasonless: null, labels: [], error: (result.stderr || result.stdout || '').slice(0, 400) };
  }
}

// Names of the tests each task's workspace carries before the agent starts.
export function originalTestNames(task) {
  return task === 'bug' ? new Set(runTests(join(compareRoot, 'bug', 'workspace')).map((t) => t.name)) : new Set();
}
