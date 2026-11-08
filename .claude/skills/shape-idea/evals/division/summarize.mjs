#!/usr/bin/env node
// Prints each variant's mean metrics per case set from results.jsonl.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const flow = resolve(process.argv[2] ?? join(process.cwd(), '.claude/hillclimb/shape-idea-division'));
const state = JSON.parse(readFileSync(join(flow, '_state.json'), 'utf8'));
const setOf = (id) => Object.entries(state.split).find(([, ids]) => ids.includes(id))?.[0] ?? '?';
for (const variant of readdirSync(flow).filter((d) => /^(baseline|v\d+)$/.test(d)).sort()) {
  const file = join(flow, variant, 'results.jsonl');
  if (!existsSync(file)) continue;
  const rows = readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
  const errors = existsSync(join(flow, variant, 'errors.jsonl')) ? readFileSync(join(flow, variant, 'errors.jsonl'), 'utf8').split('\n').filter(Boolean).length : 0;
  console.log(`\n== ${variant} (${rows.length} runs, ${errors} errors)`);
  for (const set of ['test', 'train', 'regression']) {
    const inSet = rows.filter((r) => setOf(r.prompt_id) === set);
    if (!inSet.length) continue;
    const metrics = [...new Set(inSet.flatMap((r) => Object.keys(r.grade)))];
    const means = metrics.map((m) => {
      const vals = inSet.map((r) => r.grade[m]).filter((v) => typeof v === 'number');
      return `${m}=${(vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(2)} (${vals.filter((v) => v === 1).length}/${vals.length})`;
    });
    console.log(`  ${set}: ${means.join(', ')}`);
    const byRep = {};
    for (const r of inSet) if ('exact' in r.grade) (byRep[r.rep] ??= []).push(r.grade.exact);
    for (const [rep, vals] of Object.entries(byRep)) console.log(`    rep ${rep}: exact ${vals.filter((v) => v === 1).length}/${vals.length}`);
    for (const r of inSet.sort((a, b) => a.prompt_id.localeCompare(b.prompt_id) || a.rep - b.rep)) {
      console.log(`    ${r.prompt_id}#${r.rep} ${JSON.stringify(r.grade)} ${(Array.isArray(r.meta.folders) ? r.meta.folders : Object.keys(r.meta.delivered ?? {}).map((slug) => ({ slug, blocked_by: [] }))).map((f) => f.slug + (f.blocked_by.length ? `<-${f.blocked_by.join('+')}` : '')).join(' ')}${r.meta.problems?.length ? `  | ${r.meta.problems.join('; ')}` : ''}`);
    }
  }
}
