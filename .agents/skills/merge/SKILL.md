---
name: merge
description: Carry the current repository change through a verified GitHub pull request merge into the requested base, or the repository's remote default branch when none is named, then clean up only the merged worktree and its owned development processes. Always use this skill for an actual PR merge or its post-merge cleanup, including requests to inspect, finish, land, or merge an existing PR; create a PR and merge it; preserve meaningful commits; or clean up an already-merged worktree. Report an existing merge instead of duplicating it.
---

# Merge pull request

Carry the current request's change through a pull request, verified merge, and
safe local cleanup. Complete the necessary commit, synchronization, publication,
and PR work without depending on other skills.

Start from current remote truth. Preserve unrelated work, commit only the
request's changes as logical Conventional Commits, resolve the named base or
the remote's advertised default branch, and create or reuse a ready-for-review
pull request based on its fetched state. If the change or its pull request is
already merged, verify and report that outcome instead of creating another one.

## Make the body understandable

When creating or updating an open PR, write for a reviewer without the
conversation history: explain the problem, concrete before-and-after behavior,
why it changed, and what verification establishes. Scale the explanation to the
change; a typo fix needs only a brief description and relevant validation.
Include mechanisms, a diagram for complex flows, actual alternatives and
trade-offs, affected users or integrations, and specific unresolved judgments
when they help assess the change. Keep the whole change understandable beyond
those highlighted judgments; omit empty sections and invented alternatives or
questions.

For screen changes, capture the actual base and head at matching viewport,
data, and state, or reuse evidence verified to match those revisions. Embed
before-and-after screenshots side by side in the body, with a short explanation
of the difference and its reason. Identify the revisions, screen and capture
conditions, including unavoidable differences. Add actual interaction video
when still images cannot explain the important behavior. Separate observed
results from source inference and unverified states; a prototype is not runtime
evidence. When updating an existing PR, bring its explanation and evidence into
line with the final change, replacing outdated visual claims.

Before uploading, inspect screenshots and videos for credentials, personal
data, and private information. Use safe seeded data or redact those details
throughout the media, keeping comparison conditions and the relevant change
visible. Upload only the inspected, safe media as GitHub attachments, using a
supported mechanism in the current environment. For GitHub CLI, check attachment support: `gh pr create` and
`gh pr edit` accept repeatable `--attach` on supported versions and rewrite
matching local image references in `--body-file` to uploaded URLs. A Markdown
table can place the two images side by side. Keep review captures outside
repository history; no separate image host is needed.

If baseline execution, capture, or upload is unavailable, state the exact limit
and present only the evidence obtained. Inspect the resulting remote body and
attachments before reporting them as available to reviewers; a local path is
not a published image. A partial upload may still create the PR: inspect and
repair that PR instead of duplicating it. Carry successful attachment URLs from
the remote body into its replacement, and replace unusable local references
with an honest limitation if recovery fails.

## Merge and clean up

Preserve multiple commits with a rebase merge only when they are meaningful,
independent units worth retaining in the base branch; use a squash merge
otherwise.
Respect required checks and reviews, and treat the remote pull request state as
the authority for whether the merge succeeded.

Clean up only after the remote reports `MERGED`. Before removing a linked
worktree, run the bundled [server cleanup helper](scripts/stop-worktree-server.sh)
from that worktree when applicable. Remove only the merged worktree and branch,
preserve other worktrees, processes, and user changes, then bring the canonical
base checkout to the merged remote state using whatever safe mechanism the
current host provides.

Finish with the merged pull request URL, merge strategy, verified remote state,
and cleanup result. Keep a cleanup failure visible without misreporting the
already verified merge.
