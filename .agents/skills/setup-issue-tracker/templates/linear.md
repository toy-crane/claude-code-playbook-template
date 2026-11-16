# Linear tracker convention template

## Agent instructions

```markdown
## Issue tracker

- Manage spec state and configured general-issue triage in Linear team `<team>`.
- Resume an issue already in progress only when the user explicitly requests it.
- Each spec folder names its one issue with an `Issue: <tracker>:<id>` line in `spec.md`; find issues by that ID, never by title.
- Link the issue through its PR. A spec PR keeps it open; close it when implementation merges.

For issue work, read [the tracker convention](docs/issue-tracker.md).
```

## Detailed convention: `docs/issue-tracker.md`

Adapt the guidance below to the repository and the currently available tool.
Keep repository-specific choices; consult current tool help for argument details.
Record how active work is recognized and claimed. An issue already in progress
requires an explicit user request to resume, even with the same assignee.

Tracker: Linear, team `<team key>`, through <the Linear MCP server or CLI this
session verified>. Issue ID form: `linear:<identifier>`, written as
`Issue: linear:<identifier>` in `spec.md` and in PR bodies. Titles carry no key
or prefix. Address every issue by that identifier; never find one by title
search, because Linear search ranks by meaning and may miss an exact title.

Spec section markers: `<!-- triage-issues:spec:start -->` and
`<!-- triage-issues:spec:end -->`, the same markers the triage body renderer
writes. Create, refresh, and every other skill use exactly these.

- Find: fetch the issue by identifier and read its state, assignee,
  description, and open blocking relations.
- Create: create an issue in the team titled with the spec title, with the
  bounded spec section as its whole description, in the team's review state
  (for example, a verified In Review state). Return the new identifier.
- Refresh the spec section: re-read the description, replace only the text
  between the spec section markers, write it back, then re-read and confirm the
  rest is unchanged. Never edit the title.
- Update blockers: replace the complete "blocked by" relation set, removing
  stale blocker issues and adding missing ones.
- Claim: assign the issue to the current Linear user and move it to the
  team's in-progress state. Record which states count as active, including
  review states when applicable. The same assignee does not prove resumption.
- Mark ready: after a spec-only PR merges, move the issue from the review state
  to the team's non-active ready state (for example, a verified Todo state),
  never to Triage.
- Close: record the PR closing reference and the team's verified integration
  behavior. After merge, move the issue to the team's done state if the
  integration has not closed it.

When general-issue triage is enabled, record which team states are open and
which include Backlog. Map `needs-triage` to native Triage or a label as
appropriate, and verify the selected `needs-info` and `needs-decision` labels.
Record the not-yet-judged query: the team's open issues, including Triage and
Backlog, whose description has neither the `<!-- triage-issues:triage:start -->`
nor the spec section and which carry no `needs-info` or `needs-decision` label
and no review or active state, and whose due date, when set, is today or
earlier; order issues with a due date first, earliest first, then the rest
oldest first. Filter the returned descriptions locally rather than through
search. Record linked PR lookup, evidence
attachments, and duplicate disposition. Record the stale-review query: the
team's open issues in the review state, kept when no linked PR is open. Record
the move to Backlog for an issue whose spec PR closed unmerged; it clears the
stale review state and leaves the issue's sections in place. Record an operation
that re-reads the latest description and updates only bounded AI-managed
sections while preserving human content.
Record whether the available tool conditionally updates descriptions;
otherwise re-read and verify after writing, recover any observed human edit,
and report the remaining race.

Due date: Linear's native issue due date, set and read as a calendar date.
The not-yet-judged query returns it with each issue. A check issue also
repeats it as the `Due:` line of its check section for readers.

Check issue: created by `merge` after an implementation PR whose spec folder
has a `## Post-release check` section other than `None.`.
- Title: `Post-release check: <spec title>`.
- State: the team's verified Backlog or another open state the not-yet-judged
  query returns, never Triage, a review state, or an active state, with a
  verified `post-release-check` label.
- Assignee: none, unless the repository names who owns release results.
- Due date: the merge date plus the section's period, set on the native field.
- Body, as the whole description:
Record the time zone that turns a merge timestamp into a due date; UTC
when none is named.

```markdown
<!-- triage-issues:check:start -->
## Post-release check

Spec-Folder: docs/specs/<slug>/
Merged: <merged PR URL> at <merge timestamp>
Merge-Commit: <merge commit SHA on the base>
Due: <YYYY-MM-DD>

<the spec's `## Post-release check` content, copied as written>
<!-- triage-issues:check:end -->
```

- Find an existing one: list the team's issues in every state carrying the
  `post-release-check` label and keep the issue whose check section carries
  the folder's exact `Spec-Folder:` line; filter descriptions locally rather
  than through search.
- Create: create the issue in the team with the title, state, label, due
  date, and description above, and return its identifier.

Notifications: None.
Replace `None` with the method that copies each triage report to people, such
as a chat channel and the verified tool that posts to it, only when the user
asks for one. The tracker stays the record; a failed send is reported and
never fails a run.
