# Recovery and correction

Read this reference completely when a task or cumulative gate is `blocked` or
`in-progress` at invocation, a worker returns a blocker, deterministic
verification or review fails, a worker result has unexpected Git state, or the
harness is interrupted.

## Distinguish the two blocker types

- A **declared dependency** is immutable task-contract content under
  `## Blockers`. It must name an existing lower-numbered completed task whose
  checkpoint is an ancestor of current `HEAD`.
- A **runtime blocker** is mutable execution evidence in `Execution > Blocker`
  or `Run completion > Cumulative blocker`. It may describe a failed check,
  review finding, missing environment capability, or user decision. Never
  interpret it as a task filename.

Record runtime evidence as `<stage> — <evidence>`. Valid task stages are
`implementation`, `verification`, and `task-review`; valid run stages are
`cumulative-verification` and `cumulative-review`. When the user resolves one,
retain `resolved <stage> — <resolution>` until that gate closes so a later
restart knows where to continue.

## Use exact durable boundaries

The task's `Base commit` is its original code start. The latest state-only
commit that changes the task from `pending` or `blocked` to `in-progress` is
the dispatch anchor for that attempt. `Task checkpoint commit` is the latest
code boundary the orchestrator has validated and recorded. Find these states
from the task file's first-parent Git history; do not rely on conversation
history or commit-message wording.

`Cumulative base commit` and `Cumulative candidate commit` are the exact
integrated review range. `Cumulative reviewed commit` is populated only after
that same candidate passes verification and review.

A repair round is durable and consumed only when a clean first-parent repair
commit both changes code and increments exactly the selected counter by one.
An interruption before such a commit consumes no round. If the commit exists
but the orchestrator was interrupted before recording its checkpoint or
candidate, the round remains consumed; validate and adopt or block it without
decrementing the counter.

Before dispatching any repair, the orchestrator records the exact failed
verification or blocking review evidence in its existing state field, commits
that state-only transition, and captures the resulting `HEAD` as the repair
dispatch anchor. A code commit after an existing task checkpoint or cumulative
candidate is never ordinary implementation unless a durable
`resolved implementation` marker explicitly authorizes that continuation.

## Reconstruct an interrupted task

Use these ordered cases. Repair evidence always takes precedence over the
generic candidate cases:

1. `blocked` without an explicit user resolution: stop.
2. `blocked` with an explicit resolution: verify that it resolves the staged
   runtime blocker without changing the approved outcome, dependency graph, or
   task boundary. Preserve the original base and correction count, replace the
   evidence with `resolved <stage> — <resolution>`, set the task or cumulative
   gate to `in-progress`, and commit that state-only transition. If a legacy
   blocker has no stage, infer one only from unambiguous durable evidence;
   otherwise pause. If the contract changed, pause for a revised task set.
3. `in-progress` with a `resolved implementation` blocker: inspect from the
   latest resume transition even when a partial checkpoint exists. If no later
   code commit exists, dispatch a fresh implementation worker with that
   checkpoint and the remaining approved outcome. If a later clean task-scoped
   first-parent commit exists, record its tip as the new checkpoint. This
   continuation is not a correction round.
4. `in-progress` with any code commit after a recorded task checkpoint, unless
   case 3 applies: require durable failed verification or blocking review
   evidence, first-parent ancestry from its repair dispatch anchor, a
   task-scoped code change, and an atomic one-step task-counter increment. If
   valid, record the tip as the new checkpoint and rerun verification and
   review. If any condition fails, stop; do not adopt the code through a generic
   candidate case.
5. `in-progress` with a blank task checkpoint and no commit after the latest
   dispatch anchor: dispatch a fresh implementation worker from that exact
   anchor.
6. `in-progress` with a blank task checkpoint and later clean ordinary
   implementation commits: use this case only when neither durable failure
   evidence nor a correction-counter change indicates a repair attempt. Treat
   the tip as a candidate result only when the dispatch anchor is its
   first-parent ancestor and every intervening change belongs to the task.
   Record it as the task checkpoint, then rerun authoritative verification and
   review. Pause when attribution or topology is ambiguous.
