---
name: human-review
description: Help a human understand and inspect completed AI-authored repository work through actual results, before-and-after explanations, and supporting evidence. Use when the user asks to understand the work before accepting it, examine assumptions beyond an AI summary, or resume a human review after switching tasks. Also use for explicit requests to judge unresolved product behavior. Ordinary change summaries, automated defect hunting, and non-repository content do not need this skill.
---

# Human Review

Make the work understandable enough for the human to examine it independently.
Reduce the effort of remembering context, finding evidence, and connecting
changes so the human can spend attention on understanding and judgment.

## Reconnect to the work

Read the request, applicable project decisions, spec when present, current diff,
and available review history. Establish what the work was meant to achieve and
which choices the human actually settled. Code shows what was implemented; it
does not establish that the human intended every consequence.

Open with the purpose, the resulting change, and where to start looking. When
prior review context exists, identify what changed since the revision the human
last examined. Otherwise describe a fresh starting point. Infer familiarity
only from the conversation, adjusting depth as the human asks or reveals gaps.

Before compressing the change, account for each changed behavior, access rule,
data effect, external interaction, and failure path. For each, distinguish what
to explain, what needs a product decision, and any confirmed defect; separately
record what was observed, inferred from source, or remains unverified. This
prevents a concise explanation from silently omitting part of the change. Keep
the complete list accessible and put blockers and consequential unknowns near
the opening.

## Show how the behavior changed

Explain one coherent behavior at a time, connecting its trigger, before/after
result, mechanism, and consequences. Keep its place in the whole change visible
and let the human choose another part, including choices the AI considers
settled. Organize by what happens rather than by file or implementation layer.

Use the smallest representation that makes the relationship easy to inspect:
actual UI captures, request/response values, a short source comparison, an access
table, or a flow diagram. Put the relevant evidence beside the claim or behind
an adjacent disclosure. Explain technical details when they help the human
check how a result follows; keep the deeper source available on demand.

Inspect the actual product and run the smallest safe checks needed to support
the explanation. Tie each observed result to the named revision or dirty diff,
route or command, and environment. Identify supplied observations as supplied
and preserve their provenance. Prior AI summaries are claims, not proof. Label
source-derived conclusions and missing observations accurately; a mock or
proposed screen is never an observed result. Redact secrets and personal data,
and preserve the product while preparing the review.

Write in the human's language using concrete actions and outcomes. Name the
actual question, changed behavior, or place to see the evidence instead of
abstract process labels such as “unresolved commitments,” “review disposition,”
or “evidence path.” Keep necessary technical names and explain unfamiliar ones
in context. Omit time estimates, severity codes, scores, and file/test counts
that do not help examine the behavior.

## Support judgment without substituting for it

Invite examination at consequential assumptions or boundaries, not an
acknowledgment after every explanation. A question should expose a real choice
and what each answer changes. Do not invent a product decision because evidence
is missing, a diff is large, or a confirmed defect needs repair.

Keep at most three unresolved product decisions active and name every deferred
decision so it can follow as earlier ones settle. Start with choices whose
consequences are costly or hard to reverse. This limit applies to
decisions, not to the work the human can inspect. With no open product decision,
still explain the behavior and make its evidence available; say separately
whether defects or missing observations prevent a readiness claim.

Treat a choice as settled only when the human explicitly states it in
conversation. Opening a section, reading, silence, and a general acknowledgment
are not acceptance. Preserve reusable confirmed decisions through the project's
existing decision process; temporary review pages and notes are not that record.

## Leave a usable return point

When review pauses or the human switches tasks, preserve a concise note in the
conversation, or beside a temporary review artifact when a portable handoff is
useful. Include the source revision and any dirty changes, retaining the relevant
diff or snapshot when uncommitted edits are part of that source. Record the parts
actually examined, the human's expressed decisions or questions, what remains open, and
the next useful action. Link the note and its source evidence so another session
can pick it up. Keep observed navigation separate from expressed understanding
and acceptance; if none is known, say so.

On return, compare the current work with the recorded source before reusing
earlier observations. Point out what needs another look and why, preserve
unaffected discussion, and resume at the open question. If the earlier source
cannot be recovered, say which comparison is unavailable rather than claiming
the review is current. Before handing off any review, provide a next starting
point without pretending the human has already examined it.

## Deliver a review the human can use

Keep simple explanations in conversation. When comparison, navigation, or
continued review benefits from HTML, adapt [assets/review.html](assets/review.html)
outside the repository. It provides context, a map of behaviors, before/after
sections, nearby evidence, and an optional return note. Translate labels,
replace placeholders, and remove unused sections; the template is a starting
point, not a compulsory screen for every change.

For HTML, exercise navigation, comparisons, disclosures, and a narrow viewport
in a browser. Fix incomplete content or broken controls before calling the
surface ready. If browser verification is unavailable, state that limitation.
Run the finished HTML using a method supported by the current harness and share
an address the user can open, plus a preview when supported. Keep the server
available for review. Browser verification establishes that the review surface
works, not that the underlying product is correct or approved.

A successful handoff supports explaining the behavior, inspecting an assumption
the AI did not flag, and resuming after a switch. Do not claim improved human
understanding merely because the page renders or the human grants approval.
