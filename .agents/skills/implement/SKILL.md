---
name: implement
description: Implement or resume settled work from a selected spec folder. Use when the user provides a `docs/specs/SLUG/` folder and wants its settled spec or approved tasks completed in the current checkout with verification and the current harness's native review process.
---

# Implement

Treat the selected spec folder as the complete settled handoff. If approved
task files exist under `tasks/`, implement them sequentially in dependency
order. Otherwise implement `spec.md` directly.

After an actual interruption, reconstruct progress from the spec folder, Git,
diff, and tests, then continue the remaining work. Confirm ownership before
incorporating ambiguous dirty changes.

Complete each outcome and its acceptance criteria with focused verification.
When task files exist, check their acceptance criteria, mark finished tasks
`completed`, and record verification evidence. Where commits are expected,
commit code, tests, and the task update together as a meaningful checkpoint.

After all outcomes, run the complete required verification, then use the
current harness's native review process on the entire implementation diff. Fix
blocking findings and repeat the affected verification and review until no
blocker remains. Completion requires every acceptance criterion to pass. If the
harness review is unavailable, report it as the remaining completion gate.
