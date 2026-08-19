---
name: resolve-follow-ups
description: Resolve evidence-backed `docs/follow-ups/*.md` through a bounded manual, Codex Scheduled task, or Claude Routine sweep. Use when project follow-ups should be reproduced before editing, handled by one isolated worker and branch per item, and published as independent ready-for-review pull requests without automatic merge. Do not use to invent intended behavior or merely record a newly discovered follow-up.
---

# Resolve Follow-ups

Turn a bounded set of recorded follow-ups into independently verified pull
requests. Preserve every item that cannot pass the reproduction and authority
gates.

## Choose the execution mode

- Treat an invocation without a specific follow-up path as a **sweep**. Select
  workers from the repository backlog and return one combined report.
- Treat an invocation carrying one follow-up path, base SHA, attempt identity,
  owner token, branch, and worktree as a **worker**. Resolve only that item and
  return one terminal outcome.
- Keep Schedule or Routine frequency outside this skill. One invocation is one
  sweep, never one recurring schedule per follow-up.

## Sweep the backlog

Resolve this skill's directory, then use
`scripts/resolve-follow-ups.sh` from that directory. The script is the
deterministic boundary for ordering, fresh-base identity, worktree creation,
attempt suppression, and cleanup.

1. Run `list --repo <root>` to fetch the remote default branch and obtain every
   valid candidate in discovery order plus every `invalid-follow-up`. Report
   invalid files without filling in their missing evidence. Do not enumerate a
   possibly stale coordinator checkout.
2. For each candidate in order, run
   `identity --repo <root> --follow-up <path>`. Continue until three eligible
   workers have been started or the ordered backlog is exhausted.
   `eligible` is only a snapshot, not a reservation. The platform adapter must
   win the attempt's atomic `claim` or `prepare` result before launching a
   worker; `skipped-unchanged ... claimed <owner> [<worktree> <branch>]` means
   another sweep already owns the unchanged follow-up content. That active
   ownership and a recorded pull request survive unrelated default-branch
   advancement; terminal non-PR results become retryable after that advance.
3. For `skipped-unchanged`:
   - When the result carries `claimed` and an owner, do not dispatch it again;
     another worker already owns the exact content and base identity. If the
     adapter proves that owning process has ended without a terminal result,
     clean up its exact bound worktree when one is reported, then run `recover
     --repo <root> --attempt-key <key> --owner <owner>`. Never recover an active
     or uncertain worker merely because its claim is old.
   - Preserve a prior `not-reproduced`, `needs-shaping`, or `blocked` result
     until the follow-up content or remote default-branch SHA changes. Terminal
     identity output retains `owner <owner> [<worktree> <branch>]`; if that
     worktree still exists after its worker ended, use those exact coordinates
     for `cleanup` before starting the base-change retry. A base advance does not
     hide an outstanding terminal worktree.
   - When the result carries `pull-request` and a URL, check that pull request.
     Keep it skipped while open. After an unmerged close, run `clear` for that
     exact base identity before retrying. A merged pull request should remove
     the follow-up on the updated default branch; report a mismatch instead of
     opening a duplicate. If the path was deleted and later re-created, treat it
     as a fresh follow-up lifetime even when its Markdown matches the old item.
4. Establish whether candidate scopes are independent before running workers
   concurrently. Process uncertain or overlapping scopes separately while
   retaining a distinct worktree and pull request for each item.
5. A failed worker does not cancel other independent workers. Never exceed
   three actual workers in one sweep.

## Launch one isolated worker per item

Give every worker only its follow-up path, verified base SHA, attempt identity,
owner token, branch, worktree, and the worker contract below. The owner token is
required when binding the checkout, recording the outcome, and cleaning up, so
one worker cannot overwrite or remove another worker's attempt. The dispatcher
also reserves each canonical worktree path repository-wide; never bypass a
reservation failure by reusing another attempt's checkout.

### Claude Routine

Use a subagent with `isolation: worktree` when the active installation has a
creation-time `WorktreeCreate` policy or equivalent check that stops on fetch
failure and guarantees the identity base SHA. Require the subagent to compare
its `HEAD` with that SHA before editing.

Before dispatch, run `claim --repo <root> --follow-up <path> --base-sha <sha>`.
Dispatch only a `claimed <attempt-key> <owner>` result. As the worker's first
action, run `bind --repo <root> --attempt-key <attempt-key> --owner <owner>
--worktree <worktree> --branch <branch>` from the native checkout. A bind
failure stops the worker before editing. Claude owns removal of a native
worktree after the coordinator records the terminal outcome.

When native creation cannot make that guarantee, run `prepare` to create and
verify the worktree, then start a top-level headless Claude worker from that
directory. Do not nest a Claude CLI process merely to duplicate isolation the
native subagent already guarantees.

### Codex Scheduled task

Treat the scheduled task as coordinator only; its background worktree does not
isolate item workers. For each eligible item:

1. Choose a unique worktree path and branch whose name includes the follow-up
   slug and a short attempt-identity suffix.
2. Run `prepare --repo <root> --follow-up <path> --worktree <path> --branch
   <branch>`. Continue only for `prepared <worktree> <branch> <base-sha>
   <attempt-key> <owner>`; a concurrent sweep can instead return
   `skipped-unchanged` without creating a checkout. The dispatcher persists the
   canonical worktree target before creation, so an interrupted prepare is
   reported with the same claim owner, worktree, and planned branch for exact
   cleanup rather than becoming an anonymous checkout.
