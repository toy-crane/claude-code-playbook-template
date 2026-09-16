---
name: define-piece
description: Turn one topic and a rough direction into a confirmed brief for a single piece of writing, such as a blog post, newsletter issue, or page of copy, at docs/briefs/<slug>/brief.md. Use when the user wants to settle a piece's thesis, reader, scope, outline, or reader questions before any prose is written, or asks for a brief. Do not use to write the body, to define the publication itself, or to shape a code work unit, which belongs to shape-idea.
---

# Define Piece

Settle what one piece must do before any of it is written, by putting concrete
candidates in front of the user to correct, then record the confirmed brief
that drafting will follow.

## Ground the brief in project truth

Read `docs/publications/` first. When exactly one publication file exists, it
governs this piece. When several exist, recommend one from the topic with a
one-line reason and confirm before continuing. When none exists, say so and
proceed with the piece-level decisions, recording the missing premise as a
remaining risk; do not create the publication file here.

Read `GLOSSARY.md` and the relevant subjects from `docs/decisions/README.md`
when present, and use the project's terms and settled style decisions. Read
root `PRODUCT.md` when the topic concerns the product, taking only the facts
this piece needs. Apply the relevant confirmed writing criteria and accepted
examples when proposing headings and prose variants; transfer their writing
qualities, not their subject matter. Resolve an ambiguous term with the user
and record it through `project-knowledge`, or directly in `GLOSSARY.md` when
that skill is unavailable.

Resolve what evidence can answer before asking the user. When the piece makes
a claim about how code, a tool, or a package behaves, read the source or run
it in this repository and use what was observed; a claim the piece will make
rests on evidence, not recollection.

## Present one decision at a time

Open with candidates, not questions: a one-sentence thesis, two or three title
candidates, and an outline of section headings with one line on what each
section does. Then wait. The user corrects what is wrong, and that correction
is the unit of progress; a first turn that also writes the brief has skipped
the correction the brief exists to capture.

- Decide an inexpensive, reversible choice yourself when a mismatch is unlikely
  or easy to detect, and state it as an overridable assumption.
- For a branch expensive to get wrong, such as who the reader is or what the
  piece leaves out, ask exactly one question about one choice. Include a
  recommended answer and a concise reason, then wait.
- For a choice judged by reading, such as tone, opening, or how much the piece
  assumes, show two or three short text variants inline that differ only on
  that choice, name the governing difference, and wait for the user's
  reaction. Keep each variant short enough to compare at a glance.
- When a proposed decision depends on something only the user can know, such
  as what their readers already tried, state it and ask whether it applies.

Push the reader questions toward checkable answers. A question a vague draft
could satisfy, such as "why does this matter?", is reworked until a reader's
answer could be judged right or wrong from the piece.

A choice is settled when the user confirms it or it is made under authority
the user explicitly delegated for that class of decision. Stop asking when
every brief-relevant decision is settled or explicitly deferred; do not wait
for the user to declare completion. An initial request counts as confirmation
only when it explicitly asks for the brief and states the thesis, reader,
reader questions, scope, and outline, so that nothing material is guessed.

On a user correction or accepted variant, apply the bundled
[feedback capture guidance](./references/feedback.md) during that turn.

## Keep the brief free of prose

The brief records what the piece must do. The outline carries section headings
and what each section does, never paragraphs of the piece. Preserve an accepted
reusable example in its owning writing context and reference it from the brief
when relevant. Record piece-only choices or exceptions in one line; the unused
comparison variants need no permanent record.

Durable writes are limited to the brief folder, `GLOSSARY.md`, and current
decision contracts, plus maintenance of an accepted example in its existing
publication context as described in the feedback guidance. Changes to the
standing publication voice belong to `define-publication`. Leave product code
and the publication's content location unchanged.

## Write the brief

After the thesis, reader, reader questions, scope, and outline are settled,
write `docs/briefs/<slug>/brief.md` using the
[brief format](./templates/brief.md). Choose the kebab-case slug from the
working title and state it as an overridable assumption; it becomes the
piece's own slug wherever the publication's content location uses one, so the
brief folder and the piece file stay paired. Record:

- the owning publication;
- the thesis in one sentence;
- the reader of this piece and what they know before reading;
- three to five reader questions the target reader must be able to answer
  from the piece alone;
- scope, what is left out, and why;
- the real material the piece draws on: code, numbers, experience;
- the outline as section headings with what each section does;
- for pieces with code, which code blocks and commands are execution-checked;
- assumptions, deferred points, and remaining risks.

Summarize the same brief in the conversation and finish there.
