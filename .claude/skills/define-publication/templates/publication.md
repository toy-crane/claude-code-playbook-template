# Publication Format

Write one current premise per medium at `docs/publications/<slug>.md`. Replace
the title with the publication's name when it has one; otherwise name the
medium, such as `# Product blog`.

```md
# {Publication name}

## Definition

{One sentence stating what this publication is, for whom, and the change it
promises.}

## Readers and situations

{Primary readers and the concrete situations in which they read a piece.}

## Promised change

{What should become different for a reader after reading.}

## Voice

{Confirmed voice characteristics and where they apply. Retain the accepted
sample paragraph with the user's confirming choice, when one was accepted.
Keep proposals out of the current premise. Point to the owning style subject
in `docs/decisions/` instead of repeating a shared rule or example.}

## Coverage

- {What this publication covers.}
- {What it leaves out, and why.}

## Conventions

- Form: {the shape of a typical piece and its usual length}
- Location: {where finished pieces live in the repository; `<slug>` is the
  piece's brief folder slug, such as `content/posts/<slug>.md`}
- Preview: {how the rendered piece is viewed locally}

## Evidence of a finished piece

- {A reader with no other context can answer the piece's reader questions
  from the piece alone.}
- {For pieces carrying code: every embedded code block and command runs as
  written and produces the stated result.}
- {Any medium-specific check.}

## Success signals

- {Observable evidence that the promised change is happening.}

## Assumptions and unknowns

- Assumption: {Important belief not yet supported as fact.}
- Unknown: {Question that matters later but need not block the current premise.}
```

Use compact prose and concrete statements. Remove placeholder lines and record
`None identified.` only when a required section genuinely has no current item.
Reference `PRODUCT.md` for product facts rather than copying them. Do not add
status fields, update dates, history, a content calendar, or piece-level
detail.
