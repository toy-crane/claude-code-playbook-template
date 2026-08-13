---
name: project-knowledge
description: "Maintain a project's canonical terms and settled decisions that future work should reuse, and record follow-ups a session discovers but does not resolve. Use when project-specific terms are being clarified, when a choice that may constrain future work is being considered or settles, including during planning, or when a session applies a temporary workaround whose root cause stays open or observes an out-of-scope defect with evidence. Do not use for simple definitions, routine implementation details, or carrying out an already-settled decision."
---

# Project Knowledge

Resolve unclear project terms and preserve settled decisions so future work uses
the same language and does not re-litigate the same trade-offs.

## Resolve terms

Read `GLOSSARY.md` when it exists.

- Resolve vague, overloaded, or conflicting project terms with the user.
- Stress-test unclear relationships between domain concepts with concrete
  edge-case scenarios.
- When a term is resolved, create `GLOSSARY.md` if needed and update it
  immediately using the [glossary template](./templates/glossary.md).
- Keep only project terms and their current definitions in `GLOSSARY.md`.

## Preserve decisions

When `docs/decisions/README.md` exists, read it and load only the subject files
relevant to the current work.

Record a project decision only when it is all of the following:

1. **Settled**: the choice is no longer a proposal. The user confirmed the
   outcome, or it was chosen under authority the user explicitly delegated for
   this class of decision.
2. **Reusable**: future work is likely to face the same question and should
   reuse this answer unless its reconsideration conditions are met.
3. **Non-obvious**: without its rationale, future work could reasonably reopen
   the question or choose differently.
4. **A real trade-off**: plausible alternatives existed, and preserving why
   they were rejected prevents the same evaluation from recurring.

Require evidence that a choice was intentional before treating it as settled.
Implementation or lack of objection alone is insufficient.

For each qualifying decision, use the
[decision contract template](./templates/decision-contract.md) to create or
update its single subject file in `docs/decisions/`. Preserve only the context
future work needs to apply the decision without repeating the original analysis.

## Record follow-ups

Record a follow-up when a workaround applied in this session is temporary and
its root cause stays open, or when an out-of-scope defect or suspected cause is
observed with evidence. Work that closed inside the session, a guess without
evidence, and a defect already fixed in the current change do not qualify.

Write each qualifying item at the moment of discovery to its own
`docs/follow-ups/<slug>.md` using the
[follow-up template](./templates/follow-up.md), naming the slug for the symptom.
An item must let a later session act without this conversation. Reporting the
discovery in conversation does not preserve it.

A follow-up records an open question, not a settled decision, so it does not
enter `GLOSSARY.md` or a decision contract until its outcome settles on its own
terms. Delete the file when the work ships or the item is promoted into a spec
folder.

## Protect project truth

- If code conflicts with the user's statement, `GLOSSARY.md`, or a relevant
  decision contract, surface the mismatch instead of choosing silently. Code
  shows current behavior, but not whether that behavior was intentional.
- A request to align documentation with code does not by itself confirm the
  decision the code implies.
- If relevant sources disagree about a settled decision, leave project
  knowledge unchanged until the intent is explicitly clarified.
- Treat a term or decision as preserved only after its target file is updated.
