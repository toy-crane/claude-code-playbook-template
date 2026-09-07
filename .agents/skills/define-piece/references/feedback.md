# Preserve confirmed writing feedback

During a correction or sample selection, distinguish a reusable choice the user
has settled from a change to this piece alone. An explicit rule with a clear
scope needs no extra request to remember it or repeat approval. A local rewrite,
repetition, or silence does not establish a broader preference. When reuse or
scope is uncertain, ask one focused question and keep the candidate in the
conversation, separate from current rules.

Preserve a confirmed reusable choice before handing back that correction:

- Read the existing owner and strengthen the matching rule rather than adding a
  duplicate. Keep its rule, reason, scope, a useful before/after example, and
  the user's instruction or selection that confirmed it. If the reason was not
  supplied, say so instead of inventing the user's rationale. Keep examples
  representative rather than collecting every edit.
- Reusable style and structure belong in the relevant subject under
  `docs/decisions/`, with one link from `docs/decisions/README.md`. Use
  `project-knowledge` when available; otherwise write the subject and index
  directly. Create a subject only when none owns the choice. Use shared
  repository files so either Claude or Codex can read the current criteria.
- The publication owns its baseline voice; a deliberate change to that voice
  belongs to `define-publication`. A piece's thesis and scope belong to its
  brief and `define-piece`; terms belong to `GLOSSARY.md`. Keep these meanings
  with their owners instead of recasting them as style preferences.

When later feedback replaces or rejects an accepted example, update its status
at the existing owner, including a publication's Voice section. This maintenance
preserves the confirmed rule; it does not authorize changing the standing voice.
Retain a rejected example only when it helps explain the contrast, clearly
marked as rejected. Link to shared criteria instead of copying them into a brief
or publication. Git holds the history; no extra correction log is needed.

A clear one-piece exception applies only to that piece and leaves the default
rule and its accepted examples intact. Keep the exception with the piece's
existing context: in the brief while briefing, or with the scoped edit and its
handoff while drafting. An explicit replacement of a standing rule updates that
rule through its existing owner, rather than leaving contradictory defaults.

Apply the correction without changing its underlying thesis, actors, or causal
claims. If the user identifies a role, repetition, or connection problem, check
related headings, body text, and diagrams for that same cause. Report the actual
record changed briefly; a promise to remember is not a saved criterion.
