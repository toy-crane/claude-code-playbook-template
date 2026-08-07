---
name: split-into-tasks
description: Split an implementation-ready spec into the fewest independently deliverable vertical tasks and select only risk-justified intermediate review checkpoints. Use when a spec has multiple outcomes needing separate delivery or dependency tracking; keep one coherent outcome as the spec itself.
---

# Split Into Tasks

Require `docs/specs/<slug>/spec.md`; if it is missing, stop before proposing
tasks.

Read the spec, current code, relevant project decisions, glossary, and approved
prototype. Treat missing implementation as work to do and conflicting sources
as decisions to resolve. Keep one coherent deliverable as the spec itself.

Draft the fewest **tracer-bullet** tasks. Each task must deliver a complete,
independently usable and verifiable path through every layer it touches. Put
preparation in the first task that makes it useful, and declare only blockers
that genuinely prevent a dependent outcome. Size tasks by delivered outcomes,
not predicted context length or technical layers.

Add an intermediate review checkpoint only when a material error could compound
through substantial dependent work, or when automated checks cannot adequately
settle a security, data, permission, migration, recovery, or external-contract
risk. Name its cumulative scope and concrete risk. The implementation phase
owns the final integrated review, so tasks declare intermediate reviews only.

Present the proposed tasks before writing files. Show each title, delivered
behavior, blockers with reasons, and any review checkpoint. Iterate until the
user approves the breakdown.

After approval, record shared settled constraints in the spec and only
task-specific constraints in task files. Do not invent unsettled behavior.

Publish each approved task to
`docs/specs/<slug>/tasks/<NN>-<slug>.md` using
[`templates/task.md`](templates/task.md), with blockers before dependents.
Preserve completed tasks when revising; after approval, replace superseded
unfinished tasks. End after publishing the task handoff.
