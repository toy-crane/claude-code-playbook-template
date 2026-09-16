---
name: pr
description: Publish the current repository change as a ready-for-review GitHub pull request against the requested base, or the repository's remote default branch when none is named. Always use this skill for an actual PR publication, including requests to create, open, raise, publish, or reuse a pull request, put work up for review, or make and share a GitHub review link. Complete the needed commit, base synchronization, and branch publication, but stop before merge.
---

# Create a pull request

Turn the current request's change into one ready-for-review pull request against
the named base, or the remote's advertised default branch when none is named.
Complete the necessary local Git work instead of requiring other skills to be
installed.

Preserve unrelated work while committing the request's changes as logical
Conventional Commits. Keep credentials and other sensitive files out of the
history, honor repository checks, and move work on a detached or protected
checkout to a suitably named branch.

Base the branch on the fetched target and publish it without overwriting
unexpected remote work. Reuse an existing pull request for the same head and
base; when the change is already represented on that remote base, report the
state instead of duplicating it.

Create the pull request ready for review with a title and body describing the
actual change. Leave merging, required reviews, and release decisions outside
this skill's authority.

## Make the body understandable

Write for a reviewer without the conversation history: explain the problem,
concrete before-and-after behavior, why it changed, and what verification
establishes. Scale the explanation to the change; a typo fix needs only a brief
description and relevant validation. Include mechanisms, a diagram for complex
flows, actual alternatives and trade-offs, affected users or integrations, and
specific unresolved judgments when they help assess the change. Keep the whole
change understandable beyond those highlighted judgments; omit empty sections
and invented alternatives or questions.

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

## Finish

Finish when the remote pull request exists in ready state and the user has its
URL, base, head branch, and any checks or evidence that remain outstanding.
