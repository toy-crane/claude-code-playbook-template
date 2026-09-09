---
name: implement
description: Implement or resume settled work from a selected spec folder as one handoff bundle. Use when the user provides a `docs/specs/SLUG/` folder and wants its settled spec or approved tasks completed in the current checkout with verification, one completed and triaged automated code review, and a runnable product handoff when the repository exposes one through a local server.
---

# Implement

## Load the current handoff

Treat the selected spec folder as one handoff bundle anchored by `spec.md`.
Before deriving an implementation approach or changing source, identify and
load its current required sources: the spec; every active unfinished task; any
completed or superseded task implicated by current evidence; project decision
contracts explicitly linked by the spec or active tasks, plus any other current
decision contract implicated by repository evidence; and every prototype,
screen, state, or other reference artifact that the spec or an active task
identifies as an approved or selected implementation reference. Read textual
sources and render or otherwise inspect visual artifacts so their operative
content is available before work starts. Presence in the folder alone does not
establish approval. An approved visual reference is a required, complementary
contract for the concrete screens and states it covers; explicit product
contracts retain their stated meaning. If required sources disagree, preserve
them, record the exact sources and affected behavior or screen-state coordinate,
and keep that outcome and its dependents blocked for shaping instead of choosing
a winner.

Non-superseded approved task files form the bundle's current shallow delivery
map: `pending`, `in-progress`, and `blocked` tasks are active unfinished work,
while `completed` tasks are current proof. A `superseded` task is inactive
recovery history; exclude it from the frontier, blockers, reconciliation, and
completion gates, but inspect it when current evidence implicates its prior
implementation. If an active task still names superseded history as a blocker,
reconcile that stale reference before continuing.

Before selecting or starting each outcome, and again after an interruption,
reconstruct current truth from the required handoff sources, code, Git state and
current diff, and verification evidence. Repository evidence outranks
remembered conversation; rerun verification that predates the relevant code.
Preserve completed outcomes whose current evidence still passes, and confirm
ownership before absorbing ambiguous dirty changes. Then work sequentially from
the current unblocked frontier; when no task files exist, implement `spec.md`
directly.

Derive only the active outcome's technical approach just in time. A task
boundary requires this reload; it does not by itself require a new session,
worker, or reviewer. Keep the spec folder as the single handoff instead of
adding a roadmap, execution ledger, durable implementation plan, or run-state
file.

## Implement and reconcile one outcome

Select a public test seam from the agreed behavior and existing interfaces.
Briefly state the seam and the behavior it will verify, then use the `tdd` skill
when available. Otherwise implement one red-to-green behavior at a time through
the selected seam. Resolve technical uncertainty through repository evidence;
ask the user only when expected behavior remains unclear or proceeding would
change the agreed product contract.

Derive the runtime evidence the active outcome owes from its acceptance
criteria, affected surfaces, claimed platforms, and any claim about a deeper
layer such as networking, native integration, component behavior, or
performance. Use an available specialized runtime-verification skill matching
each affected surface; it owns its framework-specific observation loop.

For a screen-based outcome with an approved visual or state reference, derive
the applicable screen, state, and viewport coordinates from that artifact and
compare the running implementation at each one. Verify concrete composition,
content, hierarchy, containment, placement and visibility, and the relevant
transitions and recovery; element existence and successful navigation alone do
not establish that match. Apply the reference within its stated limits, and use
runtime evidence for native behavior or other claims it does not cover. Every
platform named in the result owes actual-screen comparison for the same
applicable screens and states, using that platform's intended layout and native
conventions; evidence from one platform does not establish another.

When none is available, investigate the repository and current environment and
construct the strongest usable runtime path yourself. Consult current
authoritative guidance when a framework or tool's behavior matters. Do not ask
the user to approve this ordinary technical choice merely because a skill is
missing.

After a meaningful behavior change, exercise the smallest complete affected
flow in the running product. Establish that the current change is loaded, no
relevant runtime error occurs during reproduction, and the exact observable
result passes. Inspect a deeper layer only when the outcome claims it. If the
available in-scope paths cannot expose the changed behavior, record the exact
failed gate and prerequisite and keep the outcome incomplete; builds, type
checks, tests, screenshots, and code inspection do not replace runtime evidence.

Complete the outcome and its acceptance criteria with focused verification.
Before marking it complete or starting dependent work, reconcile the observed
behavior with every required handoff source and applicable acceptance or
reference criterion. This gate also applies when implementing `spec.md` without
task files.

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
intermediate review checkpoints, each one pass over its declared scope and risk,
triaged by the rules below; reconciliation adds no checkpoint.

## Preserve authority and durable discoveries

Implementation authority covers the technical path and active unfinished task
map only while the approved product contract stays intact. When a discovery
would change an approved outcome, scope, observable spec acceptance criterion,
off-limits area, or other product constraint, preserve the current artifacts
and evidence, leave the affected outcome and its dependents blocked, and stop
before absorbing the change. Apply the same boundary when an approved reference
and an explicit product contract disagree: report their exact difference rather
than treating either as a silent override. Present the exact decision for the
user to settle through shaping.

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

