#!/usr/bin/env node
// Compares two variants of tdd's eval: node compare.mjs [--flow <dir>] [--base baseline] [--next v<N>]
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { compareRoot } from './score.mjs';

const { values: opts } = parseArgs({
  options: { flow: { type: 'string' }, base: { type: 'string', default: 'baseline' }, next: { type: 'string' } },
});
const flowDir = resolve(opts.flow ?? join(compareRoot, '../../../../..', '.claude/hillclimb/tdd'));
const variants = existsSync(flowDir) ? readdirSync(flowDir).filter((d) => /^v\d+$/.test(d)) : [];
const nextName = opts.next ?? variants.sort((a, b) => Number(a.slice(1)) - Number(b.slice(1))).at(-1);
if (!nextName) {
  console.error(`no v<N> variant under ${flowDir} to compare with ${opts.base}`);
  process.exit(2);
}

const rows = (variant, file) => {
  const path = join(flowDir, variant, file);
  return existsSync(path) ? readFileSync(path, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)) : [];
};
const tokens = (u) => (u ? (u.input_tokens ?? 0) + (u.output_tokens ?? 0)
  + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) : 0);

// Mean and 95% interval half-width of one metric over a variant's runs.
function spread(values) {
  if (values.length === 0) return null;
  const mean = values.reduce((n, v) => n + v, 0) / values.length;
  const sd = values.length > 1 ? Math.sqrt(values.reduce((n, v) => n + (v - mean) ** 2, 0) / (values.length - 1)) : 0;
  return { n: values.length, mean: Number(mean.toFixed(3)), ci95: Number((1.96 * sd / Math.sqrt(values.length)).toFixed(3)) };
}

function summarize(variant) {
  const ok = rows(variant, 'results.jsonl').filter((r) => r.status === 'ok');
  const errors = rows(variant, 'errors.jsonl');
  const succeeded = new Set(ok.map((r) => `${r.prompt_id}#${r.rep}`));
  const metrics = {};
  for (const id of [...new Set(ok.flatMap((r) => Object.keys(r.grade)))]) {
    metrics[id] = spread(ok.filter((r) => typeof r.grade[id] === 'number').map((r) => r.grade[id]));
  }
  const criteriaMet = {};
  for (const r of ok) {
    for (const [id, met] of Object.entries(r.meta.criteria)) {
      const key = `${r.prompt_id}:${id}`;
      criteriaMet[key] = (criteriaMet[key] ?? 0) + (met ? 1 : 0);
    }
  }
  const bug = ok.filter((r) => r.prompt_id === 'bug');
  return {
    runs: Object.fromEntries(['feature', 'bug'].map((c) => [c, ok.filter((r) => r.prompt_id === c).length])),
    failedAttempts: errors.filter((e) => !succeeded.has(`${e.prompt_id}#${e.rep}`)).length,
    metrics,
    criteriaMet,
    newTests: ok.reduce((n, r) => n + r.meta.newTests.length, 0),
    fakeRed: ok.reduce((n, r) => n + r.meta.fakeRed.length, 0),
    mutantsCaught: ok.reduce((n, r) => n + r.meta.mutants.filter((m) => m.caught).length, 0),
    mutantsTotal: ok.reduce((n, r) => n + r.meta.mutants.length, 0),
    newTestsNeverSeenFailing: ok.reduce((n, r) => n + r.meta.steps.newTestsNeverSeenFailing.length, 0),
    bugRunsFailingBeforeFix: bug.filter((r) => r.meta.steps.failedOnAssertionBeforeSourceEdit).length,
    bugRuns: bug.length,
    runsWithFailingFinalSuite: ok.filter((r) => r.meta.finalFailing.length > 0).length,
    reasonless: ok.every((r) => typeof r.grade.reasonless === 'number') ? ok.reduce((n, r) => n + r.grade.reasonless, 0) : null,
    turns: ok.reduce((n, r) => n + (r.turns ?? 0), 0),
    tokens: ok.reduce((n, r) => n + tokens(r.usage), 0),
    reportedCostUsd: Number(ok.reduce((n, r) => n + (r.meta.reported_cost_usd ?? 0), 0).toFixed(2)),
    models: [...new Set(ok.map((r) => r.model))],
  };
}

const base = summarize(opts.base);
const next = summarize(nextName);
const majority = (count, total) => count * 3 >= total * 2;
const servedModels = [...new Set([...base.models, ...next.models])];
const gates = {
  sameModel: servedModels.length === 1,
  comparableRuns: ['feature', 'bug'].every((c) => base.runs[c] > 0 && base.runs[c] === next.runs[c]),
  criteriaKept: Object.keys(base.criteriaMet)
    .filter((key) => majority(base.criteriaMet[key], base.runs[key.split(':')[0]]))
    .every((key) => majority(next.criteriaMet[key] ?? 0, next.runs[key.split(':')[0]])),
  finalSuitesPass: next.runsWithFailingFinalSuite === 0,
  fakeRedNotWorse: next.fakeRed <= base.fakeRed,
  mutantsNotWorse: next.mutantsCaught >= base.mutantsCaught,
  everyNewTestSeenFailing: next.newTestsNeverSeenFailing === 0,
  bugReproducedBeforeFix: next.bugRunsFailingBeforeFix === next.bugRuns,
};
gates.pass = Object.values(gates).every(Boolean);
const runsPerVariant = next.runs.feature + next.runs.bug;
const report = {
  base: opts.base,
  next: nextName,
  noiseFloor: `two cases, directional only; a pass rate over ${runsPerVariant} runs carries about ±${Math.round(100 / Math.sqrt(Math.max(runsPerVariant, 1)))} points`,
  summary: { [opts.base]: base, [nextName]: next },
  gates,
};
writeFileSync(join(flowDir, 'comparison.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
