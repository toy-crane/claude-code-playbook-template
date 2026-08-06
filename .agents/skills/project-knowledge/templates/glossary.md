# Glossary Format

`GLOSSARY.md` lives at the repo root and holds the project's canonical vocabulary.

## Structure

```md
# Glossary

{One or two sentence description of the domain this project covers.}

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Choose one term.** When several words name the same concept, select one and
  list the others under `_Avoid_`.
- **Keep definitions short.** Use at most two sentences and define the term, not
  its implementation.
- **Include project-specific terms only.** Exclude general programming concepts
  such as timeouts, error types, and utility patterns.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.
