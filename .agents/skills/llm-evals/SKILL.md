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
as an `evals/` folder beside a skill or a flow under `.claude/hillclimb/`, use
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
skips what is already written. Keep the layout claude-api's report tools read:
a flow folder, by default `.claude/hillclimb/<flow>/`, holding `_state.json`
(metrics with the headline first, train and test ids, the access choice, the
approved spend) and one folder per variant named `baseline` or `v<N>`. Each
variant holds `results.jsonl`, one row per (case, rep) with `prompt_id`, `rep`,
`tags`, `grade` as `{metric: number}`, `status`, `model` read from the
response, and `usage`; `traces/<id>_rep<k>.json` with the whole exchange; and
`errors.jsonl` for attempts that failed before a scorable output. An infra
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
- the run size, cases × reps, and the model;
- the noise floor next to the gain the target needs;
- the cost estimated from the pilot's usage and the spend ceiling, or on a
  subscription the expected usage-limit draw with dollars only as the API
  equivalent.

Wait for a clear yes. Changing the cases, grader, split, or budget after
approval needs approval again.

## Red, then climb to green

Run the full set on the unchanged behavior and record it as the baseline: this
is the red. Then climb in rounds:

- One round, one idea. A fresh analyzer, a subagent where the harness has one,
  reads only train traces and proposes a change that names the failing
  behavior, not the content of the cases. Record it in the variant's
  `change.md`.
- Run the full set every round. Keep a change that raises the test score;
  revert one that raises train while test stays flat, or that regresses.
- Stop at green, after three rounds in a row that move only inside the noise
  floor, or at the approved spend.
- When rounds stall, sort the remaining train failures into content gap,
  grader disagreement, harness, structure, and variance before another content
  round.

Reach green only by changing the behavior. Never weaken, drop, or re-split
cases or the grader to pass.

## Keep the eval and hand back

Leave the runner, cases, and grader in the project ready to commit, and keep
traces and reports out of version control. Hand back:

- the behavior change;
- the baseline and final held-out scores with their noise floor, and a table
  of each round's change with its train and test scores;
- where the eval lives and how to rerun it;
- for an unreached target, the best held-out score and the failure buckets,
  so the criterion stays incomplete.
