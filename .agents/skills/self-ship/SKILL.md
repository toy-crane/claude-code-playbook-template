---
name: self-ship
description: Carry one settled `docs/specs/SLUG/` folder from implementation through a verified merge and cleanup with no person present, asking everything a person must answer at the start and later only through the question tool. Runs only when the user invokes it by name with one spec folder; it never runs a release or deployment.
disable-model-invocation: true
---

# Self-ship one spec folder

This skill requires `babysit-specs`, `implement`, and `merge`. Before doing
any work, confirm each one is installed. When one is missing, stop and report
it with its install command,
`npx skills@latest add toy-crane/skills --skill <name>`, using the project's
package manager runner where it pins one.

The run takes one spec folder, `docs/specs/<slug>/`, to a merged pull request
and a cleaned-up branch, then reports. Deployment after the merge belongs to
the repository's CI/CD; never run a release or deploy command yourself.

## Take exactly one spec folder

- With no spec folder, do not start. Say that unattended work starts from a
  settled spec and that `shape-idea` writes one from the problem and
  direction.
- With several folders, ask which one to run, and run only that one. Each
  folder was split for a reason, such as a separate review or an outside wait,
  that chaining them would skip. Unrelated folders run in separate sessions.

## Authority

The user's invocation of this skill is the authority for the run. It covers:

- merging the pull request once it meets the repository's merge conditions;
- `--force-with-lease` pushes to this run's own work branch;
- the means verification needs, such as running the app, a browser, or a
  simulator. This invocation answers a repository instruction that says to
  ask before using such means; a repository instruction about how to verify
  still applies as written.

It does not cover the following. For each, ask and wait for the answer:

- no way can be found to prove the change;
- a merge condition the agent cannot meet itself;
- deleting data, changing a production environment, or changing anything
  outside this repository;
- closing another pull request, or force-pushing any other branch;
- a spec edit that changes its approved meaning;
- an ambiguity whose readings lead to different results.

Never work around a tool's or system's approval prompt.

## Ask first, while the user is still here

Before any source change, settle everything a person can answer now, and put
every question to the user in one go:

1. Run `babysit-specs` on this folder alone. It hands back the folder brought
   in line with what shipped since the spec was written, plus any question
   about a point whose fix would change the approved meaning. Ask those now.
2. Read the spec's `## Setup before implementation` section. Do what you can
   yourself; name every item still left for a person, with its done condition.
3. When the repository's `AGENTS.md` or `CLAUDE.md` carries an
   `## Issue tracker` section, claim this folder's issue as that convention
   says. Tell `implement` that this run holds the claim; this invocation is
   the user's explicit request to resume that issue.

Start implementing only once these are settled. An unanswered question here
ends the run before any source change.

## Run unattended

Invoke `implement` with the folder and the signal **no person is present**.
It hands back either a blocker, or a ready-for-review pull request with the
end state of `babysit-pr`: ready, or needs a person. On ready, invoke `merge`
on that pull request with the same signal. It hands back the verified merge
and the cleanup result, or the reason it left the pull request open. On a
blocker, needs a person, or a pull request `merge` left open, ask as below and
do not merge.

When the spec and reality part ways during the run, make the correction that
keeps the approved meaning, record it as a decision taken for the user, and
continue. When the correction would change the meaning, ask and stop.

Never end a turn while waiting. Wait for CI or reviews only through something
that wakes you when they change, such as a blocking wait or a background
watcher the harness reports back on, and never stop in a waiting state with
nothing to wake you.

## Asking and notifying

Ask through the harness's question tool, such as `AskUserQuestion` in Claude
Code, never as plain chat text the user may not see. Each question carries the
pull request link when one exists, why the run is blocked, the options, and
your recommendation. When there is no question tool, or no answer comes, do
not merge: leave the pull request open, and make the question the first line
of your final message.

When a push notification tool is available, send one notification when the
run finishes and one when it blocks. Without one, send nothing.

## Final report

On a merge: the pull request link, the merge commit, the evidence for each
acceptance criterion, every decision taken on the user's behalf, and the
cleanup result. On a stop: where the run stopped, the pull request link if
one is open, and the exact decision needed.
