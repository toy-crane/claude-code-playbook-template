# Brief Format

Write one brief per piece at `docs/briefs/<slug>/brief.md`. The folder slug
is also the piece's slug in the publication's content location. The brief
records what the piece must do; the outline names sections and their jobs,
never paragraphs of the piece.

```md
# {Working title}

## Publication

{`docs/publications/<slug>.md` this piece belongs to.}

## Thesis

{One sentence the whole piece exists to establish.}

## Reader

{Who reads this piece and what they already know or have tried before
reading.}

## Reader questions

- {A question the reader must be able to answer from the piece alone, with an
  answer that can be judged right or wrong.}

## Scope

- Covers: {what the piece takes on}
- Leaves out: {what it does not, and why}

## Material

- {Code, numbers, or experience the piece draws on, and where it lives.}

## Outline

1. {Section heading} — {what this section does for the reader}

## Execution-checked code

{Which code blocks and commands must run as written, or `None.` for a piece
without code.}

## Assumptions

- {Overridable choice made without asking.}

## Deferred points

- {Decision postponed, and what it affects.}

## Remaining risks

- {What could still make the piece miss its thesis or reader.}
```

Three to five reader questions. Remove placeholder lines and record `None.`
only when a section genuinely has no current item. Do not add status fields,
dates, history, or body prose.
