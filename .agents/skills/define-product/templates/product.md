# Product Context Format

Write one current product definition at repository root as `PRODUCT.md`. Replace
the title with the product name when it is known; otherwise use `# Product`.

```md
# {Product name}

## Definition

{One sentence stating what the app is, for whom, and the change it enables.}

## Users and situations

{Primary users and the concrete situations in which they reach for the app.}

## Problem and current alternatives

{The recurring problem and what users do instead today.}

## Promised change

{What should become meaningfully different for the user.}

## Core loop

{The recurring sequence through which the user receives that value.}

## Capabilities and boundaries

- {Stable app-wide capability or product boundary.}

## Experience principles

- {Quality the experience should protect.}

## Success signals

- {Observable evidence that the promised change is happening.}

## Assumptions and unknowns

- Assumption: {Important belief not yet supported as fact.}
- Unknown: {Question that matters later but need not block the current premise.}
```

Use compact prose and concrete statements. Remove placeholder lines and record
`None identified.` only when a required section genuinely has no current item.
Do not add status fields, update dates, history, a roadmap, or implementation
detail.
