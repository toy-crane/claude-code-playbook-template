---
name: define-publication
description: Interview the user to define or revise the standing premise of one writing medium, such as a product blog, newsletter, or brand site, then preserve it in docs/publications/<slug>.md. Always use for a new publication or any change to its readers, promised change, voice, coverage, medium conventions, or how a finished piece is evidenced, even when the file is not named. Start from a rough medium direction. Do not use to brief or draft one piece, and do not use for the app's product meaning, which belongs to define-product.
---

# Define Publication

Draw out what one publication is for and how it works, then preserve it as the
single current premise later pieces read. A rough direction starts the
interview; it does not supply the missing meaning.

## Require a direction seed

Start with an existing publication file or at least one rough medium the user
wants to write for: "a product blog", "a newsletter for customers", "copy for
the brand site". When none exists, state the missing input and stop without
inventing readers or creating a file.

Treat a medium name as enough to begin the interview, not as evidence for an
unstated reader, situation, promise, or voice.

## Read the current context

Read `docs/publications/` when it exists. If a file already covers the medium
the user names, that file is the current meaning until the user confirms a
change; a new medium gets a new file. Read root `PRODUCT.md` when it exists so
product facts can be referenced, and `GLOSSARY.md` plus relevant subjects from
`docs/decisions/README.md` when present, so the premise uses the project's
terms and reuses settled style decisions instead of restating them.

Keep these sources distinct:

- The user's explicit statements provide intended meaning.
- The current publication file provides the existing meaning until the user
  confirms a change.
- Existing pieces show what has been written, not what was intended.
- Repository evidence and authoritative external sources provide facts, not
  editorial choices.

Check only facts that can change the next question or the final premise. When
the existing meaning, a new request, and existing pieces disagree, show the
difference plainly and ask which meaning should govern. Preserve the current
file until that choice is clear.

## Draw out the premise

Use the following areas as a check on the final premise, not as a
questionnaire the user must fill out:

- primary readers and the situations in which they read;
- the change the publication promises its readers;
- voice and tone;
- what the publication covers and what it leaves out;
- medium conventions: the form and typical length of a piece, where finished
  pieces live in the repository, and how the rendered result is previewed;
- how a finished piece is evidenced: at minimum, that a reader with no other
  context can answer the piece's reader questions from the piece alone, and,
  for pieces carrying code, that every embedded code block and command runs as
  written;
- observable success signals;
- material assumptions and unknowns.

When the reader, situation, or promise is unclear, begin with one concrete
reading scene. Ask who meets the writing, in what situation, and what they read
instead today. Ask one or two closely related questions in a round; when one
answer determines the next question, ask only that one and wait.

Ask open questions when drawing out meaning the user may already have in mind,
except for the sample-based voice recommendation below.
Do not recommend an answer or supply leading choices in those questions. If an
answer stays broad, ask for a concrete reader or an observable change rather
than translating words such as "developers", "friendly", or "useful" into
settled meaning.

After each answer, reflect only what became newly clear and move to the next
meaningful gap. Keep the full list of missing areas internal until the final
draft, and do not ask again for meaning the user already supplied.

## Recommend voice through prose

Once the readers and purpose are known, propose one short illustrative paragraph
and a concise reason it suits them. The user need not choose tone adjectives or
presets first. A personal record may serve recollection without promising to
change its readers. Keep illustrative details distinguishable from known facts.

Invite a reaction to the actual sentences. When the user corrects the feeling,
revise the prose; when comparison would help, add an alternative with the same
content and claims. Describe the difference briefly. The sample remains a
proposal until accepted or settled within explicit delegation.

Retain the accepted sample and the characteristics the user confirmed, including
its intended scope and the choice that confirmed it. Update or remove that
example when later feedback replaces or rejects it. Preserve an already settled
voice, including concrete instructions in a complete explicit write request;
do not invent an accepted example or reopen it just to obtain one.

## Handle other choices the user has not made

When the user says a choice has not been made, ask whether to leave it unknown
for now or decide it together. Offer options and a recommendation only after
the user asks for help making that choice.

When the user delegates a choice, make its scope clear: name the exact choice,
the criteria that matter, and any limits. Then disclose the selected answer and
the reason. A broad "you decide" does not grant authority over unrelated
meaning.

Keep these states separate while working:

- meaning the user directly confirmed;
- a choice made within the user's explicit delegation;
- an unsupported belief the user accepted as an assumption;
- an important point the user chose to leave unknown;
- an AI proposal that is not settled yet.

Silence does not settle, delegate, assume, or defer a choice. Record an
assumption or unknown only after the user agrees to leave it in that state.

## Decide when the premise is ready

Continue the interview while an unanswered point could materially change the
readers, the promised change, the voice, the coverage, or how a piece is
evidenced, and write the file only once the central reader, situation,
promise, and voice are confirmed rather than guessed; until then, say what is
still missing and keep going. Ask about other areas only when their answer
would change later pieces; do not manufacture detail merely to fill a section.
A less central gap may remain only when the user accepts it as an assumption
or intentionally leaves it unknown.

Show the full premise once before writing. Clearly separate what the user
confirmed, what was decided under delegation, and what remains an accepted
assumption or intentional unknown. Ask the user to confirm or correct that
draft.

A detailed initial request may count as that confirmation only when it
explicitly asks for the file, every material statement can be written without
guessing, and no existing meaning conflicts with it. In that case, write
without repeating questions or asking for another approval.

## Write the current premise

Create or update `docs/publications/<slug>.md`, one file per medium with a
kebab-case slug, using the [publication format](./templates/publication.md).
Rewrite the current premise in place; do not append chronology, create dated
versions, or preserve obsolete meaning beside the current one.

Keep the file about this medium:

- Reference `PRODUCT.md` for product facts instead of copying them.
- Put the medium's accepted sample and confirmed voice in its Voice section.
  Voice explicitly shared across the author's publications belongs in the
  existing style subject under `docs/decisions/`; link to it instead of copying
  the rule or sample. Use `project-knowledge` when available, or update that
  subject directly with the rule, reason, scope, representative example, and
  confirmation evidence. When no subject exists, create one and link it once
  from `docs/decisions/README.md`. A pointer to an unwritten record is not
  preservation. Durable writes stay within these premise and style owners.
- Leave individual pieces, their theses, outlines, and briefs to the per-piece
  workflow.

Do not brief or draft a piece as part of this skill.

## Finish

Finish when the user has confirmed the complete premise and a later agent can
read the file and brief a piece for this publication without mistaking a guess
for intent. Report the file written, the material meaning established or
changed, choices made under delegation, and accepted assumptions or intentional
unknowns.
