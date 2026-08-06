---
name: run-tasks
description: Execute an approved set of task files under a docs/specs task folder from start to finish with one restartable orchestrator. Use when the user asks to run, continue, resume, or finish all generated tasks. Delegate one write-capable task at a time to fresh subagents, persist progress in task files and Git, verify and locally review every task, and finish with a cumulative review. Do not use to split a spec, implement a single unsplit spec, or parallelize tasks.
---

# Run Tasks

Keep the orchestrator thin and replaceable. Let task files carry execution
state, Git carry code state, and fresh workers carry only the context needed for
one bounded outcome.

## Ground the run

Work from numbered task files at `docs/specs/<slug>/tasks/`. The terminal task
is the highest-numbered file in the approved set. A set is unfinished when any
task is not `completed` or the terminal task's `Cumulative status` is not
`passed`. The user's explicit request to run a named set, or the sole unfinished
set, confirms its current boundaries for execution; it does not authorize
changing them. If the user did not identify a set and multiple unfinished sets
exist, ask them to select one before changing files. If no task files exist or
their filenames do not establish dependency order, stop; do not invent a
breakdown or implement directly from an unsplit spec.

Inventory every task filename, status, declared dependency, runtime blocker,
and execution field. A declared dependency is an entry in the task contract's
`## Blockers` section; require it to name an existing lower-numbered task whose
status is `completed` and whose checkpoint is an ancestor of current `HEAD`.
Do not apply that rule to the mutable `Execution > Blocker` evidence field.
Stop on missing, forward, cyclic, or divergent dependencies.

For each selected task, resolve one authority bundle and reuse it for all of
its workers and reviewers:

- repository instructions and current Git state;
- the owning `spec.md` and relevant subjects routed through
  `docs/decisions/README.md`;
- the selected task and only the completed blockers it needs;
- `GLOSSARY.md` terms the task uses and an approved `prototype.html` when the
  task touches that experience.

Preserve the approved outcomes, blockers, constraints, and acceptance
criteria. Workers inspect the current implementation and reviewers additionally
receive the exact diff range and review evidence relevant to their role.

Require a resolvable Git `HEAD` and a state that supports explicit local
commits. For a new run, require a clean worktree. On resume, continue a clean
state that agrees with the recorded execution state. If tracked or untracked
changes remain, do not infer their owner from task relevance alone: continue
only after the user explicitly confirms that they are task-owned, otherwise
pause without stashing, committing, or discarding them. A detached checkout
chosen by the user is valid.

Require the harness to support fresh subagents. Do not silently fall back to
implementing every task in the orchestrator context.

## Maintain durable execution state

Use these task status transitions:

```text
pending -> in-progress -> completed
                       -> blocked
blocked -> in-progress only after the user resolves the blocker
```

Allow at most one `in-progress` task. Preserve completed tasks. Every task uses
this task-local execution shape:

```md
## Status

pending

## Execution

- Base commit: —
- Task checkpoint commit: —
- Verification: —
- Task review: —
- Task correction rounds: 0
- Blocker: —
```

Only the terminal task also carries the run-level gate:

```md
## Run completion

- Cumulative status: pending
- Cumulative base commit: —
- Cumulative candidate commit: —
- Cumulative reviewed commit: —
- Cumulative verification: —
- Cumulative review: —
- Cumulative correction rounds: 0
- Cumulative blocker: —
```

Initialize blank fields directly only for a new `pending` task. For any existing
task with legacy or missing execution evidence, read
[`references/recovery.md`](references/recovery.md) and apply its migration
rules without changing the approved contract. Do not create another run-state
file. The orchestrator owns task status, commit anchors, verification and review
evidence, blockers, and acceptance checkboxes. The only delegated
execution-state mutation is an atomic correction-counter increment in the
repair commit defined by the recovery reference.

At task start, record `in-progress` and the full current commit SHA as its base,
then commit that state transition before dispatch. Capture the resulting exact
`HEAD` as the expected worker start. After accepting a worker or repair result,
record its exact final commit as `Task checkpoint commit` in a state-only commit.
The checkpoint is the code boundary; later state-only commits do not expand
the task review range. At task completion, record verification commands and
results, the task review result, observable acceptance criteria, clear any
resolved runtime blocker, and record `completed` in one state-only commit.

## Run one task at a time

If a task or cumulative gate is `blocked`, or the run is being resumed, read
[`references/recovery.md`](references/recovery.md) completely and follow its
state reconstruction rules before selecting work.

Otherwise choose the lowest-numbered pending task whose blockers are complete.
If pending tasks remain but none is eligible, stop with the invalid dependency
evidence.

Start one foreground, write-capable worker with a fresh context. Give it the
task's authority bundle, current implementation, exact expected start `HEAD`,
and these requirements:

