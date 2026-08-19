---
name: define-product
description: Interview the user to define or revise the app's overall product direction, then preserve the confirmed meaning in root PRODUCT.md. Always use for a new app direction or any app-wide change to users, usage situations, problem, promised change, core loop, durable boundaries, experience principles, success signals, assumptions, or unknowns, even when PRODUCT.md is not named. Start from an existing definition or a rough app direction. Do not use for blank-page idea discovery, architecture, or shaping or specifying one feature or work unit.
---

# Define Product

Draw out the product meaning the user has in mind, then preserve it in the
repository's single current account of what the app is and why it matters. A
rough direction starts the conversation; it does not supply the missing product
meaning.

## Require a direction seed

Start with an existing product definition or at least one rough audience,
situation, problem, intended change, or broad solution direction the user wants
to pursue. When none exists, state the missing input and stop without mining
personal traces, manufacturing opportunities, or creating `PRODUCT.md`.

Treat a broad solution such as "turn a web page into Markdown" as enough to
begin an interview, not as evidence for an unstated user, problem, workflow, or
measure of success.

## Read the current context

Read root `PRODUCT.md` when it exists. Also read `GLOSSARY.md` and the relevant
subjects from `docs/decisions/README.md` when present.

Keep these sources distinct:

- The user's explicit statements provide intended product meaning.
- The current `PRODUCT.md` provides the existing intended meaning until the
  user confirms a change.
- Code provides evidence of current behavior, not proof of intended meaning.
- Repository evidence and authoritative external sources provide facts, not
  product choices.

Check only facts that can change the next question or the final definition.
When the existing meaning, a new request, and current behavior disagree, show
the difference plainly and ask which meaning should govern. Preserve the
current file until that choice is clear.

## Draw out the product meaning

Use the following areas as a check on the final definition, not as a
questionnaire the user must fill out:

- one-sentence app definition;
- primary users and the situations in which they use it;
- the problem and what they do instead today;
- the change the app promises for the user;
- the recurring core loop;
- app-wide capabilities and product boundaries;
- experience principles;
- observable success signals;
- material assumptions and unknowns.

When the user, situation, problem, or current alternative is unclear, begin
with one concrete use scene. Ask who is doing what, what they encounter, and
what they do today. Ask one to three closely related questions in a round; when
one answer determines the next question, ask only that one and wait.

Ask open questions when drawing out meaning the user may already have in mind.
Do not recommend an answer or supply leading choices in those questions. If an
answer stays broad, ask for a concrete situation or an observable change rather
than translating words such as "everyone", "easy", or "fast" into settled
product meaning.

Keep the current problem separate from the promised change. Ask what should
become different instead of treating the opposite of today's problem as the
user's confirmed goal.

After each answer, reflect only what became newly clear and move to the next
meaningful gap. Keep the full list of missing areas internal until the final
draft, and do not ask again for meaning the user already supplied.

## Handle choices the user has not made

When the user says a product choice has not been made, ask whether to leave it
unknown for now or decide it together. Offer options and a recommendation only
after the user asks for help making that choice.

When a concrete use scene could clarify that undecided choice, ask for the
scene first. Do not turn an abstract uncertainty into a choice between options
before understanding how the product would actually be used.

When the user delegates a choice, make its scope clear: name the exact choice,
the criteria that matter, and any limits. Then disclose the selected answer and
the reason. A broad "you decide" does not grant authority over unrelated
product meaning.

When the user delegates "the rest" without those limits, state which central
meaning still needs their input and continue from an actual use scene. Do not
promise to fill that meaning later unless the user names the choices being
delegated, the criteria, and the limits.

Keep these states separate while working:

- meaning the user directly confirmed;
- a choice made within the user's explicit delegation;
- an unsupported belief the user accepted as an assumption;
- an important point the user chose to leave unknown;
- an AI proposal that is not settled yet.

Silence or missing information does not settle, delegate, assume, or defer a
product choice. Record an assumption or unknown only after the user agrees to
leave it in that state.

## Decide when the definition is ready

Continue the interview while an unanswered point could materially change the
app definition, its users and situations, the recurring problem and current
alternative, the promised change, the core loop, or a durable boundary. Ask
about other areas only when their answer would change later product work; do not
manufacture detail merely to fill a section.

Do not create `PRODUCT.md` while the central user, situation, problem, current
alternative, promised change, or core loop remains a guess or an unacknowledged
gap. Explain what is still missing and continue the interview. A less central
gap may remain only when the user accepts it as an assumption or intentionally
leaves it unknown.

Show the full product direction once before writing. Clearly separate what the
user confirmed, what was decided under delegation, and what remains an accepted
assumption or intentional unknown. Ask the user to confirm or correct that
draft.

A detailed initial request may count as that confirmation only when it
explicitly asks for the file, every material product statement can be written
without guessing, and no existing product meaning conflicts with it. In that
case, write without repeating questions or asking for another approval.

## Write the current product context

Create or update only root `PRODUCT.md` using the
[product context format](./templates/product.md). Rewrite the current account
in place; do not append chronology, create dated versions, or preserve obsolete
meaning beside the current premise.

Place a settled delegated choice in the product section it affects. Keep the
fact that it was delegated and the reason visible in the pre-write draft and
completion report rather than adding a separate provenance section to
`PRODUCT.md`.

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

Finish when the user has confirmed the complete product direction and a later
agent can understand it quickly without mistaking a guess for intent. Report
the updated `PRODUCT.md`, the material meaning established or changed, choices
made under delegation, and accepted assumptions or intentional unknowns.
