---
name: pr
description: Create or reuse a ready-for-review GitHub PR for the current repository change against the requested base, or the repository's remote default branch when none is named. Always use this skill for an actual PR publication, including requests to create, open, raise, publish, or reuse a pull request, put work up for review, or make and share a GitHub review link. Complete the needed commit, base synchronization, and branch publication, but stop before merge.
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
actual change. When the repository's `AGENTS.md` or `CLAUDE.md` carries an
`## Issue tracker` section, read it and its linked detailed convention when
present; legacy inline conventions also work without the setup skill installed.
Without the section, skip every issue step below and leave the body unchanged.

## Link each spec folder to one issue

With a tracker configured, gather the spec folders this PR carries before
creating it: every `docs/specs/<slug>/` folder the branch adds or changes, and
every folder named by a `Spec-Folder: docs/specs/<slug>/` commit trailer, that
still exists at the head. Skip folders the branch deletes. A folder's
`spec.md` names its issue with an `Issue: <tracker>:<id>` line; use that ID and
create nothing.

For each gathered folder without that line, create one issue through the
convention's create operation: the title is the first heading of `spec.md`
with no prefix, the body is one spec section rendered from `spec.md` between
the convention's spec section markers, and the issue carries the
convention's review signal so general triage leaves it alone before the PR
links it. The section holds the first section's text,
the remaining section headings, the folder path, and the issues of folders its
`Blocked by: docs/specs/<other>/` lines name, read from their own `Issue:`
lines; report a blocker folder that has none. Then write
`Issue: <tracker>:<id>` in the convention's ID form beside the spec's other
links, commit it on the same branch, and only then publish and open the PR.
Never search the tracker by title to find or reuse an issue. If the issue was
created but the line could not be committed, stop before opening the PR and
report the created ID so a rerun records it instead of creating another.

Put an `Issue: <tracker>:<id>` line in the PR body for each linked issue, so a
later pass can find the PR after the branch is gone. A PR with no spec folder
that fixes a known issue directly carries the same line. Put the convention's
closing reference in the body only when the PR actually delivers that issue's
implementation, as established by the diff and verification; a trailer or
`Issue:` line alone does not establish delivery. A spec-only PR links its issue
without a closing reference. When reusing an existing PR, apply the same steps
and bring its body in line. Leave merging, required reviews, and release
decisions outside this skill's authority.

If a linked convention cannot be read, report the missing information rather
than guessing issue operations or claiming that the issue was linked or closed.

## Make the body understandable

Write for a reviewer without the conversation history: explain the problem,
concrete before-and-after behavior, why it changed, and what verification
establishes. Scale the explanation to the change; a typo fix needs only a brief
description and relevant validation. Include mechanisms, a diagram for complex
flows, actual alternatives and trade-offs, affected users or integrations, and
specific unresolved judgments when they help assess the change. Keep the whole
change understandable beyond those highlighted judgments; omit empty sections
and invented alternatives or questions.

For screen changes, let the reviewer watch the behavior they are judging.
Record the actual base and head running the same flow at matching viewport,
data, and state, or reuse evidence verified to match those revisions, and embed
the before-and-after videos with a short explanation of the difference and its
reason. When motion adds nothing to the judgment, as with copy, styling, or
static layout, compare screenshots side by side instead; when such fine visual
detail accompanies a behavior change, add that still comparison to the videos.
A screen with no before state gets the head video alone. If video cannot be
recorded, made safe, or kept within the attachment limit after trimming to the
judged behavior, compare screenshots and say why video is missing. Video takes
no alt text, so label each one with its revision, flow, and conditions, and
identify unavoidable differences between the captures. Separate observed
results from source inference and unverified states; a prototype is not runtime
evidence. When updating an existing PR, bring its explanation and evidence into
line with the final change, replacing outdated visual claims.

Before uploading, inspect screenshots and videos for credentials, personal
data, and private information. Use safe seeded data or redact those details
throughout the media, keeping comparison conditions and the relevant change
visible. Upload only the inspected, safe media as GitHub attachments, using a
supported mechanism in the current environment. For GitHub CLI, check attachment support: `gh pr create` and
`gh pr edit` accept repeatable `--attach` on supported versions and rewrite
matching local media references in `--body-file` to uploaded URLs. A Markdown
table can place two images side by side. Reference each video as `![](path)`
alone in its own blank-line-separated paragraph so it renders as a player; a
reference inside other text renders as a link, and an unreferenced attachment
lands at the end of the body. Keep review captures outside repository history;
no separate media host is needed.

If baseline execution, capture, or upload is unavailable, state the exact limit
and present only the evidence obtained. Inspect the resulting remote body and
attachments before reporting them as available to reviewers; a local path is
not a published attachment. A partial upload may still create the PR: inspect and
repair that PR instead of duplicating it. Carry successful attachment URLs from
the remote body into its replacement, and replace unusable local references
with an honest limitation if recovery fails.

## Finish

Finish when the remote pull request exists in ready state and the user has its
URL, base, head branch, and any checks or evidence that remain outstanding.
