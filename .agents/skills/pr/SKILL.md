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

Create the pull request ready for review with a title, summary, and validation
evidence that describe the actual change. Leave merging, required reviews, and
release decisions outside this skill's authority.

Finish when the remote pull request exists in ready state and the user has its
URL, base, head branch, and any checks or evidence that remain outstanding.
