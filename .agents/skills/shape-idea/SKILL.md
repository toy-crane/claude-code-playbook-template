---
name: shape-idea
description: Turn a chosen problem and broad direction into shared decisions and an implementation-ready spec. Use when the user wants to clarify behavior or scope, stress-test an idea, align before implementation, or produce a spec.
---

# Shape Idea

## Stay in shaping

Limit durable project writes to the spec folder, glossary, current decision
contracts, and installed vendor agent context. Leave product code unchanged.
Keep technical experiments, benchmarks, variants, comparison renders, and
component previews temporary. Preserve `prototype.html` only when it covers the
whole surface and the user explicitly approves it as the prototype.

## Establish project truth

Before the first question, invoke `project-knowledge` and apply it throughout the
session. If it is unavailable, read `GLOSSARY.md` and relevant subjects from
`docs/decisions/README.md` when present, update confirmed terms, and surface
terminology or decision conflicts for explicit clarification.

Use available evidence to resolve what you can before asking the user.

For an external-dependency question, check official documentation, issues, and
release notes before a workaround. If they do not answer it, run a small
technical experiment or benchmark and record the gaps. When a decision selects
a framework or hosted service, install any official vendor agent context in the
form the vendor recommends.

## Shape decisions

Present a concrete candidate for the user to correct. Keep decisions in prose
except where a form below resolves them better.

- Decide an inexpensive, reversible choice when a mismatch is unlikely or easy
  to detect; state it as an overridable assumption, never a project decision
  contract.
- For a branch expensive to get wrong, ask exactly one question per turn for one
  fact, value, or choice. Include a recommended answer and concise reason, then
  wait.
- If a proposed decision depends on information only the user can know, state
  that information and ask whether it applies. Verify any condition you can
  check yourself.
- For a choice judged by looking or trying, inspect the current surface first.
  Use a runnable candidate when it contains the change; otherwise use the
  lowest-effort sufficient renderer. Present two or three variants differing
  only on one unresolved choice, verify only the states needed for comparison,
  and wait for the user's reaction. Invoke `build-prototype` for a whole-surface
  question; if unavailable, defer it rather than treating a partial render as
  approval. If no visual medium makes the choice judgeable, defer it and record
  the uncertainty as a remaining risk.
- When a flow, state model, or relationship has multiple branches, transitions,
  or links, render one diagram before a downstream decision. Ask at most one
  question about its unresolved part and wait. Keep a linear structure that fits
  in one sentence in prose.

A choice is settled when the user confirms it or it is made under authority the
user explicitly delegated for that class of decision. It becomes a project
decision contract only when future work should reuse it, its rationale prevents
reasonable re-litigation, and it came from a real trade-off; feature-local
choices stay in the spec.

When the user asks for an explanation rather than a decision, invoke
`explain-visually`. If unavailable, use one sentence when sufficient or the best
available renderer otherwise.

Skip review only for an already confirmed pattern, routine presentation details,
or explicit user delegation. Record the reason and treat only agent-judged
reasons as assumptions.

## Close autonomously

Stop asking questions when every implementation-relevant decision is resolved
or explicitly deferred; do not wait for the user to declare completion.
Translate confirmed product-change requests into required behavior and record
unresolved requests as deferred points with their possible impact as remaining
risks.

Summarize confirmed decisions, rationale, assumptions, off-limits areas and why,
deferred points, and remaining risks. When ready for implementation, write that
content to `docs/specs/<slug>/spec.md`, creating the kebab-case folder when
needed. Record decisions, not implementation instructions. Do not prompt for
another action after the summary and risks.
