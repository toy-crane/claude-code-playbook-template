# tdd's eval

This eval measures how an agent following tdd's `SKILL.md` writes tests. Use it
when a change to that text needs proof that the revision does not get worse
than the previous text. It follows the llm-evals layout, so `llm-evals` reuses
it for any tdd change instead of building another eval.

## What it measures

Two cases, each run in a disposable workspace with only `SKILL.md` installed:

- `feature`: build `shippingFee(order)` from `feature/workspace/docs/spec.md`.
- `bug`: fix the negative total in `bug/workspace/docs/bug.md`.

The agent never sees `*/hidden/`. After each run, `score.mjs` grades the end
state and the test runs a hook recorded:

| metric | meaning |
|---|---|
| `criteria_met` | share of the hidden criteria tests that pass |
| `mutants_caught` | share of seeded bugs the agent's own tests catch |
| `final_suite_passes` | 1 when the agent's suite ends green |
| `reproduced_before_fix` | bug case: 1 when a new test failed on an assertion before `src/cart.js` changed |
| `fake_red` | new tests that did not fail on an assertion against the stub or unfixed code |
| `never_seen_failing` | new tests the agent never ran while they failed on an assertion |
| `reasonless` | new tests a judge labels as protecting nothing |

With two cases there is no train and test split. Read the scores as
directional, and confirm a revision made after reading failures on a case it
was not tuned on.

## Run it

Ask the user first: how to reach the model, and approval of the run size and
cost, as `llm-evals` requires.

```bash
node skills/workflow/tdd/evals/compare/run.mjs --variant baseline --skill-ref <previous-ref> --access subscription --reps 3
node skills/workflow/tdd/evals/compare/run.mjs --variant v1 --access subscription --reps 3
node skills/workflow/tdd/evals/compare/compare.mjs
```

- `--access api` passes `ANTHROPIC_API_KEY` from the environment or the repo
  root's `.env.local`; `--access subscription` clears it so the logged-in
  Claude Code runs the agent.
- `v<N>` takes the working tree's `SKILL.md` unless `--skill-file` names
  another file.
- Add `--cases feature --reps 1` for the pilot, and `--dry-run` to print the
  resolved scope and the cost estimated from finished runs.
- A rerun skips every (case, rep) already in `results.jsonl`. A variant keeps
  one skill text; a different text needs a new variant. A flow keeps one
  access and one `--model`, recorded in `_state.json`, so a resumed or later
  variant cannot switch either; use another `--flow` to change them.

Results land in `.claude/hillclimb/tdd/`, which version control ignores:
`baseline/` and `v<N>/` each hold `results.jsonl`, `errors.jsonl`,
`traces/<case>_rep<k>.json`, and `runs/` with each run's raw agent trace and
step log. The workspaces themselves live in the system temp folder, because
headless Claude Code denies writes under any `.claude/` folder. A run whose
file writes were denied lands in `errors.jsonl`, not in the scores; shell
commands outside the allowlist are the same for every variant, so those runs
are scored and the denial count is kept in `meta`. `compare.mjs` writes
`comparison.json` with each metric's mean and interval and these gates for the
newer variant: both variants were served by the same model, every criterion
the baseline met in most runs is still met in
most runs, final suites pass, fake reds and caught mutants are not worse,
every new test was seen failing, and every bug run reproduced before the fix.

The 2026-10-29 comparison in `docs/decisions/testing.md` used baseline
`0154388`; rerun it with `--skill-ref 0154388`.
