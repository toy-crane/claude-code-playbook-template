---
name: push
description: Publish local Git commits on a named branch without losing local or remote work. Always use this skill for an actual Git branch publication, including requests to push, publish, upload, or put the current or detached checkout on origin or another Git remote. Use it for detached-HEAD publication and post-rebase lease-protected updates; it pushes existing commits only and does not commit dirty changes, create a PR, or merge.
---

# Push branch

Publish the current branch's commits while leaving uncommitted changes local.
Report dirty changes as not included rather than turning a push request into a
commit request.

Publish a named working branch. When the checkout is detached, derive a concise
branch name from the change. Treat a protected default branch as requiring
explicit authorization rather than a routine push target.

Reconcile the current remote branch before updating it so another contributor's
work is preserved. When an intentional rebase changed already-published
history, use a lease-protected update only against the remote state just
observed; never overwrite an unexpectedly changed remote.

Finish when the remote branch points at the intended local commit, upstream
tracking is usable for later work, and the user knows the branch and remote
result. Keep every uncommitted or unrelated change untouched.
