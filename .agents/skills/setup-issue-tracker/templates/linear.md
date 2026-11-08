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
and no review or active state, oldest first; filter the returned descriptions
locally rather than through search. Record linked PR lookup, evidence
attachments, and duplicate disposition. Record the stale-review query: the
team's open issues in the review state, kept when no linked PR is open. Record
the move to Backlog for an issue whose spec PR closed unmerged; it clears the
stale review state and leaves the issue's sections in place. Record an operation
that re-reads the latest description and updates only bounded AI-managed
sections while preserving human content.
Record whether the available tool conditionally updates descriptions;
otherwise re-read and verify after writing, recover any observed human edit,
and report the remaining race.
