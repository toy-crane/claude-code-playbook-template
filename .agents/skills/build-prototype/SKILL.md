---
name: build-prototype
description: Build a self-contained dummy-data HTML prototype covering every screen and relevant state of a web, mobile-web, or native-app surface. Use when the user wants to review and settle a complete screen-based product or feature before implementation, especially when prose or isolated variants cannot resolve cross-screen structure. Do not use for production implementation or CLI, terminal, or voice interfaces.
---

# Build Prototype

Build a disposable but finished-looking model of the whole surface so the user
can settle structure, relationships, and behavior before implementation.

## Set the effort

Accept `effort=standard` or `effort=high`. Recommend and use `standard` when the
argument is omitted.

Pass one base completion gate at either effort: produce a finished-looking
surface, cover every requested screen and relevant state, make intended
interactions and reset paths work, exercise every relevant viewport in a
browser, correct every reproduced defect found during that inspection, and
share an address the user can open. Hold this gate fixed at `standard`.

- `standard` uses the base gate as its complete result.
- `high` passes the same base gate, then adds close visual matching to an
  inspectable current product or reference. Broaden the search for mismatches,
  independently reproduce each material candidate, correct verified mismatches,
  and recheck affected screens until none remain. When the host supports
  subagents, delegate the audit to one fresh reviewer subagent at high model
  effort and give it the reference and candidate artifact without the builder's
  findings. Otherwise separate the build and verification passes and report
  that reviewer independence or model effort was unavailable. If no reference
  can be inspected, report that visual equivalence is unverified and use the
  extra pass only to strengthen layout robustness.

The selected effort changes additional reference verification, not prototype
completeness, interaction correctness, browser coverage, or visual finish.

## Ground the prototype

Use the request and conversation as scope. When present, read `GLOSSARY.md`,
relevant subjects from `docs/decisions/README.md`, and a work-unit spec only
when the request or a prior handoff identifies one. Do not search for a spec.

Inspect the existing product and design system as evidence. Use their canonical
terms, interface language, tokens, and components; otherwise use the user's
language and the template's finished minimal style. Include the baseline in the
review only when the user is choosing between it and the candidate. Surface
conflicts instead of resolving them silently.

Hold confirmed relationships fixed. Keep overlays, drawers, and modals attached
to their source screen unless the user is reconsidering that relationship.

## Build one canonical product surface

Present the screen inventory as a correctable draft and begin building without
waiting for approval.

Copy [templates/shell.html](./templates/shell.html) into one temporary,
self-contained HTML file and grow every product screen inside it. Preserve and
follow the template's contract comment; it owns the review chrome, product-pixel
boundary, screen and state semantics, and viewport behavior. Keep one canonical
version of each product screen in this file.

Keep one-click and transient changes as working product interactions, however
different they look. Reserve selector presets for important multi-step results,
forced data or errors, and structures that are not trivial to reach. Synchronize
the selector when interactions enter or leave a declared preset.

Copy project tokens verbatim into `:root`, or extract the existing design
language when no token file exists. Style every screen through those tokens and
mark elements with the design system's component names in `data-component`;
use `new:Name` only when no component exists.

Use realistic dummy content with real-length names, plausible copy, awkward
numbers, and only relevant edge conditions. Never use lorem ipsum. Keep out real
data, APIs, latency, production routing or state wiring, frameworks, build
steps, and network dependencies.

Use a phone frame for native app mockups and start mobile-first prototypes in
the template's narrow viewport; its classes own simulated responsive behavior.

## Review and converge

Render and inspect the artifact before presenting it. Exercise every screen,
declared state, interaction entry and reset path, and relevant viewport in a
browser. Run the finished HTML using a method supported by the current harness
and share an address the user can open. Explain differences, rationale, and
review guidance in the conversation, outside the product pixels. Present the
artifact and correctable screen draft, walk through the surface screen by
screen, and ask what to change. Do not close an open review with a completion
handoff.

For `high`, audit through two independent lenses. Compare the reference and
prototype at matching screen, state, and viewport coordinates for typography,
spacing, alignment, wrapping, overflow, and asset treatment. Separately stress
layout and interaction recovery with realistic long or awkward content. Give
each material mismatch candidate its exact coordinate, observed evidence, and
reproduction path. Have the fresh reviewer subagent reproduce candidates when
one is available, discard those that do not reproduce, and correct the verified
set.
After a correction, re-render its coordinate and the other screens or states
that share the changed token, component, or shell behavior. Report the audited
coverage and any unverified coordinates or fidelity claims in the conversation.

For an unresolved detail, render two or three variants that differ only on that
question. Hold content, data, surrounding layout, behavior, and every confirmed
element fixed. Keep these disposable comparisons outside the product screen and
state selectors. Let the user choose, fold the winner into the canonical file,
and discard the other variants.

## Preserve the approved result

Keep the working file temporary and write nothing under `docs/specs/` while
review remains open. Once every screen is approved or explicitly deferred,
reuse an identified work-unit folder or derive a kebab-case slug. Record only
confirmed decisions, assumptions, deferrals, and risks in
`docs/specs/<slug>/spec.md`; save and link the approved surface as
`docs/specs/<slug>/prototype.html`. Never infer navigation, order, or behavior
from source order or visual proximity.

Promote only user-confirmed, reusable, non-obvious trade-offs from the spec into
a project decision contract.

Discard intermediates; the approved prototype is a reference, not production
code.
