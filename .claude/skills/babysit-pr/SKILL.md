---
name: babysit-pr
description: Watch one open GitHub pull request through CI and review bots until it is ready to merge or needs a person, fixing confirmed findings and failing checks, answering and resolving review threads, and rerunning infrastructure flakes. Use when a pull request has just been opened or updated and its checks, bot review comments, or merge conflicts need answering, or when asked to babysit, watch, shepherd, or get a PR green or ready. Does not merge; `merge` and `implement` invoke it before merging or handing off.
---

# Babysit a pull request

Take one open pull request and carry it to one of two end states, then stop.

- **Ready**: every required check passed on the current head, every review
  GitHub requires has seen the current head, no review thread is unresolved,
  and GitHub reports the pull request mergeable.
- **Needs a person**: something the agent cannot settle itself, such as a
  check failure it cannot fix, a person's review requesting changes, a
  conflict whose intended result is unclear, or 30 minutes with no event.

Merging is outside this skill. The request to babysit authorizes commits that
answer the pull request's checks and findings, pushes of them to its branch,
replies and thread resolutions on it, and reruns of its checks. Rewrite
history only on this pull request's branch, with `--force-with-lease` against
the remote state just observed, when a rebase onto the base is needed.

## Read the whole state on every pass

Each pass starts from the pull request as it is now: its head, base,
mergeability, required checks and their results on the current head, required
reviews and which commit each reviewed, unresolved review threads, and new
comments and reviews. Find what is required from branch protection or
rulesets, not from which checks happen to run. Results and reviews of an
earlier head do not count. Every unresolved review thread is open work,
whenever it was posted.

A person's comment or review comes first, whenever it was posted: finish it,
commit, push, and reply, before you open any bot thread. A person's request for
changes ends the run as needs a person unless the request is clear and in
scope, in which case answer it like a confirmed finding and leave its
approval to that person.

## Answer checks

Read a failing check's logs before acting. Separate a failure the repository
caused from an infrastructure flake, such as a runner that lost its
connection, a registry timeout, or a rate limit: rerun a flake and change no
code for it. Fix a repository failure when the cause and the intended fix are
clear from the change's purpose; otherwise end as needs a person with the
failing step and log excerpt. When GitHub reports a conflict with the base,
rebase onto the fetched base and resolve it when the intended result is clear
from both sides, verify, and push with the lease above; otherwise end as needs
a person with the conflicting files. Treat a check GitHub does not require as
information: report it, and never wait for it.

## Answer review findings

Check each bot finding against the current source before acting on it. Fix it
only when it describes a real bug on the path the change is meant to serve.
Decline, with the reason, a finding about another path, a rare case, a small
performance difference, or tests and defensive code the change did not intend,
so answering review does not grow the pull request. Verify a fix the way the
change was verified, commit it as a Conventional Commit, and push it.

Reply on every thread you act on. A fixed finding's reply says what changed
and where. A declined finding's reply gives the evidence: `file:line`, a test,
or command output. Resolve the thread only after its reply has posted. Wait
only for bots GitHub requires; when a required review bot has not reviewed
the current head, request it once in the way it accepts, such as a
`@codex review` comment for Codex.

Every comment posted on the user's behalf starts with a GitHub note block
saying an agent wrote it for them, using their GitHub login and no model
name. Write the login without `@`, so the note does not notify them on every
comment:

```markdown
> [!NOTE]
> 🤖 에이전트가 <login> 대신 답함
```

Before posting, check the text for secrets, credentials, and personal data.

## Wait for the next event

Between passes, wait with the bundled
[`scripts/pr-events.mjs`](scripts/pr-events.mjs). Run `mark <pr>` before the
first pass reads the state, so nothing posted during that pass is missed. Then
run `wait <pr>` in the background, or wherever the harness wakes you when a
command ends. It returns when a check completes, a commit lands, a review,
thread, or comment appears or changes, mergeability changes, or the pull
request closes, and records that state, so a restarted run or a new session
still sees events that arrived while nothing waited. Its exit codes:

| Code | Meaning | Next |
| ---- | ------- | ---- |
| 0 | `changed`, with the changes | run a pass |
| 10 | `idle`: 30 minutes since the last change | end as needs a person |
| 11 | `retry`: its `--max-minutes` ran out | run `wait` again |
| 3 | `busy`: another wait holds this PR | stop your own earlier wait, or leave the PR to the session that owns it |

Keep one wait per pull request. Your own pushes and replies wake the next
wait; that pass finds nothing to do. When a pass has nothing to do, start the
next wait without a message or comment: no progress reports, no "still
waiting".

## When no person is present

When the invoking skill says no person is present, ask the user anything
through the harness's question tool, not as chat text. When no answer comes,
end as needs a person with that question, and never merge. Without that
signal, everything here applies as written.

## Finish

End with the state, ready or needs a person, and the pull request URL; what
was fixed, with commits; what was declined, with reasons; check reruns; and
for needs a person, exactly what is waiting and on whom.
