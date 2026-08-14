---
name: implement
description: Implement or resume settled work from a selected spec folder. Use when the user provides a `docs/specs/SLUG/` folder and wants its settled spec or approved tasks completed in the current checkout with verification, the current harness's automated code-review process, and a runnable product handoff when the repository exposes one through a local server.
---

# Implement

## Load the current handoff

Treat `spec.md` as the approved product contract. Non-superseded approved task
files, when present, form its current shallow delivery map: `pending`,
`in-progress`, and `blocked` tasks are active unfinished work, while `completed`
tasks are current proof. A `superseded` task is inactive recovery history;
exclude it from the frontier, blockers, reconciliation, and completion gates,
but inspect it when current evidence implicates its prior implementation. If an
active task still names superseded history as a blocker, reconcile that stale
reference before continuing.

Before selecting or starting each outcome, and again after an interruption,
reconstruct current truth from the spec, every active unfinished task, any
completed or superseded task implicated by current evidence, relevant project
decisions, code, Git state and current diff, and verification evidence.
Repository evidence outranks remembered conversation; rerun verification that
predates the relevant code. Preserve completed outcomes whose current evidence
still passes, and confirm ownership before absorbing ambiguous dirty changes.
Then work sequentially from the current unblocked frontier; when no task files
exist, implement `spec.md` directly.

Derive only the active outcome's technical approach just in time. A task
boundary requires this reload; it does not by itself require a new session,
worker, or reviewer. Keep the spec folder as the single handoff instead of
adding a roadmap, execution ledger, durable implementation plan, or run-state
file.

## Implement and reconcile one outcome

Use the `tdd` skill at a pre-agreed public seam when available. Otherwise retain
the same observable seam and implement one red-to-green behavior at a time.

Use an available runtime-verification skill matching each affected surface, or
verify through the repository's supported runtime. Keep the outcome incomplete
when its changed behavior cannot be verified in the running product; builds,
type checks, and tests do not replace runtime evidence.

Complete the outcome and its acceptance criteria with focused verification.
Before marking it complete or starting dependent work, reconcile the observed
behavior with the product contract and every active unfinished task. This gate
also applies when implementing `spec.md` without task files.

For a verified discovery that preserves the product contract:

- Correct the active outcome's disposable technical approach and any recorded
  technical assumption.
- Persist actual downstream effects in affected active unfinished task
  boundaries, order, blockers, task-specific constraints, verification, or
  observably equivalent task-acceptance wording. Record concise revision
  evidence and preserve unaffected task contracts.

When tasks exist, record current status and whichever verification, blocker, or
revision evidence applies. Where commits are expected, commit code, tests, and
the task update as one meaningful checkpoint. Run only task-declared
intermediate review checkpoints; reconciliation adds no review checkpoint.

## Preserve authority and durable discoveries

Implementation authority covers the technical path and active unfinished task
map only while the approved product contract stays intact. When a discovery
would change an approved outcome, scope, observable spec acceptance criterion,
off-limits area, or other product constraint, preserve the current artifacts
and evidence, leave the affected outcome and its dependents blocked, and stop
before absorbing the change. Present the exact decision for the user to settle
through shaping.

If later code, integration, verification, or review invalidates a completed
task, preserve its prior evidence and return it to `in-progress` or `blocked`.
Keep dependent and final work blocked until that task's acceptance criteria and
focused verification pass again. `completed` means current proof, not historical
success.

Resolve in-scope discrepancies and affected tasks in the current work. Route a
workaround whose root cause remains open, or an evidenced out-of-scope defect,
through `project-knowledge` at discovery time. If unavailable, write the
symptom, observed evidence, suspected cause, what was tried, and proposed next
step to `docs/follow-ups/<slug>.md`.

## Pass the final gates

After every outcome passes reconciliation, run the complete required
verification and the current harness's automated code review on the entire diff
against the selected spec and acceptance criteria. Prefer a model-invocable
reviewer. A rejection recorded only in an earlier session is not current
evidence; retry that reviewer once in the active session.

Completion requires every acceptance criterion, reconciliation gate, complete
verification, and final review to pass. A current user-only result, rejection,
error, or timeout leaves the review gate open. Hand off an exact user command
only when the active harness confirms it for that reviewer. In Claude Code,
`/review` may alias `code-review`; use only the command the active session
confirms. When the reviewer exists but no user command is confirmed, report that
handoff as unavailable. When no review facility exists, report the missing
facility. Both states remain incomplete.

## Hand off the runnable product

After the final gates pass, when the repository exposes the actual result
through a user-reviewable local server, run it through the supported development
or preview path. Verify the changed routes and essential states, share a
reachable address, and name what to review.

Reuse a healthy server owned by the current checkout or start an isolated one
while preserving other checkouts and unrelated processes. Keep that server
running until review finishes or authorized delivery cleanup stops it. If the
environment cannot provide a reachable address, report the exact launch command
and blocker without claiming a working URL. When the repository has no such
server, hand off its verified result without inventing one. Access to a running
result is evidence delivery, not human approval.