- implement only the selected outcome and run relevant deterministic checks;
- leave a clean worktree and a local checkpoint commit on the same first-parent
  line without resetting, rebasing, switching, or creating a checkout;
- return behavior changed, checks run, final commit SHA, and any unresolved
  blocker;
- do not spawn further agents.

Wait for that worker to finish before starting another worker. Inspect the
actual diff, command output, commit graph, and worktree rather than trusting its
summary. Accept the result only when current `HEAD` equals the reported
checkpoint, the expected start is its first-parent ancestor, all intervening
commits belong to the delegated task, and the worktree is clean. Do not repair
an invalid topology with reset or rebase.

If the worker returns an unresolved implementation, dependency, environment,
or authority blocker, follow the worker-blocker disposition in
[`references/recovery.md`](references/recovery.md). Unexpected dirty state
requires user confirmation before any commit can absorb it.

After accepting and recording the checkpoint, the orchestrator reruns the
deterministic verification against that code tree. Worker-reported checks are
context, not completion evidence. Verification must pass before review.

## Correct blocking evidence

When deterministic verification or review produces blocking evidence, read
[`references/recovery.md`](references/recovery.md) completely and use its one
bounded correction loop. That reference is authoritative for both task and
cumulative correction counts, interrupted repair commits, progress evidence,
and blocked-state recording.

## Review before task completion

Review the complete task diff from its recorded `Base commit` through its exact
`Task checkpoint commit`. Prefer the current harness's native local code-review
capability only when it is callable from the session and can honor that range.
Otherwise start a fresh reviewer with no write tools when the harness supports
tool restriction; if it does not, explicitly prohibit writes and confirm
afterward that Git state is unchanged.

Give the reviewer the same authority bundle, exact commits and diff, passing
verification evidence, and review criteria. Ask for correctness, security,
regression, and specification findings with file and line evidence. Exclude
style-only advice from blocking results. Require an explicit statement when no
blocking findings remain. A local foreground reviewer is an allowed fallback;
hosted or pull-request review is an external action under the authority boundary.

Route blocking findings through the bounded correction loop. When verification
and review pass, close the task gate before selecting the next task.

## Finish the whole run

First close every task-local gate, including the terminal task, as `completed`.
Then use only the terminal task's `Run completion` section as the authoritative
run-level state. Set `Cumulative status` to `in-progress`, record the first
task's base as `Cumulative base commit`, record the current pre-transition
`HEAD` as `Cumulative candidate commit`, and commit that transition.

Build the run authority bundle from repository instructions, the shared
specification, relevant decisions, glossary and approved prototype, every task
contract and acceptance criterion, the completed task checkpoints, and the
current integrated diff. Rerun the full deterministic verification and review
the cumulative diff from its recorded base through its exact candidate commit.
Give the reviewer that bundle, the exact start and end commits, the full diff,
and verification evidence. Require the review to cover interactions between
tasks rather than repeat isolated summaries.

Route failures through the bounded correction loop using the independent
cumulative counter and the run authority bundle. A cumulative repair may change
code introduced by any task when required by the integrated blocker; validate
it against the approved combined outcomes rather than one task's file scope.
Task checkpoint commits remain historical task-gate anchors, while the final
cumulative anchor represents the integrated result. After all verification and
blocking findings pass, copy the exact `Cumulative candidate commit` to
`Cumulative reviewed commit`, persist the verification and review evidence, set
`Cumulative status` to `passed`, and commit the final state update.

A completed-only set whose cumulative status is absent, pending, in-progress,
or blocked remains unfinished. Resume or perform that gate instead of declaring
success or selecting another set.

## Pause safely

For any restart, interruption, correction attempt, or blocked state, use
[`references/recovery.md`](references/recovery.md) rather than conversation
history. Recorded Git commits and counters are authoritative; disposable phase
markers are not.

Pause immediately when:

- more than one task is `in-progress`, required commit anchors are missing or
  divergent, or an unrecorded commit cannot be attributed safely;
- dirty state lacks the user's explicit confirmation of task ownership;
- a specification change invalidates an outcome, blocker, or task boundary;
- a repository hook or policy rejects a required checkpoint or state commit;
- continuing requires user input, external authority, or destructive recovery.

State the evidence and the smallest user decision needed. Retry policy never
expands authority and never permits silent task rewrites.

## Keep authority bounded

The request authorizes only the local reads, writes, commands, fresh subagents,
and commits required to execute the selected task set in the current checkout.
Do not alter unrelated pre-existing changes or checkout topology, interact with
remote or hosted systems, or delete project artifacts without a separate
explicit request. User-confirmed task-owned resume changes may be continued but
never silently absorbed. Pause when completion requires any other action.
