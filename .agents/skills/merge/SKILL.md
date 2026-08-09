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
