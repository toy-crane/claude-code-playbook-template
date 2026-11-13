---
name: merge
description: Carry the current repository change through a verified GitHub pull request merge into the requested base, or the repository's remote default branch when none is named, then hand the merged branch to clean-branches so its worktree and local branch are cleaned up with the project's declared cleanup commands. Always use this skill for an actual PR merge or its post-merge cleanup, including requests to inspect, finish, land, or merge an existing PR; create a PR and merge it; preserve meaningful commits; or clean up an already-merged worktree. Report an existing merge instead of duplicating it. A sweep of a repository's accumulated branches and worktrees belongs to clean-branches.
---

# Merge pull request

Carry the current request's change through a pull request, verified merge, and
safe local cleanup. Complete the necessary commit, synchronization, publication,
and PR work, using the `pull` skill for base synchronization, the `pr` skill to
create or update the pull request, the `babysit-pr` skill to bring it to
ready, and the `clean-branches` skill for the cleanup after the merge.

This skill requires `pull`, `pr`, `babysit-pr`, and `clean-branches`. Before doing any work,
confirm each one is installed. When one is missing, stop and report it with
its install command, `npx skills@latest add toy-crane/skills --skill <name>`,
using the project's package manager runner where it pins one.

Start from current remote truth. Preserve unrelated work, commit only the
request's changes as logical Conventional Commits, resolve the named base or
the remote's advertised default branch. If the change or its pull request is
already merged, verify and report that outcome instead of creating another one.
For an existing open PR, fetch its current head and synchronize the checkout
with it, preserving both the observed remote commits and in-scope local work.
If their intended combination is unclear, report the blocker before rebasing
or publishing. Then invoke `pull` with that resolved remote and base before verification,
publication, and creating or updating the ready-for-review PR; it hands back
the checkout rebased onto the fetched base, or the exact blocker when it could
not rebase safely.
Preserve unrelated local work; do not silently
commit, stash, or discard it to make synchronization possible. Resolve conflicts
only when the intended result is established; otherwise keep the work
recoverable and report the blocker. Verify the resulting HEAD before publication,
and publish rewritten history only against the remote PR branch state just
observed.
When the repository's `AGENTS.md` or `CLAUDE.md` carries an `## Issue tracker`
section, read its linked detailed convention when present; legacy inline
conventions also work, without a separate setup skill installation. Without
the section, skip every issue step in this skill except reporting a
post-release check it could not open. Read the
`Spec-Folder: docs/specs/<slug>/` trailers from the branch's commits before
merging, while the branch still exists and before a squash can drop them, and
keep those folders for the tracker and post-release check steps below.

## Respect merge order

Before rebasing, read the `Blocked by:` lines in the `spec.md` of each spec
folder the branch carries, found through its `Spec-Folder` trailers or the
`docs/specs/<slug>/` folders its diff touches. When a blocking folder's work
is not on the fetched base yet, for example because the PR that delivers it
is still open, leave this PR open and report which folder it waits on. Pull
requests without such a block merge in the order they meet their merge
conditions: whichever is ready first merges first, and the rest rebase
afterwards and pass the rebase checks below.

## Check what a rebase carried

Run these checks after every rebase of the PR branch and before publishing
it: the one `pull` hands back, a rebase repeated to recover a rejected merge,
and one already sitting unpublished in the checkout.

First compare the PR's commits before and after the rebase, one by one, with
`git range-diff <old-base>..<old-head> <new-base>..<new-head>`. The old head
is the remote PR branch just observed, or `ORIG_HEAD` and the reflog when the
rebase happened earlier. Each rebased commit should carry the same intended
change. Also read the incoming base commits against the PR's changes, because
range-diff shows an unchanged patch when the base already holds the same
change elsewhere. When a change the PR intends is missing, or the rebased
branch adds again what the base already holds, such as a second copy of an
entry, function, or fix, correct the branch before publishing. When the
intended result is unclear, keep the PR open and report the blocker.

Then list the base commits that arrived since the PR branched and find the
ones that overlap it: they touch a file the PR changes, or change behavior the
PR calls or relies on, such as a default value, a shared constant, or a
helper's name or signature. For each overlap, re-verify on the current head
the behaviors that the PR's spec acceptance criteria or PR body state and the
overlap could affect, by running or exercising them. Passing tests and CI do
not settle this when they do not exercise the assumption the overlap changed.
Correct the PR when its intended behavior is clear; otherwise keep the PR open
and report the blocker. Without an overlap, the verification below is enough;
a rebase does not by itself call for repeating every check. An overlap decides
only how much to re-verify, never whether to rebase: a branch behind its base
still goes through `pull` and these checks before it merges.

