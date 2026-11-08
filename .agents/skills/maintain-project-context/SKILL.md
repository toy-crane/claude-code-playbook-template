---
name: maintain-project-context
description: Clean, compact, and reconcile durable project context and any configured issue-tracker mirror without changing established meaning. Always use this skill whenever a request cleans, audits, or checks consistency across two or more durable context sources, even when they are called product docs, glossary, decisions, specs, or agent instructions instead of PRODUCT.md, GLOSSARY.md, docs/decisions, docs/specs, AGENTS.md, or CLAUDE.md. Also use for confirmed shipped-spec retirement or a full consistency sweep between default-branch spec folders and their tracker issues. Do not use to define new product intent, record one newly settled term or decision, look up context, shape a feature, implement work, or revise an active spec's behavior against work that has shipped, which belongs to `babysit-specs`.
---

# Maintain Project Context

This skill requires `define-product`. Before doing any work, confirm it is
installed. When it is missing, stop and report it with its install command,
`npx skills@latest add toy-crane/skills --skill define-product`, using the
project's package manager runner where it pins one.

Run a deliberate hygiene pass across the durable context that future work will
reuse. Make the current meaning easier to retrieve without becoming the
decision-maker for any artifact.

## Preserve authority

- Apply a meaning only when the user confirmed it, explicitly delegated that
  class of decision, or an authoritative project source already states it.
- Use shipped code to spot stale documentation, not to prove intent. Do not
  change product code during this pass.
- Leave sources unchanged when their intended meaning conflicts or shipment is
  unclear. Ask the exact question required to continue; never choose by file
  date, implementation prevalence, labels such as `accepted`, or silence.
- Preserve a current fact or decision only in the artifact that owns it. Do not
  build a parallel summary or copy the same authority across files.

## Inspect the durable surfaces

Inspect only the surfaces that exist or are required by the cleanup:

- root `PRODUCT.md` for the app-level product premise;
- root `GLOSSARY.md` for current project terms;
- `docs/decisions/README.md` and the relevant subject contracts;
- `docs/specs/<slug>/` folders whose work may have shipped;
- always-loaded repository guidance such as `AGENTS.md` and `CLAUDE.md`.

Do nothing merely because an optional file is absent. This is a periodic
cross-artifact pass, not the incremental capture of a single newly settled term,
decision, or follow-up.

## Maintain product context

When `PRODUCT.md` exists, compare its claims with explicit current product
decisions and other authoritative context. Remove duplicated or obsolete
wording and apply already-settled product meaning while preserving still-current
content.

Keep `PRODUCT.md` product-only: app definition, users and situations, problem
and alternatives, promised change, core loop, app-wide capabilities and
boundaries, experience principles, success signals, assumptions, and unknowns.
Do not move stack, architecture, repository mechanics, screen requirements,
work-unit scope, or acceptance criteria into it.

When a proposed edit would choose a new audience, problem, promise, core loop,
product boundary, or other product intent, leave the file unchanged and ask the
user to settle that meaning. When the user wants to reopen the product
premise, invoke `define-product` with the current `PRODUCT.md`, the exact
ambiguity found, and the surfaces that depend on it, so it revises only that
part of the premise; it hands back the updated `PRODUCT.md`, after which this
pass resumes and reconciles the remaining durable surfaces against it.

## Maintain decision contracts

List `docs/decisions/` and read its index when it exists. Check for files
missing from the index, then compare relevant subjects with current context and
remaining specs.

Keep one editable decision file per subject. Use Git for history instead of
keeping old decision files in the active folder. When several files clearly
agree on one decision, merge them under the clearest stable subject name. Update
every inbound link before deleting redundant files.

Every decision contract created or edited in this pass needs a subject title
and these required sections:

- `Decisions`: every current rule;
- `Why`: the minimum reason needed to apply the rule without repeating the same
  debate.

Add these sections only when they carry current value:

- `Boundaries`: limits or exceptions;
- `Reconsider when`: a specific condition that should reopen the decision;
- `Still-rejected alternatives`: a future agent might retry a rejected path;
- `Evidence worth preserving`: a measurement or experiment would be costly to
  reproduce.

Remove status fields, supersession chains, adoption or update dates,
pull-request order, and old implementation notes. Keep a date when it sets a
current rule or tells future work when to reconsider.

Before removing other content, ask whether its absence could make a capable
future agent repeat the same proposal, investigation, experiment, or failed
approach under the same conditions. If so, keep the shortest explanation that
prevents repetition. Remove duplicates and alternatives that cannot reasonably
recur.

