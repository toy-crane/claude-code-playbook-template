---
name: add-stack-context
description: Audit and establish current agent context for the technologies that define a project's stack. Use when setting up a project for agent work, after selecting or adding a framework, library, developer tool, or hosted service, or when entering an existing project whose agent context has not been audited.
---

# Add Stack Context

## Inventory the stack

Build a checklist of the direct technologies that shape how the project is
built or operated from manifests and configuration files. Include frameworks,
libraries, developer tools, and hosted services; exclude transitive
dependencies. Use lockfiles to confirm installed versions, not to expand the
checklist. If the project does not declare a stack yet, ask the user what they
intend to use.

## Discover skills and vendor context

For every checklist item, invoke `find-skills` when it is available and use it
to discover relevant skills. When it is absent, search the current Skills
ecosystem through the Skills CLI or an equivalent current source so this skill
remains independently installable.

Verify candidate ownership against the technology vendor's current
documentation or official organization; search rank, install count, and
repository popularity do not establish that relationship. Inspect the
documented installation method and expected changes, then install a
vendor-controlled skill when it is missing. Assess a relevant community skill
as an optional candidate, but install it only after explicit user approval and
never count it as the technology's official context.

Continue through the vendor's current sources for official context that skill
search does not cover, including installers, codemods, package-bundled
documentation, and MCP servers. Match the installed version when the vendor
provides version-specific context and apply the vendor's documented method.
When no official channel exists, record the gap without letting a community
candidate substitute for it.

## Keep changing guidance live

Treat a vendor `llms.txt` or equivalent changing document as a current remote
source, not a file to copy into the repository. Add or update a bounded managed
instruction in the repository's established `AGENTS.md` or `CLAUDE.md` surface.
Name the technology and official source, tell later agents to retrieve it when
relevant work begins, and require them to reconcile it with the installed
version.

Preserve user-authored context and existing links, imports, or other sharing
between agent instruction files. When both files are independent and active,
expose the same live retrieval behavior in each without replacing their other
content. Treat vendor-managed blocks as vendor-owned and update them only
through the official method.

## Account for every technology

Finish only when every checklist item has one of four outcomes:

- installed;
- already present;
- unavailable from an official source; or
- blocked, with the reason stated.

Summarize the outcome and official sources checked for every item. For installed
context, include the changes made and the vendor's documented update path. List
community candidates awaiting approval separately. For live vendor guidance,
name task-time retrieval as its update path and report a retrieval blocker
instead of treating a cached copy as current.