## Re-verify the product before review and after repairs

After all outcomes pass focused verification and reconciliation, rerun the
complete deterministic verification, then re-exercise the changed flow and a
representative journey derived from the root `PRODUCT.md` core loop in the
running product. Every platform named in the result owes its own runtime
evidence; never infer one platform from another.

When `PRODUCT.md` or its core loop is absent, re-verify the changed flow and
report the missing regression coverage without inventing a journey or editing
the file. When the core loop admits materially different journeys, preserve the
current evidence and return that product interpretation for clarification; it
is distinct from approval of the verification method.

## Complete one review of the whole diff, then triage

After every outcome passes reconciliation and the complete verification, obtain
one completed automated code review of the whole implementation diff against
the spec and its acceptance criteria. Count a pass only when the reviewer
finishes inspecting the intended scope and returns findings or an explicit
no-findings result. An invocation, partial output, or silent exit is not that
result. Skip a required review only when the user explicitly waives it, and
record the waiver's scope.

Use a reviewer the current harness lets you invoke. A prior session's user-only
restriction does not establish current availability; check it again. Choose
the depth this change warrants from the modes you can invoke yourself, weighing
what it touches against what verification
already settles, and name it, since a harness given no mode may reuse an
earlier one. A deeper mode reserved for the user is something to offer, not to
select. Take the harness's standard mode when nothing argues either way:
`code-review medium` in Claude Code, while Codex has no dial. Wherever the
reviewer accepts context, give it the required handoff sources or their
repository paths: the spec's approved scope, off-limits areas and remaining
risks, the active task contract, linked project decisions, and any approved
reference artifacts whose criteria apply to the diff. Check the reviewer's
reported scope against both that handoff and the diff you meant to review.
Findings about another target require retargeting, not repairs; that pass is not
spent.

For a review backed by a model service, identify the actual service and the
diff, spec, and related source context it will receive. Carry applicable user
authorization into the execution request and reuse it without asking again.
Read-only describes file access, not whether context leaves the machine. If
the service or source scope exceeds that authorization, request only the
missing authority; a skill instruction is not itself a grant of permission.

Recover command, compatibility, environment, and transient failures within the
authorized scope and retry. Failed or mistargeted attempts do not consume the
pass. Distinguish an explicit policy denial from those execution errors:
preserve its rationale, pursue only a materially safer permitted alternative,
or request the specific authority needed before retrying. Do not route the
same denied action through another tool or service to bypass the denial.
For a model-invocable reviewer blocked by missing user permission, establish the
actual service and source scope, then ask for that permission. A confirmed
manual command is not a substitute for resolving the missing authority.

When review cannot finish because of permissions, a user-only or absent
reviewer, or an unresolved execution failure, keep overall completion pending.
Preserve verified outcomes, provide their evidence and runnable handoff, and
name the exact blocker and next required action. Offer a user command only
when the active harness confirms it. For a declared intermediate checkpoint,
dependent work also waits for its review or explicit waiver.

Repair a finding only when it breaks an approved acceptance criterion, or is a
defect or regression you confirm by reproducing it on a path ordinary use
reaches; a reviewer's assertion is not that confirmation. Rerun the affected
verification. When the repair changes executable product behavior, it
invalidates the earlier final runtime evidence: re-run the changed-flow and
core-loop gate above on every claimed platform after the repair passes. Send no
scope through the reviewer twice, repairs included. Each scope gets one pass: a
declared checkpoint's cumulative scope, then the whole diff. Point anyone asking
for another look at a confirmed user command instead of invoking the reviewer
again.

Record every other finding rather than repairing it: an evidenced defect or open
workaround through `project-knowledge`, or as `docs/follow-ups/<slug>.md` when
that skill is absent; a trade-off the spec or a decision contract already
disposed of, as disposed; an out-of-scope, stylistic, or unconfirmed finding, in
the handoff; and a material consequence the spec leaves open, such as a security
trade-off or a pathological-input failure, as a decision the user owns, with
`human-review` offered for judging it.

Completion needs every required handoff source to have been inspected, every
applicable acceptance and approved-reference criterion to be reconciled with the
executable revision being handed off, each required review to have completed or
been explicitly waived by the user, and the must-fix findings to be repaired and
reverified. An uninspected required source or uncompared applicable criterion
keeps the result incomplete. A completed review may leave recorded findings; zero
findings is not the gate. Report the sources and reviewed scope used for the
claim, the result or explicit waiver, what changed, and what remains open.

## Hand off the runnable product

After that report, when the repository exposes the actual result through a
user-reviewable local server, run it through the supported development or
preview path. Verify the changed routes and essential states, share a
reachable address, and name what to review.

Reuse a healthy server owned by the current checkout or start an isolated one
while preserving other checkouts and unrelated processes. Keep that server
running until review finishes or authorized delivery cleanup stops it. If the
environment cannot provide a reachable address, report the exact launch command
and blocker without claiming a working URL. When the repository has no such
server, hand off its verified result without inventing one. Access to a running
result is evidence delivery, not human approval.
