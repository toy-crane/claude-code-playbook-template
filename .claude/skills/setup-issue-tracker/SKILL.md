---
name: setup-issue-tracker
description: Record once per repository which issue tracker coordinates spec folders and, when requested, scheduled triage of human-written issues. Run by hand before parallel implementation or issue triage; rerun to change trackers or upgrade an older convention.
disable-model-invocation: true
---

# Set up the issue tracker

Give this repository one issue tracker convention that the other skills read
through a short route in its agent instructions. The spec folder under
`docs/specs/<slug>/` stays the implementation contract, and its `spec.md`
names its one issue with an `Issue: <tracker>:<id>` line. When work starts from
an existing issue, that issue is the one named; otherwise the PR that first
carries the folder creates the issue and commits the line. Every lookup uses
that recorded ID, never a title search. Repositories without this section keep
every skill's current behavior: no issue is created and no `Issue:` line is
written. Write it when the user wants parallel implementation or scheduled
general-issue triage.

## Explore, then recommend

Read what is already there before asking anything: the Git remotes, whether
`AGENTS.md` and `CLAUDE.md` exist and whether either already carries an issue
tracker section, and which tracker tools this session can actually use (a
GitHub CLI login, a Linear MCP server or CLI, or nothing). Lead with a
recommendation the user can accept in a word: the remote's host when the
repository lives on GitHub, an existing section's tracker when one exists, and
otherwise the tool the session can reach. Confirm one item at a time.

Settle these items:

- **Tracker**: GitHub Issues, Linear, or another tracker the user describes in
  one paragraph.
- **Issue ID form**: the `<tracker>:<id>` value an `Issue:` line carries in
  `spec.md` and in a PR body, such as `linear:FLY-145` or `github:#12`. The
  line is the only link between a spec folder and its issue; titles carry no
  key or prefix, and no label marks a spec issue.
- **Tool**: the command or server the skills use, verified to exist in this
  session rather than assumed.
- **Repository conventions**: how work in progress is recognized, when a user
  must explicitly request resumption, and how a PR links and closes its issue.
- **Seven operations**, documented for issue work, each addressing an issue by
  its recorded ID: find it (returning whether it is open, its assignee, its
  state, and its open blockers); create it with the spec title, a bounded spec
  section as its body, and the review signal, returning its ID; refresh only
  its bounded spec section while preserving its title and every other part of
  its body; replace its blockers by removing stale edges and adding missing
  ones; claim it; mark it ready for implementation after a spec-only PR merges
  by clearing the review or active signal and leaving it open in a non-active
  state that is not general triage; and close it. Record which states or
  labels are the review signal and which states count as active work. Record
  the exact markers that bound the spec section so every skill writes and
  finds the same one; the templates' default matches the markers the triage
  skill's body renderer writes, so a triaged issue never gets a second spec
  section.
- **General-issue triage, when requested**: record the open general-issue
  scope including Backlog; the not-yet-judged query that returns open general
  issues with no `Triage 요약` or spec section and none of the triage results;
  and the
  tracker states or labels representing `needs-triage`, `needs-info`, and
  `needs-decision`. Triage handles each issue once, so record no detection of
  human replies or body edits. Use native
  Triage where appropriate, and verify or create the selected labels. Record
  how to find linked PRs and active work, attach evidence, leave comments, set
  waiting states, dispose of proven duplicates, and update only bounded
  AI-managed body sections while preserving human text. Record whether
  conditional body updates are supported and how the latest body is re-read
  and verified afterward. Record the stale-review query, which returns open
  issues carrying the review signal with no open linked PR, and how such an
  issue whose spec PR closed unmerged returns to a non-active state such as
  Backlog; this clears a stale review signal and does not make the issue new. Do not add a decision-maker field or
  treat an assignee or label as an atomic lock.

Start from the matching template and adjust it to what exploration found:
[templates/github.md](templates/github.md),
[templates/linear.md](templates/linear.md), or
[templates/other.md](templates/other.md) for a tracker the user describes.

## Write the section

Record the convention as an `## Issue tracker` section in the repository's
agent instructions. Edit `AGENTS.md` when it exists, `CLAUDE.md` when only that
exists, and `AGENTS.md` when both exist as separate files; when neither exists,
ask which one to create. Never create the second file beside an existing one.
When the section already exists, replace it in place and leave the surrounding
content untouched; rerunning this skill shows the current convention and
changes only what the user wants changed. Treat an older section that maps
folders through a `spec:<slug>` title key, a `Source-Issue` line, or a managed
issue listing as outdated: propose replacing them with the `Issue:` line and
ID-based operations while preserving its tracker, tool, states, and
already-compatible operations. Also replace an additive-only blocker update
with the complete stale-removal and missing-addition operation. Treat triage
items that re-select waiting issues on a human reply or body edit as outdated
too, and replace them with the not-yet-judged query. The old names
are not read for compatibility, so tell the user to rename `Source-Issue:` to
`Issue:` in active spec folders themselves; leave existing title-key issues
for the user to tidy in the tracker.

Keep the always-loaded section focused on purpose: where spec state lives,
require an explicit user request before resuming an issue already in progress,
and link issues through PRs and close them when implementation merges. A spec
PR never closes its issue. Add a task-time link to `docs/issue-tracker.md`;
write the repository's issue ID form, verified tool, state and claim
conventions, closing reference, seven spec operations, and any triage
operations there. Load that file only for issue work. Preserve
repository-specific choices and non-obvious
behavior; use the current tool schema or CLI help for exact arguments instead
of copying exhaustive field lists into either document. General tool guidance
belongs in this skill's references, not in always-loaded instructions.

On rerun, move existing operational detail into that document without losing
custom team settings, states, claim protection, or closing behavior. Reconcile an
existing detail document instead of creating a competing source. Preserve the
surrounding agent instructions and unrelated document content. Consumers must
be able to use the repository documents without this skill being installed.

Show the drafted section and detailed convention before writing them, then
write both and report their paths. Do not create issues for existing spec
folders here: the next PR that carries a folder without an `Issue:` line
creates its issue and records the line.
