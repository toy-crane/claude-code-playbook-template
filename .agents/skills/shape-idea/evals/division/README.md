# shape-idea's folder-division eval

This eval measures whether an agent following shape-idea's `SKILL.md` divides
a shaped change into the right spec folders with the right `Blocked by:`
lines. It follows the llm-evals layout, so `llm-evals` reuses it for any
change to how shape-idea divides work instead of building another eval.

## What it measures

Each case ends a shaping session with every decision settled. The agent runs
headless in a disposable workspace with shape-idea and the skills it requires
installed. When its first turn writes no spec folder, the runner sends one
approval turn: approve the proposed division, take the agent's recommendation
on any open question, and write the specs. Then `grade.mjs` reads every
`docs/specs/<slug>/spec.md`, asks a judge model which listed work items each
folder takes on, and compares the result with the expected division.

| metric | meaning |
|---|---|
| `exact` | 1 when every in-repository item sits in exactly one folder, the folders group items exactly as expected, no folder holds only outside work, and the `Blocked by:` edges match |
| `over_split` | 1 when items that belong in one folder were spread over several |
| `wrote_before_approval` | 1 when the first turn already wrote several folders, before any approval |
| `single_folder` | regression set: 1 when the run wrote exactly one folder |

`cases.json` holds three sets:

- `held_out`: ten cases scored against the target. Three are real divisions
  re-divided by the user (dearly `japan-launch`, dearly `login-flyn-structure`,
  robo `channel-and-thread-conversations`), six are the division cases of the
  retired `split-into-tasks` evals (2, 3, 7, 8, 9, 12) rewritten as shaping
  inputs, and one has only outside-repository preparation and after-release
  actions between its outcomes. The skill text is never tuned on them.
- `train`: four synthesized variations an analyzer may read while climbing.
- `regression`: shape-idea evals 5, 14, 16, 19, 24, and 25, which write one
  spec and must still write one.

The judge is a different model from the agent under test. `check-grader.mjs`
pushes a reference division for every case through the judge and scorer, and
a single constant folder for the multi-folder cases; the reference should
score about 100% and the constant about 0%.

## Run it

Ask the user first: how to reach the model, and approval of the run size and
usage, as `llm-evals` requires.

```bash
node skills/workflow/shape-idea/evals/division/check-grader.mjs --subscription
node skills/workflow/shape-idea/evals/division/run.mjs --variant baseline --skill-ref <previous-ref> --access subscription
node skills/workflow/shape-idea/evals/division/run.mjs --variant v1 --access subscription
node skills/workflow/shape-idea/evals/division/run.mjs --variant v1 --access subscription --set regression --reps 1
node skills/workflow/shape-idea/evals/division/summarize.mjs
```

- `--access api` passes `ANTHROPIC_API_KEY` from the environment or the repo
  root's `.env.local`; `--access subscription` clears it so the logged-in
  Claude Code runs the agent.
- `v<N>` takes the working tree's `SKILL.md` unless `--skill-file` names
  another file. The other installed skills always come from the working tree.
- Add `--cases <id> --reps 1` for a pilot and `--dry-run` to print the scope
  and the cost estimated from finished runs.
- A rerun skips every (case, rep) already in `results.jsonl`. A variant keeps
  one skill text, and a flow keeps one access and one agent model, recorded in
  `_state.json`; use another `--flow` to change them.

Results land in `.claude/hillclimb/shape-idea-division/`, which version
control ignores: `baseline/` and `v<N>/` hold `results.jsonl`,
`errors.jsonl`, `traces/<case>_rep<k>.json`, and `runs/` with each turn's raw
stream. Workspaces live in the system temp folder, because headless Claude
Code denies writes under any `.claude/` folder; `runs/<id>/workspace.txt`
names each one. Timeouts, denied writes, a served model other than the one
asked for, and judge failures land in `errors.jsonl`, never as a zero score.