## Create or update the PR with `pr`

After verifying the synchronized HEAD, invoke the `pr` skill with the
resolved remote and base. It publishes the branch and creates the
ready-for-review PR, or reuses the open PR and brings its body and evidence in
line with the final change, including any issue links. Verify before invoking
it, because it publishes. `pr` finishes by handing back the PR URL; here that
is an intermediate step, so continue to the merge below instead of stopping to
report. Invoke it again only when the change itself makes the body outdated,
not when a rebase merely moves the head.

## Bring the PR to ready with `babysit-pr`

After `pr` hands back the pull request, and before any merge step below,
invoke `babysit-pr` with it. It answers CI and review bots and hands back
ready or needs a person. Continue to the merge only on ready, and recheck that
the head it reported is still the current head; when a later step moves the
head, invoke it again before merging. On needs a person, keep the
pull request open, enable no auto-merge, and report the reason it gave.

With a tracker configured, confirm on the remote PR before merging what the
reconciliation below reads back: each spec folder the PR carries has its one
issue, named by the `Issue: <tracker>:<id>` line in its `spec.md` and repeated
in the PR body, and the body carries the convention's closing reference only
when the PR delivers implementation. If a linked convention cannot be read,
report the missing information rather than guessing issue operations or
claiming that the issue was linked or closed.

## When no person is present

When the invoking skill says no person is present, ask the user anything
through the harness's question tool, not as chat text. When no answer comes,
stop without merging, leave the pull request open with no auto-merge armed,
and report the question. Pass the same signal to `babysit-pr`. Without that
signal, everything here applies as written.

## Merge and clean up

Preserve multiple commits with a rebase merge only when they are meaningful,
independent units worth retaining in the base branch; use a squash merge
otherwise.
If GitHub cannot rebase-merge the pull request because its commits conflict
with the base, repeat the `pull` synchronization above on the PR branch.
Resolve conflicts when the intended combined result
is established, preserve unrelated local work, and publish rewritten history
only against the PR branch state just observed. If intent is unclear or the
remote branch changed unexpectedly, keep the PR open and report the blocker.

After updating the PR head, use only verification of the current head; earlier
CI results do not verify the new commit. Finish relevant checks that GitHub
does not require before allowing a merge. Enable auto-merge only when the
repository permits it, GitHub enforces checks against the current base (for
example, by requiring branches to be up to date or using a merge queue), and
only GitHub-enforced requirements remain pending. Verify that it is enabled,
then wait for the remote to report `MERGED`. If current-base verification is
not enforced, auto-merge is unavailable, or the PR is already mergeable, finish
its relevant CI and required checks and reviews, then merge directly with the
chosen method after rechecking the current head and base. `gh pr merge --auto`
can merge an already-mergeable PR immediately;
it is not a general wait flag. If enabling auto-merge fails, reassess the PR
and use direct merge only after its verification and requirements pass.

Right before merging, directly or by enabling auto-merge, fetch the base
again and compare it with the base your last passing verification ran on,
for example with `git log --name-only <verified-base>..<remote>/<base>`. Run
this comparison as its own command and read its output before deciding; never
chain the fetch and the merge in one command, because the merge then runs
before anyone sees what landed. When a commit that landed touches this PR's
files, do not merge on that verification: rebase again, run the rebase checks
above on the new head, and merge only once they and the current head's
verification pass.

While waiting, recheck the current head, base, relevant CI, and required checks
and reviews. If the head or base changes, reassess mergeability and repeat
verification for the current head. A head-match option on the enable request
does not pin later auto-merge to that head; a push by someone with write access
can leave auto-merge armed. Whenever new agent-side or non-required verification
is needed, including after a base-only change or a late check on the same head,
disable pending auto-merge while the PR is still open and verify its removal
before waiting for that verification. Also disable it if merge intent can no
longer be established and work must stop. Before ending with an open PR because
CI failed or a requirement remains unmet, disable any pending auto-merge and
verify its removal. Report those blockers rather than bypassing them. Respect
required checks and reviews without imposing a review request that the
repository does not require, and treat the remote pull request state as the
authority for whether the merge succeeded.

