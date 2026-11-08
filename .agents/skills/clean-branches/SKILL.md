---
name: clean-branches
description: Clean up the local leftovers of finished work in one pass, removing worktrees and local branches whose pull request merged or closed, detached worktrees already contained in the base, and left-over worktree folders that lost their Git registration, while leaving open, uncommitted, session-attached, and Codex-managed work in place. Use when the user asks to clean up, prune, or tidy stale or piled-up branches or worktrees across a repository. merge hands this skill the one branch it just merged. Remote branches are never deleted.
---

# Clean branches

Remove the local leftovers of finished work, then report what was removed,
what stayed, and why. There are two entry points: a sweep of the whole
repository when the user asks, and one branch that `merge` hands over right
after it verified the merge. Do not ask for confirmation along the way: safety
comes from the narrow targets below, and anything that cannot be judged stays
where it is.

## Find the candidates

Fetch the remote first. The base is the branch the user names, otherwise the
remote's advertised default branch. Read `git worktree list --porcelain` for
registered worktrees and `git branch` for local branches. For folders that lost
their registration, look only inside folders of the default checkout that also
hold a registered linked worktree, such as `.claude/worktrees/`.

A worktree is a candidate when one of these holds:

- Its checked-out branch has a pull request that merged or closed. Judge this
  from GitHub, for example `gh pr list --head <branch> --state all`, because a
  squash merge leaves the branch tip outside the base history. Any open pull
  request for the branch name keeps the worktree; otherwise use the most
  recently created one, and keep its head commit for the helper.
- Its HEAD is detached and contained in the fetched base.
- It is a folder whose Git registration is gone. The helper below decides
  whether such a folder is safe to remove.

A local branch with no worktree is a candidate when its pull request merged or
closed, judged the same way. A branch checked out in the primary checkout is
never a sweep candidate: the primary checkout is left in place, and only the
handoff from `merge` below touches a branch checked out there.

Leave these in place and list them in the report: the default checkout, a
worktree on the base branch, the base branch itself, an open pull request, a
branch with no pull request even when the base contains it, a branch whose tip
has commits beyond its pull request head that the base does not contain, and
any worktree with uncommitted changes, including one this session works
inside. If `gh` is missing or not authenticated, skip worktrees and branches
with a pull request to judge, say so, and keep going with detached worktrees
and folders.

## Release and remove each worktree candidate

The project releases a worktree's development resources with its own commands.
Read `AGENTS.md` and `CLAUDE.md` and use the first `## Worktree cleanup`
section found: its fenced code block lists one command per line, and text
outside the block is for people. Without that section, stop no process.

Decide each candidate with the bundled
[worktree removal helper](scripts/remove-worktree.sh), run from this session's
own working directory: `inspect <worktree> --base <remote>/<base>`, adding
`--pr-head <sha>` for a branch with a pull request. The helper counts its
working directory as this session's, so running it after changing into a
candidate reads as `session-inside`.

- `session-inside`: this session works inside the candidate. The helper does
  not check for uncommitted changes here, so leave the candidate when
  `git status --porcelain` shows any. Otherwise run the declared commands, then
  `remove` with the same arguments. The folder stays, HEAD detaches at the
  base, and only the branch is deleted.
- `ready`: run the declared commands, then `remove` with the same arguments.
  It checks again and removes the worktree, or the folder, and its branch only
  when no process still works inside.
- `attached`, `codex-managed`, or `blocked`: leave the candidate, its
  processes, and its branch as they are. A live session, terminal, or app still
  uses an attached worktree. The Codex app manages its own worktrees and
  removes one, after saving a snapshot, when its chat is archived.

When `inspect` reports `branch <name> unmerged`, leave that worktree too: its
branch has commits that exist nowhere else.

Run the declared commands in order inside the candidate's folder. Stop at the
first failure and leave that folder and branch so the commands can run again.
Never stop a process yourself or force a removal. Handle candidates one at a
time; a candidate that stays does not stop the others.

## Delete each branch-only candidate

A branch with no worktree needs no helper and no cleanup commands. Delete it
only when its tip equals its merged or closed pull request's head commit or
the fetched base contains it; otherwise leave it and report it as unmerged.
Never delete the base branch or a branch that is checked out anywhere.

## Clean the branch that merge hands over

When `merge` invokes this skill, it passes the merged branch, its worktree when
one exists, the base, and the merged pull request's head commit. Fetch the base
first, because the remote merge moved it after any fetch `merge` made, so the
helper's base argument, the detached HEAD it leaves for a session, and the
branch-only rule all see the merged base. Then skip the candidate search and
act on that branch alone:

- In a linked worktree: run the helper with those arguments and act on its
  verdict exactly as above, including the declared cleanup commands.
- Checked out in the primary checkout: the helper reports `main-checkout` and
  `blocked`, so do not use it. When `git status --porcelain` shows uncommitted
  changes, leave the branch and report it. Otherwise bring that checkout to
  the merged base state by checking out the base and fast-forwarding it to
  the freshly fetched remote, then delete only the local branch under the
  branch-only rule.
  When the base cannot be checked out there, for example because a linked
  worktree holds it, or cannot be fast-forwarded because the local base has
  diverged, leave the checkout and the branch as they are and report why;
  never force, reset, or detach to get past it.
- Neither: delete it under the branch-only rule.

Hand the result lines back so `merge` can report them beside the verified
merge.

## Report

Finish with one report grouped as follows:

- Removed: each worktree, folder, or branch with why it qualified, such as the
  merged or closed pull request number, containment in the base, or a lost
  registration.
- Folder kept for this session: HEAD detached and the branch deleted.
- Left in place: each one with its reason, such as the open pull request
  number, uncommitted changes, a holder's PID and command, a failed cleanup
  command, a Codex-managed worktree with the archive hint, a folder whose
  `.git` cannot be verified, a branch without a pull request, or a branch
  with commits the base does not contain.
- Not judged: worktrees and branches skipped because GitHub could not be read.

Leave remote branches alone.
