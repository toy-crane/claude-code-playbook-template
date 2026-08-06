---
name: build-prototype
description: Build a self-contained dummy-data HTML prototype covering every screen and relevant state of a web, mobile-web, or native-app surface. Use when the user wants to review and settle a complete screen-based product or feature before implementation, especially when prose or isolated variants cannot resolve cross-screen structure. Do not use for production implementation or CLI, terminal, or voice interfaces.
---

# Build Prototype

Build a disposable but finished-looking model of the whole surface so the user
can settle structure, relationships, and behavior before implementation.

## Ground the prototype

Use the request and conversation as the primary scope. When present, read
`GLOSSARY.md`, only relevant entries from `docs/decisions/README.md`, and any
work-unit spec identified by the request or a prior handoff. Do not require or
search for a spec before building.

Inspect the existing product and design system. Use their canonical terms,
interface language, tokens, and components; otherwise use the user's language
and the template's finished minimal style. Surface conflicts instead of
resolving them silently.

Hold confirmed relationships fixed. Keep overlays, drawers, and modals attached
to their source screen unless the user is reconsidering that relationship.

## Build the artifact

Present the screen inventory as a correctable draft and begin building without
waiting for approval.

Copy [templates/shell.html](./templates/shell.html) into one temporary,
self-contained HTML file and grow every screen inside it. Preserve the
template's contract comment and its three-control review shell. List screen
names without an index or total; source order is neither product flow nor review
progress.

Treat states as representative review presets, not an inventory of every UI
change. Keep the automatic `Default`; add a naturally named state only for an
important multi-step result, forced data or error condition, or materially
different structure. Keep one-click results, menus, filters, expanded details,
hover, focus, typing, and combinations as real interactions, however different
they look. Synchronize the selector whenever an interaction enters or leaves a
declared state, including when repeated actions cross that state's condition.

Copy project tokens verbatim into `:root`, or extract the existing design
language when no token file exists. Style every screen through those tokens and
mark elements with the design system's component names in `data-component`;
use `new:Name` only when no component exists.

Use realistic dummy content with real-length names, plausible copy, awkward
numbers, and only relevant edge conditions. Never use lorem ipsum. Keep out real
data, APIs, latency, production routing or state wiring, frameworks, build
steps, and network dependencies.

Use a phone frame for native app mockups and start mobile-first prototypes in
the shell's narrow viewport. Drive viewport-dependent styles from the shell's
`.sh-vp-390` and `.sh-vp-768` classes, not browser media queries alone; the
shell simulates those widths inside a wider browser window.

## Review and converge

Render and inspect the artifact before presenting it. Exercise every screen,
declared state, interaction entry and reset path, and relevant viewport in a
browser. Present the artifact and correctable screen draft, walk the user through
the surface screen by screen, and ask what to change. Do not close an open review
with a completion handoff.

For an unresolved detail, render two or three variants that differ only on that
question. Hold content, data, surrounding layout, behavior, and every confirmed
element fixed. Let the user choose, then fold the choice into the single file.

Use the rendering medium's element selection or prose to identify problems. Do
not add pointing, annotation, approval, or change-tracking controls to the
prototype.

## Preserve the approved result

Keep the working file temporary and write nothing under `docs/specs/` while
review remains open. Once every screen is approved or explicitly deferred,
reuse an identified work-unit folder or derive a kebab-case slug. Record only
confirmed decisions, assumptions, deferrals, and risks in
`docs/specs/<slug>/spec.md`; save and link the approved surface as
`docs/specs/<slug>/prototype.html`. Never infer navigation, order, or behavior
from source order or visual proximity.

Update a project decision contract only when the user explicitly confirmed a
choice that future work should reuse, whose rationale prevents reasonable
re-litigation, and that came from a real trade-off.

Discard intermediate work. Keep the approved prototype as a reference, never as
production code.
