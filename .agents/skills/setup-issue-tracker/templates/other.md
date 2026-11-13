# Other tracker convention template

## Agent instructions

```markdown
## Issue tracker

- Manage spec state and configured general-issue triage in <tracker and project or team>.
- Resume an issue already in progress only when the user explicitly requests it.
- Each spec folder names its one issue with an `Issue: <tracker>:<id>` line in `spec.md`; find issues by that ID, never by title.
- Link the issue through its PR. Keep it open through a spec PR; close it when implementation merges.

For issue work, read [the tracker convention](docs/issue-tracker.md).
```

## Detailed convention: `docs/issue-tracker.md`

Adapt the guidance below to the repository and the currently available tool.
Keep repository-specific choices; consult current tool help for argument details.
Record how active work is recognized and claimed. An issue already in progress
requires an explicit user request to resume, even with the same assignee.

Tracker: <name>, through <tool the session verified>. Issue ID form:
`<tracker>:<id>`, written as `Issue: <tracker>:<id>` in `spec.md` and in PR
bodies. Titles carry no key or prefix. Address every issue by that ID; never
find one by title search or by listing issues.

Spec section markers: `<!-- triage-issues:spec:start -->` and
`<!-- triage-issues:spec:end -->`, the same markers the triage body renderer
writes. Create, refresh, and every other skill use exactly these.

<One paragraph in the user's words describing how issues are fetched, created,
updated, assigned, moved between states, and closed, covering each of the
seven operations below.>

- Find: <command; fetches the issue by ID and returns open state, state,
  assignee, open blockers>
- Create: <command; spec title, bounded spec section as the whole body, review
  signal; returns the new ID>
- Refresh the spec section: <command; re-reads the body, replaces only the
  marked spec section, keeps the title and every other part, verifies>
- Update blockers: <command; replaces the complete relation set by removing
  stale edges and adding missing ones>
- Claim: <command>
- Mark ready: <command; clears the review or active signal after a spec-only
  PR merges and leaves the issue open in a non-active state outside triage>
- Close: <command, or the pull request body reference that closes it on merge>

If general-issue triage is configured, also specify its open scope including
Backlog; `needs-triage`, `needs-info`, and `needs-decision` state/label mapping;
the not-yet-judged query, which returns open general issues with neither the
`<!-- triage-issues:triage:start -->` nor the spec section and none of those
results, leaving out issues whose due date is still ahead, with due issues
first, earliest due date first, then the rest oldest first; active work and linked PR lookup; comment and evidence
publishing; duplicate disposition; the stale-review query, which returns open
issues carrying the review signal with no open linked PR; the return to a
non-active state when a spec PR closes unmerged; and a bounded AI-section body update that
preserves the latest human report and verifies the result. Record whether the
tracker supports conditional updates; if not, report the remaining human-edit
race.

Due date: <how an issue's due date is set and read as a calendar date: the
tracker's native field, or a `Due: <YYYY-MM-DD>` body line when it has none.
The not-yet-judged query returns it with each issue.>
Record the time zone that turns a merge timestamp into a due date; UTC
when none is named.

Check issue: created by `merge` after an implementation PR whose spec folder
has a `## Post-release check` section other than `None.`.
- Title: <form, such as `Post-release check: <spec title>`>.
- State: <an open state the not-yet-judged query returns, never an active or
  review state; the label that narrows the lookup, when the tracker has labels>.
- Assignee: <none, or who owns release results>.
- Body, as the whole issue body:

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

- Find an existing one: <command; returns issues in every state whose check
  section carries the folder's exact `Spec-Folder:` line>.
- Create: <command; title, state, due date, body; returns the new ID>.

Notifications: None.
Replace `None` with the method that copies each triage report to people, such
as a chat channel and the verified tool that posts to it, only when the user
asks for one. The tracker stays the record; a failed send is reported and
never fails a run.
