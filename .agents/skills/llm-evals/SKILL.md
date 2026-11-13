---
name: llm-evals
description: Prove LLM behavior with evals. Use when an acceptance criterion or request concerns the quality of LLM or agent output that varies run to run and no deterministic assertion can decide, such as a prompt, classifier, extractor, summarizer, tool-using agent, or a skill's instructions, whether `implement` hands the criterion over or the user asks to measure, prove, or improve that behavior or raise its quality score toward a target. Not for deterministic code, which `tdd` covers, or for checking whether a skill triggers.
---

# LLM Evals

Prove a criterion about LLM output with an eval: an approved case set, a runner
that calls the product's entry point, and a grader, scored over repeated runs.
It is a test in a noisy medium. The bar exists before the behavior changes, the
baseline score is the red, and the green is a held-out score at or above the
target and above the baseline outside the noise floor.

An eval is one of two kinds. A capability eval starts below the target so there
is a hill to climb, and it is finished once it reaches green. A regression
suite holds the cases a capability eval finished with, at the level they
reached, so a score below that level means something broke rather than that
there is room to improve. Every criterion starts as a capability eval and ends
by graduating into the project's one regression suite.

Read `GLOSSARY.md`, then use `docs/decisions/README.md` to load only the
decision subjects relevant to the behavior under evaluation. Surface a conflict
between code, spec, and a decision contract instead of choosing silently.

## Start from the criterion

When `implement` hands over work, it names the criterion with its metric, its
target on held-out cases, and where the cases come from, plus the active
outcome and the spec as design context. Prove only that criterion. A handed
criterion without a target goes back for shaping: inventing one would let
implementation set its own bar. Invoked directly, derive the criterion from the
request and ask the user for the metric and target when it gives none.

When the project already holds an eval that measures the same behavior, such
as a skill's eval folder or a flow under `.claude/hillclimb/`, use
it instead of building another. It still goes through the access choice and
the approval below.

## Choose how to reach the model

Before building anything, ask once how the eval reaches the model, because the
runner's shape and the pilot depend on it. Check what exists without printing
a secret: an API key in the environment or in the env file the product reads,
and a logged-in `claude` or `codex` CLI.

- With a key: ask whether to use the API key, recommended because it runs the
  real path, bills exactly, and runs cases in parallel, or the subscription.
  For an app feature, say that the subscription leaves out the app's
  parameters and tool wiring.
- Without a key: do not stop, and do not pick for the user. Ask whether to run
  on the subscription or to prepare a key first.
- With neither: stop and give both setups, a key placed where the product
  reads it or a CLI login.

The user's answer is the choice; record it in `_state.json`.

On a subscription, an app feature's runner swaps only the model call for a CLI
call with the app's own system prompt and model and no tools, for example
`claude -p --system-prompt <prompt> --tools "" --model <model> --output-format json`
with `--json-schema` for structured output, or `codex exec -m <model>` with
`--output-schema`. `claude --bare` skips the keychain, so it needs a key. For a
skill or agent, the CLI run is the real entry point either way: set the key in
the child environment for API access and clear it for the subscription.

## Build the eval

**Cases.** Take cases from production logs, then bug reports, then examples
the user gives. Synthesize only variations of real examples plus what makes a
case hard here. Size the set against the change you need to see: a pass-rate's
95% interval is about `1/sqrt(cases × reps)`, so 25 cases at 2 reps is about
±14 points. Split train and test at random, balanced by the primary tag. With
too few cases to split, score the whole set, label the result directional, and
confirm any revision made after seeing failures on cases not seen before.

**Runner.** Call the product's real entry point; never rebuild the model call
from the prompt you found. Write each (case, rep) as it finishes, so a restart
skips what is already written. The same holds across the whole climb: never
run a (variant, case, rep) that already has a scored row from the same cases
and grader; read that row instead. An attempt recorded only in `errors.jsonl`
has no row and runs again. The project chooses where its eval root lives:
use the one its agent instructions name, else the folder its existing evals sit
in, else `.claude/hillclimb/`. Never put it inside a folder that ships to
users, such as a skill's own folder: installers copy that folder whole, and
its users never need the eval. The layout under that root is fixed. The root
holds the runner, `regression/` (its `log.md`, its `cell-history.json`, and
one folder per graduated criterion), and one folder per capability eval. Name that
folder for the spec folder whose criterion it proves, and for the criterion too
when that spec has more than one of them, so two criteria handed over
separately never land on the same folder. This eval's folder holds
`cases.jsonl`, its grader, `_state.json` (metrics with the headline first,
train and test ids, the access choice, the approved spend), and one results
folder per variant named `baseline` or `v<N>`, in the shape claude-api's report
tools read. Each variant holds `results.jsonl`, one row per (case, rep) with
`prompt_id`, `rep`, `tags`, `grade` as `{metric: number}`, `status`, `model`
read from the response, and `usage`, keeping each check's verdict so its cells
can be counted; `traces/<id>_rep<k>.json` with the whole
exchange; and `errors.jsonl` for attempts that failed before a scorable output. An infra
failure is recorded with its class there, never scored as zero. Give each case
a wall-clock ceiling, back off with jitter on rate limits, and fail an attempt
whose served model differs from the requested one.

