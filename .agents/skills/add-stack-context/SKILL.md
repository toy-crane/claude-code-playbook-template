---
name: add-stack-context
description: Audit and install official agent context for the technologies that define a project's stack. Use when setting up a project for agent work, after selecting or adding a framework, library, developer tool, or hosted service, or when entering an existing project whose official agent context has not been audited.
---

# Add Stack Context

## Inventory the stack

Build a checklist of the direct technologies that shape how the project is
built or operated from manifests and configuration files. Include frameworks,
libraries, developer tools, and hosted services; exclude transitive
dependencies. Use lockfiles to confirm installed versions, not to expand the
checklist. If the project does not declare a stack yet, ask the user what they
intend to use.

## Resolve each technology

For every checklist item, search the vendor's current documentation and
official organization for official agent context. Match the installed version
when the vendor provides version-specific context.

Inspect the documented installation method and expected changes, then install
missing context in the form the vendor recommends. Accept only sources
controlled by the vendor. When none exists, record the gap instead of
substituting community-made context.

Preserve user-authored context. Treat vendor-managed blocks as vendor-owned:
update them only through the official method. Make only the changes required by
that method.

## Account for every technology

Finish only when every checklist item has one of four outcomes:

- installed;
- already present;
- unavailable from an official source; or
- blocked, with the reason stated.

Summarize the outcome and official sources checked for every item. For installed
context, include the changes made and the vendor's documented update path.