Clean up only after the remote reports `MERGED`, and only the merged branch.
Invoke `clean-branches` with the merged branch, its worktree when one exists,
the fetched base, and the merged pull request's head commit, so a squashed
branch can still be deleted. It runs the project's declared cleanup commands,
removes the worktree and local branch only when nothing still works inside,
and keeps a folder this session works in, a branch with uncommitted changes,
or one with commits the base does not contain. Report its result lines,
including any `holder` process or a branch it kept, beside the verified merge.
Preserve other worktrees, processes, and user changes. When the merged branch
lived in a linked worktree, `clean-branches` leaves the canonical base
checkout alone, so bring it to the merged remote state afterwards using
whatever safe mechanism the current host provides; when the branch was in
the primary checkout, `clean-branches` already did that.

## Reconcile spec folders with the issue tracker

After the remote reports `MERGED`, and only when the repository's `AGENTS.md`
or `CLAUDE.md` carries an `## Issue tracker` section, bring the tracker into
line with the spec folders now on the base branch, using the convention's tool,
issue ID form, and operations. Read both files and use the first section found and its
linked detailed convention when present. Without the section, skip this entirely.

Diff the merge range for `docs/specs/<slug>/` folders and find each folder's
issue by the `Issue:` line in its `spec.md`, never by title. Create no issue
here; a folder without the line has none yet. For each issue whose `spec.md`
changed, refresh only its bounded spec section through the convention,
keeping its title and every other part of its body, and recheck that content
afterward. An issue an agent created is treated exactly like one a person
wrote: its title does not follow later spec title changes. Replace its
blocking edges when its `Blocked by` lines changed, resolving each blocker
folder through its own `Issue:` line. Deleting a folder never closes its
issue; only confirmed implementation delivery does.

After a PR that actually delivered implementation, close the issue of each
implemented folder named by its `Spec-Folder` trailer if still open, whatever
the tracker's automatic closing does: a merge into a non-default base, a squash
message without the trailer, or a tracker with no closing reference can leave
it open otherwise. A spec-only merge never closes the issue, even when its
commits carry that trailer. A direct small implementation PR may have no spec
folder or trailer: inspect the current PR's exact `Issue:` line, diff, and
verification, then close that issue now when they establish implementation
delivery. A line alone never closes an issue. Verify the resulting tracker
state and report a failed close for retry. After a spec-only PR merges, leave
its issue open and use the convention's mark-ready operation to clear the PR
review or in-progress signal and leave it in a non-active,
ready-for-implementation state. Check for newer active implementation first;
never demote work that has already started. Verify the resulting state so
`implement` can claim it without a special resume request. If the convention
lacks this operation or the update fails, report the blocked handoff instead of
assuming the issue is ready.

A tracker failure never undoes the verified merge: report which operation
failed and why. On later runs, search merged PR bodies for the exact
`Issue: <tracker>:<id>` line, fetch each issue by that ID, and retry an open
issue's closure only when that PR's diff
and verification establish actual implementation delivery. A linked spec PR or
trailer alone is insufficient. For a merged spec-only PR, retry the recorded
mark-ready operation when the issue still carries its
review or active signal and no newer implementation has started. For a delivered
folder with a post-release check and no check issue, retry its creation with
the due date counted from the original merge timestamp. Report missing
evidence or a failed retry. This catch-up works after the original branch and
trailers disappear in a squash merge.

## Open a post-release check

After a PR that actually delivered implementation, by the same evidence used
for closing above, look at each implemented folder's `spec.md` on the merged
base, whether or not a tracker is configured. When it has a `## Post-release check` section whose content is not
`None.`, and the tracker convention has a `Check issue` item, open one check
issue for that folder through that item. A spec-only merge, a direct fix with
no spec folder, a missing section, or `None.` opens nothing.

First look for an existing check issue for the folder through the item's
lookup, which matches the `Spec-Folder: docs/specs/<slug>/` line in the check
section, in any state; when one exists, create nothing and report it. The due
date is the remote's merge timestamp plus the period the section states,
taken as a calendar date in the time zone the `Due date` item names, or UTC
when it names none, and written in that item's form. The body is the item's bounded
check section: the `Spec-Folder:` line, the merged PR, a `Merge-Commit:` line
with the merge commit the remote reports on the base, the due date, and the
section's content copied as written. The commit keeps the measurement file
readable after the spec folder is retired. Do not run the measurement or judge the
target here; the check is read when it comes due. When the repository has no
tracker convention, the convention has no `Check issue` item, its tool is
unavailable, or the section states no period, create nothing and report the
check that was not opened and which of these stopped it. Verify the created
issue's state and due date, and report its link.

Finish with the merged pull request URL, merge strategy, verified remote state,
cleanup result, the tracker issues created, updated, or closed, and each
post-release check issue opened, found, or skipped with its reason. Keep a
cleanup or tracker failure visible without misreporting the already verified
merge.