**Skills and agents.** The entry point is an agent run with the skill or agent
installed in a disposable workspace. Grade the end state it leaves: hidden
tests pass, expected files exist, nothing off-limits changed, and a no-op that
claims success fails. Record steps through a hook when the process itself is a
criterion. The baseline is the previous skill text, or no skill for a new one.
Keep each workspace outside any `.claude/` folder: headless Claude Code treats
every write there as sensitive and denies it. Record a run whose file writes
were denied as a harness failure, not as a score.

**Grader.** Choose the cheapest grader that truly measures the criterion: a
programmatic check, then a pairwise judge against frozen baseline outputs, then
a rubric judge with structured output and concrete checkable claims, then a
person. Never let the model under test judge itself. Before approval, push the
reference answers through runner and grader and see about 100%, push empty and
constant outputs and see about 0%, and see a judge fail an empty answer, "I
don't know", and a confident answer to the wrong question. Keep expected
answers where the model under test cannot read them.

When `claude-api` is installed and the model under test is Claude, you may use
its runner scaffold and report builder from its own skill folder. Otherwise
build the same contract in the project's language.

## Get one approval before the full run

Run a pilot of at most three cases at one rep through the whole runner and
grader, and read a written row to see every field filled. Then stop once and
show:

- every case, or a balanced sample when the set is large;
- graded pilot samples with their transcripts;
- the repetition count as its own choice: recommend 2, and 3 only when the
  set stays under 10 cases or the behavior is known to vary run to run. Never
  accept fewer than 2, since graduation keeps only cases that passed on every
  repetition and one pass cannot tell a stable case from a lucky one. Answer a
  request for more than 3 with more cases instead: repetitions show only how
  one case varies, and the noise floor shrinks slowly with them;
- the run size, cases × reps, and the model, counting the baseline, the
  rounds, and the gates, but no run whose row will already exist;
- the noise floor next to the gain the target needs;
- for each case you expect to pass already at the baseline, what it guards
  against, such as a behavior the change could push too far; record the
  answer as the case's `guards` field;
- the cost estimated from the pilot's usage and the spend ceiling, or on a
  subscription the expected usage-limit draw with dollars only as the API
  equivalent.

Wait for a clear yes. Changing the cases, grader, split, or budget after
approval needs approval again.

## Red, then climb to green

Run the full set on the unchanged behavior and record it as the baseline: this
is the red, for train, for test, and for the project's regression suite, so a
suite already failing before this climb is not later read as its doing. When
that baseline already sits near
the target there is no hill to climb: report that the cases are too easy for
this behavior and ask for harder ones instead of climbing. Then climb in
rounds:

- One round, one idea. A fresh analyzer, a subagent where the harness has one,
  reads only train traces and proposes a change that names the failing
  behavior, not the content of the cases. Record it in the variant's
  `change.md`.
- Score train only. Keep a change whose train score rises outside the train
  noise floor; revert one that does not.
- Open a gate when the train score first reaches the target, and again at the
  end. A gate scores the held-out split and the project's regression suite.
  On a set too small to split, the round already scored the whole set, so the
  gate takes that round's score and runs only the regression suite; a second
  gate on a variant already gated takes the first gate's score.
  When the held-out score does not follow train, the climb fitted train:
  revert to the last gate that passed and bisect the changes between them.
  A gate fails the same way when the suite drops below the baseline recorded
  for it, outside the noise floor, on cases that baseline passed — this climb
  broke behavior that already worked, and failures the baseline already had
  are not this climb's. Nothing graduates from a failed gate.
- Stop at green, after three rounds in a row that move only inside the noise
  floor, or at the approved spend. However it stops, open the final gate
  before handing back, so the result rests on a held-out score rather than a
  train one.
