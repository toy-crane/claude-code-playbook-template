# Decision Contract Format

Decision contracts live in `docs/decisions/`, one mutable file per subject. The
filename is the subject in kebab-case, such as `data-ownership.md`. Only settled
decisions that future work should reuse belong here; Git retains prior versions.

Create `docs/decisions/` lazily with a `README.md` index when the first contract
is needed.

## Template

```md
# {Subject}

## Decisions

- {Current settled rule.}

## Boundaries

- {Where the rule applies, its exceptions, or what it does not authorize.}

## Why

{The minimum rationale needed to apply or revisit the decision.}

## Reconsider when

- {An observable condition that should reopen the choice.}

## Still-rejected alternatives

- {Alternative} — {failure or rejection mechanism}; {condition for revisiting}.

## Evidence worth preserving

- {A result that would be expensive to reproduce.}
```

`Decisions` and `Why` are required. Include the other sections only when they
carry real content. Never add empty headings, status fields, supersession chains,
chronology, or pull-request history.

## Index entry

Add the subject once to `docs/decisions/README.md`:

```md
- [data-ownership](data-ownership.md) — Read when changing module ownership or cross-module data access.
```

The index says when to read the contract, not what it decides.