## Maintain related files

- In `docs/decisions/README.md`, keep exactly one entry per decision file:
  `- [subject](subject.md) — Read when ...`. Make every link work. The routing
  phrase says when to open the file, not what it decided.
- In `GLOSSARY.md`, keep only terms the project currently uses and rewrite a
  definition only when the project's language has already changed.
- For each `docs/specs/<slug>/` confirmed as shipped, first preserve every
  qualifying reusable decision in its owning contract, then delete the folder.
  If shipment is unclear, leave it and ask. In active specs, update only links
  and terms already confirmed elsewhere.
- In always-loaded instructions, keep repository working rules and a route to
  the decision index. Remove copied decision or product content without changing
  unrelated instructions.

Create, rename, or rebuild decision contracts and their index when the cleanup
requires it. Do not merge unrelated subjects or remove necessary instructions
to hit a size target. Report an index or always-loaded file that remains hard to
navigate and explain why.

## Reconcile the issue-tracker mirror

When `AGENTS.md` or `CLAUDE.md` carries an `## Issue tracker` section, read both
files and use the first section found and its linked detailed convention when
present. Existing inline conventions remain valid; the setup skill need not be
installed. If the linked document cannot be read, report that tracker work is
blocked and continue repository context maintenance. Treat its issues as a derived coordination
surface, never as authority for product meaning, shipment, terms, or decisions.
Do not import issue prose or comments into durable project context.

Resolve and fetch the remote's advertised default branch. Compare the tracker
with `docs/specs/<slug>/` folders on that fetched branch, not with unmerged
changes in the current checkout. Each folder's `spec.md` names its one issue
with an `Issue: <tracker>:<id>` line; fetch every issue by that ID. Never list
issues or search them by title to find a folder's issue, and do not hunt for
orphan or duplicate issues; a person tidies duplicates in the tracker. If the
convention still describes a `spec:<slug>` title key, a `Source-Issue` line,
or a managed-issue listing, tell the user to rerun `setup-issue-tracker`
instead of using those operations, and to rename `Source-Issue:` to `Issue:`
in active spec folders themselves; the old line is not read.

For each default-branch spec folder, apply the rules below:

- Report a folder without an `Issue:` line, or whose ID cannot be fetched,
  and create nothing; the next PR that carries the folder creates its issue.
- Refresh only the issue's spec section, between the convention's markers,
  from the fetched `spec.md`:
  the text of its first section, the remaining section headings, the folder
  path, and its `Blocked by: docs/specs/<other>/` issue references. Keep the
  issue's title and every other part of its body, whether a person or an agent
  created it.
- Replace its blocker set with the issues named by the `Issue:` lines of its
  `Blocked by` folders, removing stale edges and adding missing ones while
  preserving its assignee and open or closed state. When a blocker folder has
  no `Issue:` line, report it and leave the dependent issue's entire blocker
  relation set unchanged rather than removing edges on partial information.
- Never close an issue because its folder is absent, and never reopen a closed
  issue merely because its folder remains. Only confirmed implementation
  delivery or the recorded tracker convention settles closure.

Search merged PR bodies for exact `Issue: <tracker>:<id>` lines, including PRs
whose spec folder has since been deleted, and fetch each issue by that ID. A
merged PR is durable retry evidence for a failed close only when its diff and
verification establish implementation delivery for that issue; a `Spec-Folder`
trailer, linked spec PR, `Issue:` line, or missing folder alone is
insufficient. Retry the convention's close operation for an open issue, then
verify its state. For a merged spec-only PR with no implementation delivery,
keep the issue open. If it still carries the PR review or active-work signal,
check for newer implementation work, then use the convention's mark-ready
operation and verify the result. Never demote work that has already started.
Report the exact missing PR evidence or failed operation when neither safe
closure nor a ready transition can be established. This catch-up also applies
when the original merge run reported a tracker failure; do not depend on that
run's branch or commit trailers surviving a squash merge.

If the configured tool is unavailable or any operation fails, finish the
repository cleanup, report the incomplete tracker operation and reason, and
preserve the remaining issue state for a later pass.

## Finish

Finish when every safely resolvable subject has one owner and one current
representation, confirmed shipped specs are retired, optional current surfaces
contain no known stale duplication, the configured tracker mirror is reconciled
as far as its recorded operations allow, and ambiguous meaning remains
preserved.

Report what changed, what was deleted, what was intentionally left unchanged,
the tracker issues updated, closed, or left unchanged with a reason, and the exact
question needed for every unresolved conflict or unclear shipment.
