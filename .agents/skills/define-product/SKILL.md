---
name: define-product
description: Create or update root PRODUCT.md, the durable app-level product definition. Always use this skill whenever a request establishes or changes the app's overall product meaning, even when PRODUCT.md is not named, including target users, usage situations, problem, promise, core loop, durable product boundaries, experience principles, success signals, assumptions, or unknowns. Start from an existing definition or a rough app direction. Do not use for blank-page idea discovery, architecture, or shaping or specifying one feature or work unit.
---

# Define Product

Create or revise the repository's single current account of what the app is and
why it matters. Keep later work from reconstructing the product premise from
conversation or unrelated implementation artifacts.

## Require a direction seed

Start with an existing product definition or at least a rough app direction or
problem the user already wants to pursue. When none exists, state the missing
input and stop without mining personal traces, manufacturing opportunities, or
creating `PRODUCT.md`.

Do not require a polished concept. A concrete audience, recurring situation,
problem, intended change, or broad solution direction is enough to begin.

## Ground the current meaning

Read root `PRODUCT.md` when it exists. Also read `GLOSSARY.md` and the relevant
subjects from `docs/decisions/README.md` when present. Use repository evidence
and authoritative external sources to resolve factual questions before asking
the user, especially when current alternatives or environmental change matter.

Treat code as evidence of current behavior, not proof of intended product
meaning. When sources disagree about the premise, preserve the current file and
ask the exact question needed to identify the intended meaning. A direct
user-confirmed change may replace prior product meaning; code, recency, and
silence may not.

## Converge the product premise

Present a concrete interpretation for the user to correct instead of walking a
fixed questionnaire. Cover the following product-level context:

- one-sentence app definition;
- primary users and the situations in which they use it;
- the problem and current alternatives;
- the change the app promises for the user;
- the recurring core loop;
- app-wide capabilities and product boundaries;
- experience principles;
- success signals;
- material assumptions and unknowns.

Resolve what available evidence already answers. Label unsupported beliefs as
assumptions or unknowns instead of turning them into product facts.

When a consequential product choice depends on the user, ask exactly one
question about it, include a recommended answer and concise reason, then wait.
Choose routine, reversible wording and organization without asking. Stop asking
when every material gap is resolved or explicitly represented as an assumption
or unknown.

## Write the current product context

Create or update only root `PRODUCT.md` using the
[product context format](./templates/product.md). Rewrite the current account
in place; do not append chronology, create dated versions, or preserve obsolete
meaning beside the current premise.

Keep the file product-only:

- Describe app-wide capabilities as stable boundaries, not a feature backlog.
- Describe experience principles as qualities the product should protect, not
  a visual system or screen design.
- Keep enough rationale to interpret the premise, without marketing persuasion,
  company background, or sales calls to action.
- Leave technology, architecture, data and file structure, repository mechanics,
  implementation plans, individual screens, detailed feature requirements, and
  work-unit acceptance criteria in their existing artifacts.

Do not create a work-unit spec or begin shaping or implementation as part of
this skill.

## Finish

Finish when a later agent can understand the app premise quickly, all required
product categories are findable, and remaining uncertainty is honest. Report
the updated `PRODUCT.md`, the material product meaning established or changed,
and the assumptions or unknowns that future work must not mistake for facts.
