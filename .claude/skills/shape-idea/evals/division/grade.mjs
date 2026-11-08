// Grading for shape-idea's folder-division eval. See README.md beside this file.
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Every docs/specs/<slug>/spec.md the run left, with its Blocked by targets.
export function collectFolders(workspace) {
  const root = join(workspace, 'docs/specs');
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(join(root, d.name, 'spec.md')))
    .map((d) => {
      const text = readFileSync(join(root, d.name, 'spec.md'), 'utf8');
      const blockedBy = [...text.matchAll(/Blocked by:\s*`?docs\/specs\/([^/`\s]+)\/?`?/g)].map((m) => m[1]);
      return { slug: d.name, text, blockedBy: [...new Set(blockedBy)] };
    })
    .sort((a, b) => a.slug.localeCompare(b.slug));
}

const judgeSchema = {
  type: 'object',
  properties: {
    folders: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          slug: { type: 'string' },
          delivers: { type: 'array', items: { type: 'string' } },
        },
        required: ['slug', 'delivers'],
      },
    },
  },
  required: ['folders'],
};

// Asks a judge model which listed items each written spec folder delivers.
export function judgeAssignment(testCase, folders, { env, model }) {
  const items = Object.entries(testCase.items).map(([id, d]) => `- ${id}: ${d}`).join('\n');
  const outside = Object.entries(testCase.outside ?? {}).map(([id, d]) => `- ${id}: ${d}`).join('\n') || '(none)';
  const docs = folders.map((f) => `=== folder: ${f.slug} ===\n${f.text.slice(0, 15000)}`).join('\n\n');
  const prompt = `You classify which work each spec folder delivers. A shaping agent wrote the spec folders below for one product change.

Work items inside the repository:
${items}

Work done only outside the repository:
${outside}

For each folder, list the ids of every item, from either list, that the folder's spec takes on as its own outcome or approved scope: something its implementation or its setup section delivers. Do not list an item the spec only mentions as context, as another folder's work, as out of scope, or as already done. A folder that delivers only part of an item still lists that item. Use the folder slugs exactly as given.

${docs}`;
  const args = ['-p', prompt, '--output-format', 'json', '--json-schema', JSON.stringify(judgeSchema), '--tools', '', '--setting-sources', 'project'];
  if (model) args.push('--model', model);
  const run = spawnSync('claude', args, { encoding: 'utf8', env, maxBuffer: 64 * 1024 * 1024, timeout: 600_000 });
  if (run.status !== 0) return { error: `judge exit ${run.status}: ${(run.stderr || run.stdout).slice(0, 500)}` };
  let out;
  try { out = JSON.parse(run.stdout); } catch { return { error: `judge output not JSON: ${run.stdout.slice(0, 500)}` }; }
  let data = out.structured_output;
  if (!data && typeof out.result === 'string') {
    try { data = JSON.parse(out.result.replace(/^```(?:json)?\s*|\s*```$/g, '')); } catch { /* handled below */ }
  }
  if (!data?.folders) return { error: `judge gave no folders: ${String(out.result).slice(0, 500)}` };
  return { assignment: data.folders, usage: out.usage ?? null, model: Object.keys(out.modelUsage ?? {})[0] ?? null, cost: out.total_cost_usd ?? null };
}

const key = (ids) => [...ids].sort().join('+');

// Compares the written folders with the expected division.
export function scoreDivision(testCase, folders, assignment) {
  const inRepo = new Set(Object.keys(testCase.items));
  const delivered = new Map(folders.map((f) => [f.slug, new Set()]));
  for (const row of assignment) {
    if (!delivered.has(row.slug)) continue;
    for (const id of row.delivers) if (inRepo.has(id)) delivered.get(row.slug).add(id);
  }
  const problems = [];
  // An item in no folder, or in several, cannot match.
  const owners = new Map([...inRepo].map((id) => [id, []]));
  for (const [slug, ids] of delivered) for (const id of ids) owners.get(id).push(slug);
  for (const [id, slugs] of owners) {
    if (slugs.length === 0) problems.push(`item ${id} is in no folder`);
    if (slugs.length > 1) problems.push(`item ${id} is in ${slugs.join(', ')}`);
  }
  for (const [slug, ids] of delivered) if (ids.size === 0) problems.push(`folder ${slug} delivers no in-repository item`);

  const expectedGroups = testCase.expected.groups.map(key);
  const actualGroups = [...delivered.values()].filter((s) => s.size).map(key);
  const partitionMatches = expectedGroups.length === actualGroups.length
    && expectedGroups.every((g) => actualGroups.includes(g));
  if (!partitionMatches) problems.push(`groups ${JSON.stringify(actualGroups)} vs expected ${JSON.stringify(expectedGroups)}`);

  // Over-division: one expected group spread over several folders.
  const overSplit = testCase.expected.groups.some((group) => {
    const homes = new Set(group.flatMap((id) => owners.get(id)));
    return homes.size > 1;
  });

  const slugGroup = new Map([...delivered].map(([slug, ids]) => [slug, key(ids)]));
  const actualEdges = new Set();
  for (const f of folders) {
    for (const target of f.blockedBy) {
      if (!slugGroup.has(target)) { problems.push(`${f.slug} is blocked by missing folder ${target}`); continue; }
      actualEdges.add(`${slugGroup.get(f.slug)}<-${slugGroup.get(target)}`);
    }
  }
  const expectedEdges = new Set(testCase.expected.edges.map(([dep, blocker]) => `${expectedGroups[dep]}<-${expectedGroups[blocker]}`));
  const edgesMatch = actualEdges.size === expectedEdges.size && [...expectedEdges].every((e) => actualEdges.has(e));
  if (!edgesMatch) problems.push(`edges ${JSON.stringify([...actualEdges])} vs expected ${JSON.stringify([...expectedEdges])}`);

  return {
    exact: problems.length === 0 ? 1 : 0,
    over_split: overSplit ? 1 : 0,
    folder_count: folders.length,
    problems,
    delivered: Object.fromEntries([...delivered].map(([slug, ids]) => [slug, [...ids].sort()])),
    edges: [...actualEdges],
  };
}

// Reads Claude Code's stream-json output for the fields the runner records.
export function readStream(raw) {
  const info = { sessionId: null, model: null, apiKeySource: null, resultSubtype: null, costUsd: null, usage: null, turns: null, permissionDenials: [], finalText: '' };
  for (const line of raw.split('\n')) {
    let event;
    try { event = JSON.parse(line); } catch { continue; }
    if (event.type === 'system' && event.subtype === 'init') {
      info.sessionId = event.session_id;
      info.model = event.model;
      info.apiKeySource = event.apiKeySource;
    }
    if (event.type === 'result') {
      info.sessionId = event.session_id ?? info.sessionId;
      info.resultSubtype = event.subtype;
      info.costUsd = event.total_cost_usd ?? null;
      info.usage = event.usage ?? null;
      info.turns = event.num_turns ?? null;
      info.permissionDenials = event.permission_denials ?? [];
      info.finalText = event.result ?? '';
    }
  }
  return info;
}
