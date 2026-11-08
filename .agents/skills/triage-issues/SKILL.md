---
name: triage-issues
description: Triage new human-written general issues from a configured issue tracker once, in a scheduled or manual run, or one named issue. Investigate, ask only decisions that need a person, and raise one implementation or spec pull request when ready.
---

# Triage general issues

This skill requires `pr`. Before doing any work, confirm it is installed.
When it is missing, stop and report it with its install command,
`npx skills@latest add toy-crane/skills --skill pr`, using the project's
package manager runner where it pins one.

Reduce the time a person spends deciding what to do with freely written issues.
Use the repository's `## Issue tracker` section in `AGENTS.md` or `CLAUDE.md`
and its linked `docs/issue-tracker.md`. Read both agent files and use the first
section found; existing inline conventions work too. The convention supplies
the tracker, project/team, status and label mapping, issue operations, and PR
links. Do not guess those values from this skill or require the setup skill to
be installed. If the convention or its tool is unavailable, report the exact
missing operation without changing issues or source.

## Select new issues

Triage handles each issue once, when it is new. When the request names an
issue, handle that issue alone. When it names none, take the convention's
not-yet-judged query across the configured scope, including Backlog, in stable
oldest-first order: open general issues with no `Triage 요약` or spec section
and none of the results a triage run leaves behind. Count at most three eligible issues
inspected in one run, and raise at most one PR. Continue to the next candidate
after leaving an information or decision request. Stop selecting PR-producing
work after the first PR.

Exclude issues with active work, the convention's review signal, or an open
linked PR, and issues named by an `Issue:` line in a spec folder on the default
branch; those wait for review or implementation. A PR links an issue when the
tracker links it or its body carries that issue's `Issue: <tracker>:<id>`
line. Do not filter by title. A review signal whose only linked PRs closed
unmerged is stale. Each run also takes the convention's stale-review query,
separately from new issues, to find open issues that still carry the review
signal with no open linked PR. For each, inspect the closed PRs' branches,
comments, and attempted changes, then return the issue to the convention's
non-active state, such as Backlog, when no active work remains. This cleanup
does not count toward the three issues. This clears the signal only; the issue keeps its
sections, so triage does not pick it up again. Reuse useful work rather than
creating a duplicate PR. A merged implementation PR follows the tracker close
or reconciliation path, not triage.

A waiting `needs-info` or `needs-decision` issue, or any issue an earlier run
already triaged, is not new. A named issue in that state has been triaged:
report its current state and stop, unless the person explicitly asks for it to
be triaged again. Comments are evidence for the judgment, never a reason to
pick an issue up again. Whoever runs the skills decides when a waiting issue
continues after a person answers: through `shape-idea` when it is installed,
or by naming the issue and asking this skill to triage it again, which then
reads the answer as evidence and reaches one of the outcomes below.

## Own an issue before any write

Use the bundled [claim helper](scripts/claim.sh) with the issue's stable
`<tracker>:<id>` in the convention's ID form, the same value an `Issue:` line
carries. It conditionally
creates a remote Git claim ref, so assignment or a working label is never the
lock. A competing run skips the issue. Keep the returned SHA and secret token
in disposable run state, never in an issue, commit, PR, or log. Verify the claim
before each issue write, branch publication, and PR creation; renew it during
long work and use the new SHA. If ownership is lost, stop writing and report
the partial state. Release only the revision still owned by this run.
At every terminal outcome after claiming—including a question, disposition,
published PR, changed-issue skip, or failure—verify and release the current
owned revision. Finish the issue outcome before releasing; do not wait for an
open PR to merge. If ownership was lost, do not release another run's claim.
If release fails, report the held ref and retry path rather than assuming the
issue is available. Two-hour recovery is for interrupted runs only.

An interrupted claim older than two hours can be recovered only after reading
the issue's newest activity, branches, and PRs for the earlier attempt. Reuse
an existing artifact rather than duplicating it, then pass the observed SHA to
`recover`. If a worker may still be active, leave the claim in place. The helper
uses the repository's `origin` remote by default; verify that the convention's
repository and the selected remote are the same before claiming. If remote
refs cannot be created or conditionally updated, skip writes and report the
missing atomic claim capability. Do not replace it with a label or assignee.

Recheck eligibility after claiming and again before publishing an outcome. A newly opened PR or changed request can
invalidate the planned action. Preserve existing dirty checkout work; use an
isolated branch or worktree from the fetched remote default branch for a PR.