- When rounds stall, sort the remaining train failures into content gap,
  grader disagreement, harness, structure, and variance before another content
  round.

Reach green only by changing the behavior. Never weaken, drop, or re-split
cases or the grader to pass.

## Graduate the eval, then hand back

Green ends the capability eval, so finish it instead of leaving it in place.
Take the cases the final variant passed on every repetition from the rows it
already has: train from its round and held-out from the final gate, or the
whole set from its round when the set was not split. Do not run it again for
graduation. Move their `cases.jsonl` rows and this eval's grader into
`regression/` under the eval root, in a folder named the way this eval's was,
and carry the grader whole: the code checks and the rubric both go, because
dropping the rubric stops guarding the regressions only a judge can see. Carry
what the grader reads as well, since the rest of the folder is about to go —
the frozen baseline outputs a pairwise judge compares against, its fixtures,
and the expected answers it scores from. Add each graduating cell — one case
judged by one check — to the cell history with its trials and passes from those
rows, their results in order as its recent results, and its result at this
climb's baseline. A cell that failed at the
baseline goes to the upper tier. A cell that already passed at the baseline
goes to the upper tier only when its case's `guards` states what it guards
against, and to the lower tier otherwise; a suite with no `lower_tier_model`
yet takes the climb's model as it. Delete the rest of this eval's folder, append
one line to `regression/log.md` with the date, the criterion, the baseline and
final scores, the noise floor, the model, and the commit, and record the eval
root's path in the project's agent instructions — `AGENTS.md`, created when
missing, and `CLAUDE.md` too when it exists and does not load `AGENTS.md` — so
later work finds the suite without guessing.

A case whose passes were not repeatable does not graduate: a suite that starts
amber reports nothing. Leave it in a capability eval while the criterion is
open, and record it as a known failure once the criterion closes.

Cases, graders, the runner, and everything under `regression/` are ready to
commit. The variant results folders are not, and graduation deletes them.

Hand back:

- the behavior change;
- the baseline and final held-out scores with their noise floor, a table of
  each round's change with its train score, and each gate's held-out score;
- which cases graduated, which did not and why, and where the regression suite
  lives;
- how to rerun the regression suite, and the capability eval too when one
  stays open;
- for an unreached target, the best held-out score and the failure buckets,
  so the criterion stays incomplete.

## Run the regression suite in two tiers

A regression suite is scored against the level its cases reached, over the same
repetitions, so a drop outside the noise floor means something broke. Change or
remove one of its cases only when a decision to change that behavior exists, or
when the feature it covers is gone; a failing score is never that reason, and
neither is passing. A cell whose most recent 10 trials all passed may be
demoted to the lower tier, never deleted: answer a request to delete one by
offering demotion instead and deleting nothing. Tell the user that demotion is
proposed from the cell history by the `audit-evals` skill, which moves only the
cells they approve, and that it installs with
`npx skills@latest add toy-crane/skills --skill audit-evals` when it is not
installed; this skill does not run it.

Every suite run, at a gate or for `implement`, runs the upper tier. It runs the
lower tier too only when this run's model differs from the model the lower tier
last ran on. A lower-tier cell that fails outside the noise floor is a
regression: report it as one and propose moving it back to the upper tier,
which happens once the user approves.

After each suite run, add every cell's trials and passes to the cell history
and append each new result to the end of its `recent` results, dropping the
oldest so it keeps the last 10; then set the suite's `last_run_model`, and its
`lower_tier_model` when the lower tier ran. The history grows only from runs that happen anyway; never run
the suite to fill it. A suite that predates the history starts it on its next
run, every cell in the upper tier with an unknown baseline. Keep the run's
answers and judge reasoning only until the next suite run replaces them,
uncommitted: they are for reading the failure just seen, and the counts already
live in the history.

The cell history is `regression/cell-history.json`: per cell, cumulative counts
and its most recent 10 results, oldest first (`p` pass, `f` fail), rather than
a row per run, so its size does not grow with the number of runs. A cell's
`recent` holds as many results as its trials, up to 10:

```json
{"version": 2, "suites": {"<criterion folder>": {
  "reps": 2, "last_run_model": "<model>", "lower_tier_model": "<model or null>",
  "checks": {"<check>": {"grader": "code or judge", "judge_call": "<id shared by checks judged in one call>"}},
  "cells": {"<case>": {"<check>": {"tier": "upper or lower", "baseline": "pass, fail, or null",
    "trials": 14, "passes": 13, "recent": "pppppppppp"}}}}}}
```