3. Start a top-level non-interactive Codex worker with `codex exec -C
   <worktree> --sandbox workspace-write <prompt>`. Configure only the network
   and approval capabilities needed to verify, push, and open the pull request.

Do not use a writing subagent that inherits the coordinator's working
directory as a substitute for per-item isolation.

## Apply the worker contract

### Verify the boundary

- Confirm that the worker `HEAD` equals the supplied base SHA before any edit.
- Read the one follow-up file and verify all five fields: symptom, observed
  evidence, suspected cause, what was tried, and proposed next step.
- Keep the worker diff limited to the selected item. Stop as `blocked` when the
  base, checkout, permissions, or environment cannot be verified.

### Pass the reproduction gate

- Reproduce the symptom through the recorded command, route, test, or
  environment before modifying product source.
- Retain concrete baseline evidence such as a failing assertion, exit status,
  observable output, or runtime state.
- Return `not-reproduced` with the attempts and next useful evidence when the
  symptom does not reproduce within the bounded run. Make no speculative source
  change or resolution pull request.

When reproduction reveals a different out-of-scope defect, preserve the
selected item and return the new symptom, observed evidence, suspected cause,
what was tried, and proposed next step to the coordinator. Do not leave the only
record in the disposable worker. The coordinator serializes these records in
its own checkout through `project-knowledge` when available, or writes the same
five fields to `docs/follow-ups/<symptom>.md`. Before cleaning up the worker,
commit that record and publish a dedicated ready-for-review follow-up-record PR;
do not mix it into the selected item's resolution PR. A local coordinator change
or closing-message copy is not a durable handoff.

### Confirm authority to fix

- Derive intended behavior from current tests, specifications, decision
  contracts, supported runtime behavior, or an unambiguous compatibility
  contract.
- Continue only when the intended result is already settled and can be checked
  deterministically.
- Return `needs-shaping` without a patch when the item requires a product
  decision, public-contract change, or material trade-off. Name the unresolved
  choice so a later `shape-idea` session can settle it.

### Repair through evidence

- Make the smallest coherent fix and add or retain a regression check through a
  stable public seam when available.
- Re-run the reproduction after each meaningful candidate change. Continue only
  while new evidence supports another attempt; repeated failure without new
  evidence ends as `blocked`.
- Run focused deterministic checks and the affected repository-supported
  runtime verification. Static checks do not close a runtime symptom.
- Treat the item as resolved only when the original failure passes and relevant
  regression checks remain green.

### Publish the result

- Delete the resolved follow-up in the same commit series as the verified fix.
  Git history is its archive.
- Push only the worker branch and open one ready-for-review pull request. Include
  before-and-after reproduction evidence, checks run, and remaining uncertainty.
- Do not combine another follow-up and do not merge the pull request.
- Return `pull-request` with its URL. If publication or verification fails,
  retain the follow-up and return `blocked` rather than claiming resolution.

Finish the worker response with a compact block containing `outcome`,
`follow-up`, `base-sha`, `attempt-key`, `owner`, `pull-request` when present,
the decisive reproduction or blocker evidence, and any newly discovered
follow-up record for the coordinator. The coordinator uses this block to record
the exact attempt; prose alone is not a terminal result.

## Record and clean up each outcome

After the worker returns:

- For a pull request, run `mark --repo <root> --follow-up <path> --base-sha
  <sha> --owner <owner> --outcome pull-request --detail <URL>` so later sweeps
  do not duplicate it.
- For a non-PR result, run the same `mark` command with `--outcome
  not-reproduced`, `--outcome needs-shaping`, or `--outcome blocked` and use
  `--detail` for compact decisive evidence or the next useful condition. A
  different worker cannot replace the first terminal result. The recorded
  identity is disposable local automation state, not a status field in the
  tracked follow-up.
- For a clean non-PR worker that never moved beyond its base, run `cleanup` with
  `cleanup --repo <root> --worktree <worktree> --attempt-key <attempt-key>
  --owner <owner>`. For a PR worker, run the same cleanup only after its exact
  `HEAD` is visible on the remote branch. The script removes only the worktree
  bound to that exact claim and preserves the local branch so cleanup cannot
  race a new checkout and delete its ref. It revalidates the repository-wide
  coordinate reservation before removal, safely deinitializes clean submodules
  through isolated Git metadata without changing shared repository settings, and
  leaves Git's final dirty-worktree refusal enabled. It refuses dirty,
  unpublished changed, mismatched, foreign, or repository-root targets.
- When an owning process ended before `mark`, first inspect its bound branch for
  publication and an existing pull request. Record a found pull request with
  `mark`; if a branch was published without one, finish or explicitly block that
  publication rather than discarding its identity. Only when no publication
  occurred, use `cleanup` first when its recorded bound or preparing worktree
  exists, then `recover` with the exact attempt key and owner. If preparation
  stopped after persisting the target but before creating its path, skip cleanup
  and recover the missing target directly; recovery removes an exact stale Git
  worktree registration before releasing ownership. Recovery refuses live
  worktrees, published branches, and terminal outcomes. A preparing target is
  removed only when its checkout is clean and still detached at the base or its
  exact prepare-owned branch can be deleted with a head compare-and-swap.

Return one compact sweep report using only `pull-request`, `not-reproduced`,
`needs-shaping`, `blocked`, `invalid-follow-up`, and `skipped-unchanged`. Link
each pull request and state the evidence or next condition for every other
outcome. Never label a retained follow-up as fixed.