7. `in-progress` with a current task checkpoint and only later state-only
   commits: rerun authoritative verification and full task review at the
   checkpoint, then close the task if both pass. A `resolved verification` or
   `resolved task-review` marker follows this case rather than dispatching an
   implementation worker.

For an `in-progress` cumulative gate, apply the same ancestry rules to
`Cumulative candidate commit`. A later cumulative repair is valid only when it
atomically increments the cumulative counter and its code diff directly
addresses the integrated blocker within the combined approved outcomes. Record
the repair commit as the new cumulative candidate before rerunning full
verification and cumulative review.

An `in-progress` cumulative gate with a resolved cumulative marker reruns full
verification and cumulative review at its recorded candidate. Clear the marker
only when the cumulative gate passes; replace it with newly staged evidence if
the gate blocks again.

Dirty tracked or untracked state is never attributable from relevance alone.
Continue only after the user explicitly confirms it is task-owned; otherwise
pause without stashing, committing, or discarding it.

## Dispose a worker blocker

When an implementation worker returns an unresolved dependency, environment,
authority, or user-input blocker, first inspect its Git result:

- If it left a clean, correctly scoped first-parent checkpoint, validate and
  record that exact commit before recording the runtime blocker.
- If it made no code commit, record the runtime blocker from the existing
  dispatch anchor.
- If it left dirty, divergent, unrelated, or ambiguously owned state, pause and
  ask for the smallest recovery decision; do not absorb it into a state commit.

For a valid clean state, set the task to `blocked`, record concise `Blocker`
evidence prefixed with `implementation —`, commit the blocked state, and stop
the entire run without spending a correction round or selecting another task.

## Apply one bounded correction loop

Use the task authority bundle for a task failure. Use the run authority bundle
and combined approved outcomes for a cumulative failure. Parameterize the loop
with the blocking evidence, exact diff range, and the corresponding task or
cumulative counter:

1. When no blocking evidence remains, pass the gate even if the counter is two.
2. When blocking evidence remains and the counter is already two, record the
   appropriate blocked state and stop.
3. Otherwise persist the exact failed verification or blocking review evidence
   in its existing state field, commit that state-only transition, and capture
   its `HEAD` as the repair dispatch anchor. Then start one fresh write-capable
   repair worker with the applicable authority bundle, current code, exact
   evidence and range, and current count. Require it to fix only that evidence,
   increment the selected counter by one in the same commit as its code changes,
   and spawn no agents.
4. Require a clean worktree, exact returned `HEAD`, first-parent ancestry from
   the dispatch state, and changes within the applicable task or integrated
   scope. Record a task repair as the new task checkpoint or a cumulative repair
   as the new cumulative candidate. Rerun deterministic verification before
   reviewing again.
5. Observable progress requires the repair diff and new verification or review
   evidence to directly reduce the blocker. If a valid durable repair does not
   do so, record the blocked state without starting another round.

For a task gate, set the task `blocked` and use `Execution > Blocker`. For the
run-level gate, keep all task statuses `completed`, set `Cumulative status` to
`blocked`, and use `Cumulative blocker`. Commit concise evidence and stop rather
than skipping ahead or retrying without a new basis. Prefix the evidence with
the failing `verification`, `task-review`, `cumulative-verification`, or
`cumulative-review` stage.

## Migrate legacy execution state

Never fabricate a commit anchor. Migrate only with exact durable evidence:

- Add the current blank schema directly to a new `pending` task.
- Rename a legacy `Final code commit` to `Task checkpoint commit` only when it
  contains a full commit SHA that is an ancestor of current `HEAD`.
- Reconstruct a missing base or checkpoint only when task-file first-parent
  history and a task-scoped diff identify one unique commit. Pause when more
  than one commit could fit.
- Preserve a legacy passing cumulative result only when its evidence names an
  exact valid base and reviewed SHA. Otherwise, if every task anchor and the
  first base are safely known, initialize the terminal cumulative gate as
  `pending` and rerun it. If those anchors are not recoverable, pause and ask
  for the smallest baseline decision.

Do not change completed outcomes or acceptance criteria during migration, and
do not mark a legacy gate passed merely because prose says a review occurred.
