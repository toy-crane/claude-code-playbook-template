---
name: split-into-tasks
description: Split an existing implementation-ready spec into the fewest independently deliverable, end-to-end task files with explicit blockers. Use when the spec contains multiple outcomes that benefit from separate delivery, review, or dependency tracking. A single coherent outcome keeps the spec itself as the sole handoff.
---

# Split Into Tasks

## Ground the breakdown

Work from an implementation-ready spec folder at `docs/specs/<slug>/`. When the
user has not named one, present the available candidates for selection. If no
such spec exists, ask the user to establish one before continuing.

Ground task boundaries in `spec.md`, `GLOSSARY.md`, any approved
`prototype.html`, relevant decision contracts found through
`docs/decisions/README.md`, and the current code. Treat behavior introduced by
the spec but absent from the code as the expected gap between current and target
behavior. Reserve conflicts for sources that disagree about an existing
decision.

When the spec describes one coherent deliverable, keep the spec itself as the
sole handoff.

## Choose task boundaries

Use the fewest delivery-sized vertical tasks. Make each standalone task an
independently usable, verifiable, and reviewable outcome through every layer it
touches. Keep work together when it becomes meaningful only as a complete
outcome.

Include preparatory work in the earliest task that turns it into usable
behavior. Split preparatory work into its own task when it independently meets
the same standard. Declare an unfinished task as a blocker when its outcome is
required to complete the dependent task. Tasks whose blockers are complete form
the frontier.

## Review before writing

Present the proposed breakdown before writing files. For each task, show its
title, the complete behavior that becomes available when it finishes, and each
blocker with the reason it gates completion. Refine task boundaries and
dependencies with the user. Explicit approval of the breakdown authorizes
writing the task files.

## Publish task files

Publish one file per approved task at
`docs/specs/<slug>/tasks/<NN>-<slug>.md`, numbered in dependency order with
blockers before dependents.

When revising an existing breakdown, preserve completed task files. After the
user approves the revised remainder, replace superseded unfinished task files
so the active tree reflects the approved remaining breakdown.

Each task file contains:

- title
- independently deliverable, end-to-end behavior from the user's perspective
- a `## Blockers` section naming each blocking task and why it gates
  completion; write `None.` when there are no declared dependencies
- status initialized to `pending`; later execution may change it only to
  `in-progress`, `completed`, or `blocked`
- outcome-level acceptance-criteria checkboxes for observable completed behavior
- constraints specific to that task's delivery or coordination
- mutable execution state copied from the
  [task state template](./templates/task-state.md)

Record constraints shared by multiple tasks in `spec.md` and constraints that
apply to one task in that task file. Describe observable behavior and settled
boundaries at a level that remains valid as the code evolves. Use an approved
prototype as the authority for the intended experience.

Copy the [task state template](./templates/task-state.md) without changing its
field names. Keep `## Status` and `## Execution` in every task. Keep
`## Run completion` only in the highest-numbered terminal task; remove that
section from every other task. Do not add a separate orchestration file.

## Revisit a breakdown

Return to this skill when new evidence invalidates task boundaries or blockers.
Reassess the affected unfinished tasks and apply the same review and publishing
rules to the revised remainder.
