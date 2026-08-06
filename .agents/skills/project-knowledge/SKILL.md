---
name: project-knowledge
description: "Maintain a project's canonical terms and settled decisions that future work should reuse. Use when project-specific terms are being clarified or when a choice that may constrain future work is being considered or settles, including during planning. Do not use for simple definitions, routine implementation details, or carrying out an already-settled decision."
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

## Protect project truth

- If code conflicts with the user's statement, `GLOSSARY.md`, or a relevant
  decision contract, surface the mismatch instead of choosing silently. Code
  shows current behavior, but not whether that behavior was intentional.
- A request to align documentation with code does not by itself confirm the
  decision the code implies.
- If relevant sources disagree about a settled decision, leave project
  knowledge unchanged until the intent is explicitly clarified.
- Treat a term or decision as preserved only after its target file is updated.
