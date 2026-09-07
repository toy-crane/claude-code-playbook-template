---
name: draft-piece
description: Draft or resume a piece from a selected docs/briefs/SLUG/ folder, or apply user corrections to an existing article. Verify reader understanding, embedded code, and confirmed writing criteria; preserve reusable feedback and preview locally when supported. Do not use to change the brief, define a publication, or commit or publish the piece.
---

# Draft Piece

## Load the current handoff

Treat `brief.md` as the confirmed contract for the piece. Read the publication
file it names under `docs/publications/`, `GLOSSARY.md`, and the relevant
subjects from `docs/decisions/README.md` when present. The publication file
supplies the form, the content location, the preview method, and any
medium-specific evidence; the brief supplies the thesis, reader, reader
questions, scope, material, outline, and execution-checked code.

Before starting, and again after an interruption, reconstruct current state
from the brief, the publication file, any existing draft at the content
location, Git state and the current diff, and verification evidence.
Repository evidence outranks remembered conversation; a draft on disk is
compared against the brief before continuing, not rewritten from memory.
Confirm ownership before absorbing ambiguous dirty changes.

For a correction to an existing article, locate its brief when available. When
none exists, use the article and the explicit correction as the bounded
contract, read the relevant publication and writing decisions, and preserve
unaffected content. Do not invent a missing brief or past intent. If publication
ownership is ambiguous and affects the edit, resolve it before applying a voice.

## Write against the brief

Write the piece section by section in the outline's order, at the location
the publication file names; fill any `<slug>` in that location with the brief
folder's slug so the brief and the piece stay paired. After each section,
check it against the brief: the thesis it serves, the reader question it
answers, the scope it stays inside, the material it draws on. Use the
project's terms from `GLOSSARY.md` and the confirmed voice and structure criteria
in the publication and style decisions. Apply their accepted examples as
references for writing qualities, without importing another piece's claims.

## Handle user corrections

Apply the bundled [feedback capture guidance](./references/feedback.md) during
each user correction, including after the initial handoff. It covers recording
confirmed criteria, maintaining examples, and preserving meaning across related
parts of the piece.

Continue to use the brief's authority boundary below. With no brief, a requested
change of meaning needs an explicit new claim from the user; an unclear one
returns a focused question while preserving the article.

## Preserve evidence and scope

Embedded code and commands are claims the reader will reproduce. Run each one
in this repository at the time it is written, and match any stated output to
the real output. When a marked block cannot run in the current environment,
record the exact failed gate and prerequisite in the handoff and keep the
piece incomplete; reading the code is not running it.

When a discovery would change the thesis, the reader, a reader question, the
scope, or what the piece leaves out, stop. Preserve the draft and the
evidence, state the exact decision, and return it to the user for the brief to
be resettled. Drafting authority covers wording, structure inside the outline,
and technical detail while the brief stays intact; it does not extend to
editing the brief.

Route a workaround whose root cause stays open, or an evidenced out-of-scope
defect found while running the piece's code, through `project-knowledge` at
discovery time. If that skill is unavailable, write the symptom, observed
evidence, suspected cause, what was tried, and proposed next step to
`docs/follow-ups/<slug>.md`.

## Verify in two layers

When the draft is complete, run both checks before revising anything:

1. **Reader questions, on every piece.** Hand the draft text and the brief's
   reader questions, and nothing else from this conversation or the brief, to
   a separate agent with no other context, and have it answer each question
   from the draft alone. A question it cannot answer, or answers wrongly,
   fails. Use whatever fresh-context agent the current harness offers.
2. **Execution, on pieces with code.** Every block and command the brief marks
   runs as written, in the repository, and produces the stated result. Rerun
   any block whose surrounding text changed since it last ran.

Add any medium-specific check the publication file names.

Separately compare the draft with the applicable confirmed voice and structure
criteria and accepted examples, respecting any explicit piece-only exception.
Locate concrete violations; a reader-question pass is not evidence of style
alignment. Treat a new taste suggestion as an unconfirmed remark.

For a bounded article correction without a brief, check preservation of meaning
and confirmed writing criteria, and run affected code. Do not manufacture reader
questions or claim the full brief-based check ran. Report that coverage limit.

## Revise once, then record

Use at most one automatic revision pass. Repair a failed reader question by
changing the part of the piece that should have answered it, and repair a factual error the
execution check exposed, along with violations of confirmed applicable writing
criteria. Keep repairs within the brief's meaning and outline. Rerun changed
code and check the affected criteria after the repair; record remaining failures
without starting another automatic revision cycle. Unconfirmed taste suggestions,
structure outside the outline, and out-of-scope ideas stay in the handoff.
This limit bounds autonomous revision, not later corrections the user requests.

## Hand off the draft

Report the piece's location, the result of each verification layer, what the
automatic revision changed, where confirmed feedback was preserved, and what
was recorded without action. Retirement of the brief folder happens when the
piece is published, not here.

When the repository serves the publication through a local server, run it
through the supported development or preview path, reuse a healthy server
owned by the current checkout or start an isolated one without disturbing
other checkouts, verify that the rendered piece loads with the current draft,
and share the address and what to look at. Keep the server running until the
user finishes reading or later delivery cleanup stops it. If the environment
cannot provide a reachable address, report the exact launch command and
blocker without claiming a working URL. When the repository has no such
server, hand off the file without inventing one.

Stop before committing, opening a pull request, or publishing. Those follow
the user's reading of the draft, through the repository's Git skills or the
user's own commands.
