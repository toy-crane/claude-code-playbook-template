---
name: pull
description: Rebase the current Git checkout onto the requested remote base branch, or the repository's remote default branch when none is named, without losing local work. Always use this skill for an actual base-branch synchronization operation, including requests to pull or sync main, master, trunk, or the default branch; update a branch from its base; rebase onto a remote base; bring incoming base commits into the current checkout; or update a detached worktree from that base.
---

# Pull base branch

Bring the current checkout onto the latest requested remote base through a
rebase so the history remains linear. When the request does not name the base,
resolve the remote's advertised default branch rather than assuming its name.

Preserve all local work. A dirty working tree is not authority to commit,
stash, or discard its contents; leave it intact and identify what prevents a
safe update. Fetch the remote truth before deciding whether any update is
needed.

Rebase rather than introducing a merge commit. Resolve a conflict when the
intended result is established by the request and project evidence. When intent
is ambiguous, keep the original work recoverable and report the conflicting
files and the smallest decision needed to continue.

Finish when the checkout is based on the fetched target branch, local work is
preserved, and the user knows the resolved remote and base, whether it was
already current, or which commits arrived.
