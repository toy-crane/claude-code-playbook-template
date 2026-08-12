---
name: implement
description: Implement or resume settled work from a selected spec folder. Use when the user provides a `docs/specs/SLUG/` folder and wants its settled spec or approved tasks completed in the current checkout with verification, the current harness's automated code-review process, and a runnable product handoff when the repository exposes one through a local server.
---

# Implement

Treat the selected spec folder as the complete settled handoff. If approved
task files exist under `tasks/`, implement them sequentially in dependency
order. Otherwise implement `spec.md` directly.

Use the `tdd` skill where behavior can be verified through a pre-agreed public
seam.

Use an available runtime-verification skill that matches each affected surface.
If none is available, verify the changed behavior through the repository's
supported runtime. If the changed behavior cannot be verified in the running
product, leave verification incomplete. Builds, type checks, and tests do not
replace this runtime check.

After an actual interruption, reconstruct progress from the spec folder, Git,
diff, and tests, then continue the remaining work. Confirm ownership before
incorporating ambiguous dirty changes.

Complete each outcome and its acceptance criteria with focused verification.
When task files exist, check their acceptance criteria, mark finished tasks
`completed`, and record verification evidence. Where commits are expected,
commit code, tests, and the task update together as a meaningful checkpoint.

After all outcomes, run the complete required verification, then use the
current harness's automated code-review process on the entire implementation
diff against the selected spec and acceptance criteria. Prefer a
model-invocable review facility when the harness provides one. Fix blocking
findings and repeat the affected verification and review until no blocker
remains. A rejection recorded only in an earlier session is not current
evidence; before handing off on that basis, retry the reviewer once in the
active session.

Completion requires every acceptance criterion and the final review gate to
pass. If the current review cannot produce an outcome because it is user-only,
rejected, errors, or times out, report an exact user-invocable command when the
active harness confirms one. In Claude Code, the Skill tool may expose the
reviewer as `code-review` even when user-facing aliases exist; use `/review`
when the active session confirms that equivalence. If no confirmed command
is available or no review facility exists, report the reviewer's unavailability
as the remaining gate. Leave either fallback with the review gate outstanding
and do not claim completion.

After all acceptance criteria and the final review gate pass, when the
repository exposes the implemented result through a user-reviewable local
server, run the actual product through its repository-supported development or
preview path. Verify the changed routes and essential states in that running
instance, then share an address the user can open and name what to review.

Reuse a healthy server owned by the current checkout or start an isolated
instance while preserving other checkouts and unrelated processes. Keep the
server running until the user finishes review or a later authorized delivery
step cleans up the current checkout. When the active environment cannot provide
a reachable address, report the exact launch command and blocker as the
remaining handoff limitation. Access to the running result does not imply human
approval.
