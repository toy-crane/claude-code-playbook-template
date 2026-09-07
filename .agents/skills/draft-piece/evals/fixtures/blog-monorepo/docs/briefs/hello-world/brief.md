# Counting lines with the repo's tally script

## Publication

docs/publications/blog.md

## Thesis

`scripts/tally.sh` counts the lines of every Markdown file under a folder in
one command, so you can size a docs folder before reorganizing it.

## Reader

A developer who has cloned the repository and has not opened `scripts/`.

## Reader questions

- Which command counts the Markdown lines under `docs/`, and what does it
  print for this repository?
- What does the script do with a folder that contains no Markdown files?
- Why does the script print a total line even for a single file?

## Scope

- Covers: running the script, reading its output, the empty-folder case.
- Leaves out: extending the script to other file types; a later piece.

## Material

- `scripts/tally.sh` in this repository.
- `docs/` as the worked example folder.

## Outline

1. What tally does — the one-line problem it solves.
2. Running it on docs — the command and its exact output.
3. The empty folder — what happens and why the total line stays.

## Execution-checked code

- `scripts/tally.sh docs` and its printed output.
- `scripts/tally.sh content/empty` and its printed output.

## Assumptions

- The piece uses the repository's own `docs/` folder as the example.

## Deferred points

None.

## Remaining risks

- The line counts change whenever `docs/` changes; the piece states the
  counts as of writing.
