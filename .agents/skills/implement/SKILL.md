---
name: implement
description: Implement or resume settled work from one selected spec folder as one handoff bundle. Use when the user provides a `docs/specs/SLUG/` folder and wants its settled spec completed in the current checkout with verification, one completed and triaged automated code review, and a runnable product handoff when the repository exposes one through a local server.
---

# Implement

This skill requires `tdd`, `llm-evals`, `babysit-specs`, and
`project-knowledge`. Before
doing any work, confirm each one is installed. When one is missing, stop and
report it with its install command,
`npx skills@latest add toy-crane/skills --skill <name>`, using the project's
package manager runner where it pins one.

## Claim the folder when a tracker coordinates it

The input is always one spec folder. When the repository's `AGENTS.md` or
`CLAUDE.md` carries an `## Issue tracker` section, read both files and use the
first found and its linked detailed convention before finding this folder's
issue. An `Issue: <tracker>:<id>` line in `spec.md` names the folder's one
issue; fetch it by that ID and never search the tracker by title. Existing
inline conventions remain valid. Use the convention's ID form, tool, and claim
operation without requiring `setup-issue-tracker` to be installed.
Claiming is the first write of the run, ahead of source or spec edits.
Check the convention's active-work signal before claiming: an issue already in
progress requires the user's explicit request to resume, even when its assignee
is the current account. Assign eligible work to the current tracker account and
apply the convention's active state. Stop without changing source and report
another account's claim, open blockers, an unreadable linked convention, or an
unavailable tracker tool; continue unclaimed only on explicit user instruction.
A folder without an `Issue:` line
proceeds unclaimed; the PR that carries it creates its issue. Without the
section, nothing here applies.

End every commit's message with a `Spec-Folder: docs/specs/<slug>/` trailer so
the pull request that follows can find the folder and close its issue; this trailer is
repository information and is written whether or not a tracker exists.

## Load the current handoff

Treat the selected spec folder as one handoff bundle anchored by `spec.md`.
Each run takes exactly one folder; when several are named, ask which one to
run, because the order of folders belongs to whoever starts each run. Before
deriving an implementation approach or changing source, identify and load its
current required sources: the spec; project decision contracts it explicitly
links, plus any other current decision contract implicated by repository
evidence; and every prototype, screen, state, or other reference artifact that
the spec identifies as an approved or selected implementation reference. Read
textual sources and render or otherwise inspect visual artifacts so their operative
content is available before work starts. Presence in the folder alone does not
establish approval. An approved visual reference is a required, complementary
contract for the concrete screens and states it covers; explicit product
contracts retain their stated meaning. If required sources disagree, preserve
them, record the exact sources and affected behavior or screen-state coordinate,
and keep that outcome and its dependents blocked for shaping instead of choosing
a winner.

Before selecting or starting each outcome, and again after an interruption,
reconstruct current truth from the required handoff sources, code, Git state and
current diff, and verification evidence. Repository evidence outranks
remembered conversation; rerun verification that predates the relevant code.
Preserve completed outcomes whose current evidence still passes, and confirm
ownership before absorbing ambiguous dirty changes. Then implement `spec.md`
directly, one outcome at a time.

Before changing source for an outcome, check the spec against what the
repository has done since. Compare its assumptions, settled constraints, and
acceptance criteria with the current code and the Git history since the spec
folder's last commit; your own commits advance that
baseline, so each check covers only what happened since the previous outcome.
A mismatch that would change an approved outcome, acceptance criterion,
off-limits area, or other product constraint stops that outcome before any
source change: name the stale point and its evidence, then route it to
`babysit-specs` for this spec folder alone, handing it the stale point and its
evidence; it hands back the revised `spec.md`, which this run reloads before
continuing. Naming the folder keeps the revision on the selected work unit;
you still
never read a sibling spec folder. A stale spec caught here
costs nothing, while the same discovery made mid-implementation discards work
already done.

Derive only the active outcome's technical approach just in time. An outcome
boundary requires this reload; it does not by itself require a new session,
worker, or reviewer. Keep the spec folder as the single handoff instead of
adding a roadmap, execution ledger, durable implementation plan, or run-state
file.

## Finish outside setup before changing source

When `spec.md` lists items under `## Setup before implementation`, finish them
after any claim and before the first source change. Do what you can of each
item yourself within your current tools and authority, then check every done
condition. If any item remains, report every remaining item at once, with what
is left for the user and its done condition, and stop without changing source.
Resume when the user says they are done and every condition passes; ask the
user to confirm a condition only when you cannot observe it yourself. Never ask
for, accept in chat, or print a secret value: the user places it where the
product reads it, and you check the condition through its observable effect or
the user's confirmation. A `None.` section or a spec without the section needs
nothing here.

## Implement and reconcile one outcome

Map every acceptance criterion of the active outcome to at least one check: an
automated test, an eval, runtime evidence, or a combination. A criterion about
the quality of LLM output that varies run to run, including a skill's or
agent's behavior, maps to an eval: a mocked model call proves only the code
around it. Hand `llm-evals` that criterion with its metric, held-out target,
and case source, the active outcome, and `spec.md` as design context. It hands
back the behavior change, the baseline and final held-out scores with their
noise floor, each round's change, and where the eval lives; an unreached
target comes back with the best score and failure causes, and that criterion
stays incomplete. Report each eval criterion with its baseline and final
scores as evidence. Behavior in the running product
still owes runtime evidence when a test also proves it. Hand the `tdd` skill
the active outcome, the criteria to prove by automated tests, the approved
references that apply to it, and `spec.md` as design context; the handoff does
not authorize later outcomes. `tdd` selects the
public test seams and hands back the code change, each new test tied to its
criterion or named reason with the failing assertion it was seen to produce,
and any handed criterion it could not prove automatically with the reason.
Cover those through runtime evidence or keep them incomplete.
Resolve technical uncertainty through repository evidence;
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