## Investigate and route

Read the original report, attachments, comments, related issues, project
context and decisions, current code and behavior, and any relevant runtime
evidence. Choose the smallest outcome that actually resolves the request:

- If the requested result is clear and the change is small, implement it,
  select a public test seam, verify the affected behavior in the running
  product when one exists, and obtain one completed automated review of the
  whole diff. Repair confirmed ordinary-path defects and rerun affected checks.
  Raise a ready-for-review implementation PR with the evidence through `pr`,
  linking the original issue. Do not claim runtime proof from static checks.
- If the result is clear but spans substantial behavior or requires a durable
  design choice, write `docs/specs/<slug>/spec.md` as the implementation
  contract and raise a spec PR. Record `Issue: <tracker>:<id>` for the
  original issue beside the spec's source links, so PR creation reuses it
  instead of creating another. Raise the spec PR through `pr`. Do not start
  implementation in this triage run. An unmerged spec is a draft, and its PR
  remains linked to the original issue.
- If a missing fact prevents either path, ask for precisely that fact in a
  comment and set `needs-info` through the configured convention.
- If a product choice remains, leave `needs-decision`: explain the choice,
  viable options and their consequences, the AI recommendation and its basis.
  Produce or attach screenshots, short video, reproduction steps, comparisons,
  logs, or running links when they help the person decide. Distinguish observed
  evidence, inference, and unknowns. Check media for sensitive data before
  sharing it. Ask in a comment where the person can reply.
- For a proven duplicate or already implemented request, show the linked
  evidence and reason, then apply the convention's completed disposition. For
  a new product request that may be declined, recommend proceed, defer, or
  decline with consequences and leave the choice to a person.

Raise either PR by invoking the `pr` skill with the branch, the base, the
issue ID this run triaged, and the verification evidence collected; it writes
the body, evidence, and issue links and hands back the PR URL. Later
reconciliation reads the links it leaves: an
`Issue: <tracker>:<id>` line
in the body, and the convention's closing reference only on the implementation
PR, whose verified diff delivers the direct implementation even without a spec
folder or `Spec-Folder` trailer. A spec PR carries no closing reference. Use
available specialized shaping, implementation, or verification skills when they
fit, but carry the outcome above even when those skills are absent.
Resolve technical choices from evidence; do not turn them into human questions.
Do not treat a speculative implementation as a clear small issue merely to
avoid writing a spec or asking about expected behavior.

## Keep one issue readable

Preserve the human report. Use the bundled
[body section renderer](scripts/body-sections.py) on the freshly fetched body
to update only a clearly bounded `Triage 요약` section
with confirmed facts, current state, and next action. Keep questions and human
answers in comments; fold settled answers into the summary. A spec PR also
adds a bounded spec section in that same issue, marked draft until merged.
The repository's `spec.md` is authoritative: render the issue section from it,
and refresh that section when the merged contract changes. Never hand-edit an
independent second spec. If a body edit or section boundary is ambiguous,
preserve it and ask only for the missing distinction.

Use the convention's body-update operation to re-read the latest body and
replace only the AI-managed section. Recheck the resulting body against the
human content read immediately before the write. A Git claim serializes agents,
not human edits; when the tracker provides no conditional body update, do not
claim an atomic preservation guarantee. Repair any observed loss of human
content from available revision evidence, or leave the outcome incomplete and
report the lost-edit risk. Every outcome writes the `Triage 요약` section, which
marks the issue as triaged for later runs. Link PRs without closing the original issue on a spec PR. Once a spec
folder's `Issue:` line names this issue, `merge`, `implement`, PR creation, and
context maintenance reuse it by that ID and create no other issue.
After publishing either PR, clear triage and waiting labels and apply the
convention's review or in-progress signal. An open PR keeps the issue out of
later triage runs; if it closes unmerged, clear its review signal as above
when no other active work remains. After a spec-only PR merges, `merge` returns
its issue to the convention's non-active, ready-for-implementation state;
do not leave the PR review signal blocking `implement`.

## Report only new decisions to the person

On a scheduled run, group links to issues that received a **new** decision
request in this run, with one-line descriptions. When none did, keep the run's
user notification quiet; issue comments, body updates, and PRs retain the
results. Report blocked claims or failed writes with their exact retry path.
