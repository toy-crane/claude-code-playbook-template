# Github tracker convention template

## Agent instructions

```markdown
## Issue tracker

- Manage spec state and configured general-issue triage in GitHub Issues in `<owner>/<repo>`.
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

Tracker: GitHub Issues through the `gh` CLI, on the repository `git remote`
points at. Issue ID form: `github:#<number>`, written as `Issue: github:#<n>`
in `spec.md` and in PR bodies. Titles carry no key or prefix. Address every
issue by that number; never find one by title search or by listing issues.

Spec section markers: `<!-- triage-issues:spec:start -->` and
`<!-- triage-issues:spec:end -->`, the same markers the triage body renderer
writes. Create, refresh, and every other skill use exactly these.

- Find: `gh issue view <n> --json number,title,state,assignees,labels,body`.
  List open blockers with `gh api
  repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by --jq '[.[] |
  select(.state == "open") | .number]'`, and read any `Blocked by: #<n>` body
  line where dependencies are unavailable.
- Create: `gh issue create --title "<spec title>" --label <review label>
  --body-file -` with the bounded spec section as the whole body; read the new
  number from the returned URL.
- Refresh the spec section: re-read the body with `gh issue view <n> --json
  body`, replace only the text between the spec section markers, write it back
  with `gh issue edit <n> --body-file -`, then re-read and confirm the rest of
  the body is unchanged. Never edit the title.
- Update blockers: read every current relation, including closed blockers, with
  `gh api --paginate
  'repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by?per_page=100' --jq
  '.[].number'`; collect every returned number as the complete set, compare it
  with the desired set, remove every stale edge with `gh issue edit <n>
  --remove-blocked-by <old blocker>`, and add every missing edge with `gh issue
  edit <n> --add-blocked-by <new blocker>`. Where dependencies are unavailable,
  replace the complete set of `Blocked by: #<n>` body lines so stale lines are
  removed as well as missing lines added.
- Claim: `gh issue edit <n> --add-assignee @me --add-label <active label>`;
  the current account is `gh api user --jq .login`.
- Mark ready: after a spec-only PR merges, `gh issue edit <n> --remove-label
  <review label>`, leaving the issue open and unassigned work for `implement`.
- Close: `Closes #<n>` in the implementation pull request body closes it on
  merge into the default branch; `gh issue close <n>` when it is still open
  after the merge.

Record the label names chosen for the review and active signals, and verify
they exist in the repository before use.

When general-issue triage is enabled, extend this convention with the selected
open-issue scope (including Backlog), `needs-triage`, `needs-info`, and
`needs-decision` label mapping, linked PR lookup, evidence attachments, and
duplicate disposition. Verify the labels in the repository before use. Record
the not-yet-judged query: `gh issue list --state open --limit 1000 --json
number,createdAt,labels,body`, which excludes PRs; raise `--limit` above the
open-issue count, since the default of 30 drops older issues. Keep issues whose
body has neither the `<!-- triage-issues:triage:start -->` nor the spec section
and which carry none of `needs-info`, `needs-decision`, the review label, or the
active label, oldest first; filter the returned bodies locally rather than through search. Record
the stale-review query: `gh issue list --state open --label <review label>
--limit 1000 --json number,body`, then keep issues with no open linked PR, read
through the timeline's cross-referenced PRs and PR bodies carrying their
`Issue:` line. Record how an issue whose spec PR closed unmerged loses its
stale review label while keeping its sections. Record an operation that re-reads the latest body
and updates only bounded AI-managed sections while preserving human content.
GitHub REST conditional `PATCH` is not generally supported: verify the body
after writing, recover an observed concurrent edit when possible, and report
the remaining race instead of claiming atomic preservation.
