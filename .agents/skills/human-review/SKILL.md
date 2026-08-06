---
name: human-review
description: Turn a completed repository change into a minimal visual handoff for human judgment. Summarize the outcome, isolate consequential commitments that are costly if wrong, hard to reverse, or hard to verify automatically, show actual results, and keep evidence on demand. Use after substantial or consequential AI-authored code, UI, API, database, or infrastructure work when the user asks what changed, wants a visual review, or cannot reasonably inspect the whole diff. Do not use for a small ordinary diff, defect hunting alone, or non-repository content.
---

# Human Review

Protect human attention. Let automated review handle mechanically checkable
correctness; ask the human to accept or reject the consequential promises the
change introduces.

## Establish trustworthy coverage

Read the request, repository instructions, current diff or named change, and any
relevant specs or project decisions. Inspect the actual product and rerun the
smallest checks needed to support each claim. Treat prior summaries as claims,
never as proof. Review the completed work without fixing or broadening it.

Before compressing, account for every changed product behavior, access or data
boundary, external contract, and failure or recovery path. Give each one a
disposition: summary, human question, mechanical issue, or unverified. Keep this
coverage note behind the evidence path, but surface any release blocker or
material unverified limit in the overview. This check exists because compression
can otherwise make an omitted change invisible.

Use results observed from the named change in a real runnable environment. Keep
the change reference, route or command, and environment with the evidence. Never
redraw an intended UI or manufacture representative output and label it observed;
when the result cannot be captured safely, mark it unverified.

Redact secrets and personal data without hiding the behavior under review. Never
rerun a destructive production action merely to create evidence.

## Find the human judgment

Reason from commitments, not files or technical layers. Create a human question
only when the answer is unresolved and would change the implementation, or when
an owner must explicitly accept a consequence that is costly if wrong, difficult
to reverse, or not decidable by automated evidence.

Demonstrate commitments already settled by the request or current project
decisions without asking for approval again, unless their observed consequence
still requires explicit risk acceptance. Keep routine defects, style, and
internal refactors with demonstrated equivalence out of the human queue. Report
confirmed defects as mechanical issues and expose blockers in the overview; do
not turn them into approval questions.

Present zero to three independent questions, ordered by cost of error,
reversibility, and limits of direct evidence. If more remain, name the remaining
commitments instead of hiding them behind an anonymous count. Do not use model
confidence as evidence.

## Build the review surface

Copy [assets/review.html](./assets/review.html) to a temporary location outside
the repository and follow the presentation contract embedded there. Leave
product source unchanged, keep the artifact free of network dependencies, and do
not commit it.

Render the finished artifact in a browser. Exercise every route, disclosure,
comparison or replay, and relevant narrow viewport before presenting it. Return
a direct link and one preview image when the host supports them. If local-file
navigation is blocked, serve the temporary directory on loopback or use an
available headless browser; if no browser path works, report the surface as
an unverified draft. Browser verification is a completion gate: do not call the
review complete or ready until it passes.

## Keep ownership human

Open on the overview, then focus the conversation on the first unresolved
question. When none remains, say why the evidence closed the queue. Do not treat
silence, navigation, or an AI recommendation as approval. Record a human choice
only after the user states it in the conversation. The temporary surface is not
a project decision record.