Once the acceptance criteria pass, probe next to each changed behavior before
the outcome counts as complete. At the same surface and through the same
runtime path, try at least one deliberate misuse the change points at, such as
an empty value, a repeated action, an action with other state still applied,
or an interruption, rather than a fixed checklist. Record each probe with what
it showed, including the ones the product held. Triage what probes find by the
same rules as whole-diff review findings below, and report any behavior the
spec leaves open as a decision the user owns. A repair made here reaches that
review; the final gate after review adds no probes.

Complete the outcome and its acceptance criteria with focused verification.
Before marking it complete or starting dependent work, reconcile the observed
behavior with every required handoff source and applicable acceptance or
reference criterion.

For a verified discovery that preserves the product contract, correct the
active outcome's disposable technical approach and any recorded technical
assumption, and let it inform the approach of later outcomes when you derive
them. Where commits are expected, commit each verified outcome's code and tests
together. Reconciliation adds no review pass.

## Preserve authority and durable discoveries

Implementation authority covers the technical path only while the approved
product contract stays intact. When a discovery would change an approved
outcome, scope, observable spec acceptance criterion, off-limits area, or other
product constraint, preserve the current artifacts and evidence, leave the
affected outcome and its dependents blocked, and stop before absorbing the
change. Apply the same boundary when an approved reference and an explicit
product contract disagree: report their exact difference rather than treating
either as a silent override. Present the exact decision for the user to settle
through shaping.

If later code, integration, verification, or review invalidates a completed
outcome, preserve its prior evidence and treat it as unfinished again. Keep
later and final work blocked until that outcome's acceptance criteria and
focused verification pass again. Complete means current proof, not historical
success.

Resolve in-scope discrepancies in the current work. Route a
workaround whose root cause remains open, or an evidenced out-of-scope defect,
through `project-knowledge` at discovery time, handing it the symptom, observed
evidence, suspected cause, what was tried, and proposed next step, and keep
the `docs/follow-ups/<slug>.md` path it reports for the handoff.

## Complete deterministic verification before review

After all outcomes pass focused verification and reconciliation, rerun the
complete deterministic verification. Keep the focused runtime evidence available
for review; run the final changed-flow and core-loop gate after review and
must-fix repairs, so that gate observes the revision being handed off.

## Complete one review of the whole diff, then triage

After every outcome passes reconciliation and the complete deterministic
verification, obtain one completed automated code review of the whole
implementation diff against
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
risks, linked project decisions, any approved
reference artifacts whose criteria apply to the diff, and the focused
verification evidence already collected. Check the reviewer's
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
when the active harness confirms it. A folder whose `Blocked by:` line names
this one waits for this review or its explicit waiver.

Repair a finding only when it breaks an approved acceptance criterion, or is a
defect or regression you confirm by reproducing it on a path ordinary use
reaches; a reviewer's assertion is not that confirmation. Rerun the affected
verification after repairs. Send the diff through the reviewer once, repairs
included. Point anyone asking
for another look at a confirmed user command instead of invoking the reviewer
again.

Record every other finding rather than repairing it: an evidenced defect or open
workaround through `project-knowledge` with the same five fields, keeping the
follow-up path it reports; a trade-off the spec or a decision
contract already disposed of, as disposed; an out-of-scope, stylistic, or
unconfirmed finding, in the handoff; and a material consequence the spec leaves
open, such as a security trade-off or a pathological-input failure, as a
decision the user owns.

## Verify the final product after review and repairs

After the whole-diff review is complete and triaged and any must-fix repairs
pass their affected verification, re-exercise the changed flow and a
representative journey derived from the root `PRODUCT.md` core loop in the
running product. An explicit review waiver also leads to this gate. Every
platform named in the result owes its own runtime evidence for the revision
being handed off; never infer one platform from another.

When `PRODUCT.md` or its core loop is absent, verify the changed flow and
report the missing regression coverage without inventing a journey or editing
the file. When the core loop admits materially different journeys, preserve the
current evidence and return that product interpretation for clarification; it
is distinct from approval of the verification method.

If final verification finds an in-scope defect, repair it, rerun the affected
checks, then repeat this gate on the repaired revision without a second review
pass. An executable repair invalidates earlier final runtime evidence, including
evidence brought from a run that verified before review. A blocked required
runtime check keeps completion pending with its exact failed gate and
prerequisite.

Completion needs every required handoff source to have been inspected, every
applicable acceptance and approved-reference criterion to be reconciled with the
executable revision being handed off, the whole-diff review to have completed or
been explicitly waived by the user, and the must-fix findings to be repaired and
reverified. An uninspected required source or uncompared applicable criterion
keeps the result incomplete. A completed review may leave recorded findings; zero
findings is not the gate. Report the sources and reviewed scope used for the
claim, each acceptance criterion with its checks and evidence, each probe with
what it showed, the result or explicit waiver, what changed, and what remains
open.

## Make the delivered change directly reviewable

Close the completion report by making the delivered product change directly
reviewable from the user's point of view. The user should not need to ask what
changed or request the important screens after the implementation is reported
complete.

Choose the strongest evidence the current executable revision affords and
present enough of it for the user to understand the resulting experience,
follow its important downstream effects, and notice a mismatch with the
approved intent. Use actual product views when the change is best judged
visually, observed behavior when interaction matters, and concise explanation
for rules that cannot be seen.

Do not organize this account around files or tests, although report relevant
verification separately. Do not present a prototype or stale capture as proof
of the delivered revision, and name anything important that could not be shown.

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
