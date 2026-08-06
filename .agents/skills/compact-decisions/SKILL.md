---
name: compact-decisions
description: Clean up project decision files after shipped work has accumulated. Use periodically when decisions overlap, shipped spec folders remain, the decision index is out of date, or the glossary and always-loaded instructions contain stale or duplicated information. Do not use to make new decisions or guess which conflicting decision is current.
---

# Compact Decisions

Run this cleanup periodically after shipped work accumulates. Shorten the
records without changing the decisions.

## Do not invent decisions

- Keep a current decision file unless another file conflicts with it. Do not
  reconstruct how or when it was adopted.
- Move a choice into `docs/decisions/`, or choose between conflicting files,
  only if the user confirmed it or explicitly delegated that kind of decision.
- Use shipped code only to spot outdated documentation. Code and silence do not
  prove intent. Do not change code during this cleanup.
- If files disagree and the user's intent is unclear, leave them unchanged and
  ask the exact question needed to resolve them. Never choose based on which
  file is newer, what the code does, or the user's silence.

## Clean up decision files

List the files in `docs/decisions/` and read its index when it exists. Check for
files missing from the index, then compare relevant files with shipped code and
remaining specs.

Keep one editable decision file per subject. Use Git for history instead of
keeping old decision files in the active folder.

When several files clearly agree on one decision, merge them under the clearest
stable subject name. Update every link that points to the old files before
deleting them.

Every decision file you create or edit needs a subject title and two sections:

- `Decisions`: every current rule;
- `Why`: the minimum reason needed to apply the rule without repeating the same
  debate.

Add these sections only for the stated reason:

- `Boundaries`: the rule has limits or exceptions;
- `Reconsider when`: a specific condition should reopen the decision;
- `Still-rejected alternatives`: a future agent might retry a rejected approach;
- `Evidence worth preserving`: a measurement or experiment would be costly to
  reproduce.

Do not create empty sections. Remove status fields, supersession chains,
adoption or update dates, pull-request order, and old implementation notes. Keep
a date when it sets a current rule or tells future work when to reconsider.

Before deleting other content, ask whether its absence could make a capable
future agent repeat the same proposal, investigation, experiment, or failed
approach under the same conditions. If so, keep the shortest explanation that
prevents repetition. Remove duplicates and alternatives that cannot reasonably
recur.

## Clean up related files

- In `docs/decisions/README.md`, keep exactly one entry for every decision file:
  `- [subject](subject.md) — Read when ...`. Make every link work and include
  every decision file once. `Read when ...` says when to open the file, not what
  it decided.
- When `GLOSSARY.md` exists, keep only terms the project currently uses. Rewrite
  definitions when the project's language has already changed.
- For each `docs/specs/<slug>/` folder confirmed as shipped, first record any
  decision that future work should reuse in the right decision file, then delete
  the folder. If shipment is unclear, leave it and ask. In active specs, update
  only links and terms already confirmed elsewhere; do not change open choices.
- In files agents read on every task, such as `CLAUDE.md` and `AGENTS.md`, keep
  repository working rules and a link to `docs/decisions/README.md`. Remove
  copied decision content, but do not change unrelated instructions.

Do nothing merely because an optional file is missing. Create, rename, or
rebuild decision files and the index when needed. If the always-loaded
instructions or index have become hard to navigate, report why. Do not remove
necessary instructions or merge unrelated subjects to hit a size target.

## Finish and report

Finish when:

- each subject that can be resolved safely has one decision file and one index
  entry;
- no clearly shipped spec remains unless a reported issue prevents safe
  deletion;
- the glossary, when present, contains only current terms;
- always-loaded instructions contain no copied decision content;
- every decision file created or edited in this cleanup follows the section
  rules above and contains no history-only fields.

Report what changed, what was deleted, what was intentionally left unchanged,
and the exact question needed for every unresolved conflict or unclear shipment.
