---
name: commit
description: Create Git commits for the current request's in-scope changes as logical Conventional Commits. Always use this skill for an actual Git commit operation, including requests to commit or amend changes, save work in repository history, stage and record selected files, or group staged or unstaged changes into commits. Use it even when the request describes recording changes without saying "commit"; it performs the commit rather than only suggesting a message, and it does not push.
---

# Commit changes

Commit the changes owned by the current request. Treat explicit invocation as
authorization to create commits, while leaving the remote untouched.

Understand the current status, diff, and recent commit style before staging.
Separate unrelated concerns into commits that can be understood, reverted, or
cherry-picked independently; keep a behavior and the tests that establish it
together when they form one change.

Preserve work outside the request. Leave pre-existing or ambiguously owned
changes unstaged and ask only when their ownership prevents a safe commit.
Exclude credentials, secrets, private keys, and environment files unless the
user explicitly establishes that a particular file is safe and intended for
version control.

Use Conventional Commit messages that describe the actual diff and fit the
repository's history. Honor repository hooks and repair failures caused by the
current change; a failed hook is evidence to address, not a check to bypass.

Finish when every in-scope change is committed, every remaining working-tree
change is accounted for, and the user has the resulting commit hashes and
subjects. If there is nothing to commit, report that state without creating an
empty commit.
