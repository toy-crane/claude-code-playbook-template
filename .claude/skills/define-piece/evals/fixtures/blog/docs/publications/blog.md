# Product blog

## Definition

A short-form engineering blog for developers who install this project's
tooling, promising that each piece leaves them able to do one concrete thing
they could not do before.

## Readers and situations

Developers evaluating or already using the project's CLI, reading between
tasks with a terminal open.

## Promised change

After a piece, the reader can run one thing they could not run before and
knows why it works.

## Voice

Plain, first person plural, present tense. No hype, no rhetorical questions.

## Coverage

- Covers: the project's tooling, its decisions, and worked examples.
- Leaves out: company news and product marketing.

## Conventions

- Form: 400–900 words, one H1 title, H2 sections, at most one code block per
  section.
- Location: `content/posts/<slug>.md` with `title` and `date` front matter.
- Preview: `scripts/preview.sh` renders `content/posts/` to `dist/` and
  prints the file path of each rendered piece.

## Evidence of a finished piece

- A reader with no other context can answer the piece's reader questions from
  the piece alone.
- Every embedded command runs as written from the repository root and produces
  the stated output.

## Success signals

- Readers reproduce the worked example without asking for help.

## Assumptions and unknowns

- Assumption: readers have a POSIX shell.
