#!/usr/bin/env node
// Pushes reference, empty, and constant divisions through the judge and scorer.
// Reference divisions should score about 100%, the others about 0% on multi-folder cases.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { judgeAssignment, scoreDivision } from './grade.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const { held_out: heldOut, train } = JSON.parse(readFileSync(join(here, 'cases.json'), 'utf8'));
const env = { ...process.env };
if (process.argv.includes('--subscription')) { delete env.ANTHROPIC_API_KEY; delete env.ANTHROPIC_AUTH_TOKEN; }
const model = 'claude-sonnet-5-5';

const spec = (title, outcomes, extra = '') => `# ${title}\n\n${extra}## 사용자에게 보이는 결과\n\n${outcomes.map((o) => `- ${o}`).join('\n')}\n\n## Setup before implementation\n\nNone.\n`;

function reference(c) {
  const slugs = c.expected.groups.map((g) => g.join('-'));
  return c.expected.groups.map((group, i) => {
    const blockers = c.expected.edges.filter(([dep]) => dep === i).map(([, b]) => `Blocked by: docs/specs/${slugs[b]}/\n\n`).join('');
    return { slug: slugs[i], blockedBy: c.expected.edges.filter(([dep]) => dep === i).map(([, b]) => slugs[b]), text: spec(slugs[i], group.map((id) => c.items[id]), blockers) };
  });
}
function constant(c) {
  return [{ slug: 'all', blockedBy: [], text: spec('all', Object.values(c.items)) }];
}

const rows = [];
for (const c of [...heldOut, ...train]) {
  for (const [kind, folders] of [['reference', reference(c)], ['constant', constant(c)]]) {
    const judged = judgeAssignment(c, folders, { env, model });
    if (judged.error) { rows.push({ case: c.id, kind, error: judged.error }); continue; }
    const s = scoreDivision(c, folders, judged.assignment);
    rows.push({ case: c.id, kind, exact: s.exact, problems: s.problems });
  }
  rows.push({ case: c.id, kind: 'empty', exact: 0, problems: ['no folders: the runner scores 0 without calling the judge'] });
}
for (const r of rows) console.log(JSON.stringify(r));
const ref = rows.filter((r) => r.kind === 'reference');
const multiConst = rows.filter((r) => r.kind === 'constant' && [...heldOut, ...train].find((c) => c.id === r.case).expected.groups.length > 1);
console.log(`reference exact: ${ref.filter((r) => r.exact === 1).length}/${ref.length}`);
console.log(`constant exact on multi-folder cases: ${multiConst.filter((r) => r.exact === 1).length}/${multiConst.length}`);
