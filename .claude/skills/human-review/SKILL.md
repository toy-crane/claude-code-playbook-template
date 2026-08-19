---
name: human-review
description: Turn a completed repository change into a minimal visual handoff for human judgment. Use when the user explicitly asks to inspect the actual outcome of substantial or consequential AI-authored repository work and decide how to handle unresolved product commitments or material consequences, including requests for a visual review when the whole diff is unreasonable to inspect. Summarize the outcome, show observed results, isolate consequential human decisions, and keep evidence on demand. Do not use for a change summary alone, automatic post-implementation review, a small ordinary diff, defect hunting alone, or non-repository content.
---

# Human Review

Protect human attention. Use automated evidence for mechanically checkable
correctness; ask the human only about unresolved commitments or material
consequences that require product intent, local context, or explicit risk
acceptance.

## Establish trustworthy coverage

Read the request, repository instructions, current diff or named change, and any
relevant specs or project decisions. Inspect the actual product and rerun the
smallest checks needed to support each claim. Treat prior summaries as claims,
never as proof. Review the completed work without fixing or broadening it.

Before compressing, account for every changed product behavior, access or data
boundary, external contract, and failure or recovery path. Include material
implementation choices or consequences that the request and project decisions
leave open; treat them as unresolved rather than settled. Give each commitment a
review disposition—summary, human question, or mechanical issue—and an evidence
status—observed, inferred, or unverified. Keep this coverage note behind the
evidence path, but surface any release blocker or material unverified limit in
the overview. This check exists because compression can otherwise make an
omitted change invisible.

Use results observed from the named change in a real runnable environment. Keep
the change reference, route or command, and environment with the evidence. Never
redraw an intended UI or manufacture representative output and label it observed;
when the result cannot be captured safely, mark it unverified.

Redact secrets and personal data without hiding the behavior under review. Never
rerun a destructive production action merely to create evidence.

## Find the human judgment

Reason from commitments, not files or technical layers. Create a human question
only when the answer is unresolved and would change implementation or release,
or when an owner must supply product intent or local context or explicitly accept
a material consequence or release risk. Reserve explicit acceptance for
consequences that are costly if wrong, difficult to reverse, or whose
acceptability cannot be decided by factual verification alone. Missing evidence
alone is not a human question.

Demonstrate commitments whose intent and relevant consequences the request or
current project decisions explicitly settle without asking for approval again.
Treat a material consequence left open or newly exposed by the implementation as
unresolved. Keep routine defects, style, and internal refactors with demonstrated
equivalence out of the human queue. Report confirmed defects as mechanical
issues and expose blockers in the overview; do not turn them into approval
questions.

Present zero to three active independent questions in the current review set,
ordered by cost of error, reversibility, and limits of direct evidence. Name
every deferred commitment and bring it forward as earlier questions are
resolved. Do not bundle independent commitments or use model confidence as
evidence.

## Build the review surface

Copy [assets/review.html](./assets/review.html) to a temporary location outside
the repository and follow the presentation contract embedded there. Leave
product source unchanged, keep the artifact free of network dependencies, and do
not commit it.

Render the finished artifact in a browser. Exercise every review-surface route,
disclosure, comparison or replay, and relevant narrow viewport before presenting
it. Run the finished HTML using a method supported by the current harness and
share an address the user can open. Return one preview image when the host
supports it. If no browser path works, report the surface as an unverified draft.
Browser verification is a completion gate for the surface, not the underlying
change. Preserve every product blocker and unverified result after the surface
passes.

## Keep ownership human

Open on the overview, then focus the conversation on the first active unresolved
question. Treat a question as resolved only after the user states a choice in the
conversation. Restate the choice and its consequence, then move to the next
unresolved commitment and bring deferred commitments forward. When none remains,
say what closed each question: governing decisions, direct evidence, or an
explicit human choice. Do not treat silence, navigation, or an AI recommendation
as approval.

Keep the temporary surface non-authoritative. When a choice must constrain future
work, identify the need for canonical preservation and write it only through the
repository's established decision process and authorization.
