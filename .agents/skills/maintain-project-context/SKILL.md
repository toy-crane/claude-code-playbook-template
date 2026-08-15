---
name: maintain-project-context
description: Clean, compact, and reconcile durable project context without changing established meaning. Always use this skill whenever a request cleans, audits, or checks consistency across two or more durable context sources, even when they are called product docs, glossary, decisions, specs, or agent instructions instead of PRODUCT.md, GLOSSARY.md, docs/decisions, docs/specs, AGENTS.md, or CLAUDE.md. Also use for confirmed shipped-spec retirement. Do not use to define new product intent, record one newly settled term or decision, look up context, shape a feature, or implement work.
---

# Maintain Project Context

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
user to settle that meaning. Use `define-product` when it is available and the
user wants to reopen the product premise; otherwise ask the same exact product
question directly.

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

## Finish

Finish when every safely resolvable subject has one owner and one current
representation, confirmed shipped specs are retired, optional current surfaces
contain no known stale duplication, and ambiguous meaning remains preserved.

Report what changed, what was deleted, what was intentionally left unchanged,
and the exact question needed for every unresolved conflict or unclear
shipment.
