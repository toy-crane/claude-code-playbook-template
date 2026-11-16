---
name: shape-idea
description: Turn a chosen problem and broad direction into shared decisions and an implementation-ready spec. Use when the user wants to clarify behavior or scope, stress-test an idea, align before implementation, or produce a spec.
---

# Shape Idea

This skill requires `project-knowledge`, `add-stack-context`,
`explain-visually`, and `build-prototype`. Before the first question, confirm
each one is installed. When one is missing, stop and report it with its
install command, `npx skills@latest add toy-crane/skills --skill <name>`,
using the project's package manager runner where it pins one.

## Keep alignment separate from delivery

Shaping settles decisions; implementation applies them. Do not change product
source, configuration, or dependencies, even for an edit you plan to revert. A
changed line mixes alignment with delivery and leaves unreviewed code behind.

Write only to spec folders, the glossary, decision contracts, the root
`DESIGN.md` and its read route that recording a screen decision updates, and
vendor agent context. Run every experiment, benchmark, and preview in a scratch directory
outside the working tree. If no experiment can answer a question, record an
assumption and its risk. If code contradicts the user or a decision, surface the
conflict; do not fix the code.

Check the working tree when you start and again before writing `spec.md`.
Revert what this session changed outside the allowed paths and keep only what
you learned. Leave uncommitted work that predates the session alone.

## Ground decisions in project truth

Before the first question, invoke `project-knowledge` with the problem and
direction being shaped and the terms and choices they touch; it hands back
the confirmed definitions of those terms, the decision contracts that apply,
and the path of each `GLOSSARY.md` entry or `docs/decisions/<subject>.md`
file it writes. Apply those throughout the session, and route each term that
gets resolved and each decision that settles during shaping back through it
the same way.

Read root `PRODUCT.md` when it exists before settling the work unit. Treat it as
the current app-level premise, use only the product constraints relevant to the
selected work, and surface any mismatch that would require changing that
premise. Do not create, edit, or copy the whole file into the work-unit spec.
Missing `PRODUCT.md` does not block shaping.

Resolve what available evidence can answer before asking the user.

Ground any conclusion about a third-party package or tool in evidence of how it
actually behaves — its own source, documentation, releases, and maintainer
statements — and confirm it against this project's versions in a scratch copy
before building on it or working around it. Record what was checked, what fell
short, and the upstream change that would reopen the decision.

When a decision selects a framework or hosted service, invoke
`add-stack-context` with that one technology, the decision that selected it,
and the project evidence behind it, so it audits only that technology rather
than the whole stack. It owns discovery, source acceptance, installation, and
live vendor-document routing for it, and hands back the technology's
accounting outcome together with the paths of the skills it installed and the
agent-instruction lines it added or changed; shaping resumes once that is in
hand and records the outcome in the spec.

## Present one decision at a time

Present a concrete candidate for the user to correct, using the lightest medium
that makes the decision judgeable.

- Decide an inexpensive, reversible choice when a mismatch is unlikely or easy
  to detect; state it as an overridable assumption, never a project decision
  contract.
- For a branch expensive to get wrong, ask exactly one question about one fact,
  value, or choice. Include a recommended answer and concise reason, then wait.
- If a proposed decision depends on information only the user can know, state
  that information and ask whether it applies. Verify any condition you can
  check yourself.
- For a choice judged by looking or trying, inspect the current surface as
  evidence and show it only when the decision requires a baseline comparison.
  Render a candidate or two or three controlled variants, verify the relevant
  states, and wait for the user's reaction. Invoke `build-prototype` for a
  whole-surface review or a temporary comparison for the user's specific
  situation. Scope that decision layer independently of product screen count:
  pass only the question and context needed to judge it, integrate
  the chosen result into the existing prototype when present, discard the
  comparison, and resume shaping. If no sufficient renderer is available, defer
  the decision and record the resulting risk.
- When a flow, state model, or relationship has multiple branches, transitions,
  or links, render one diagram before a downstream decision. Ask at most one
  question about its unresolved part and wait. Keep a linear structure that fits
  in one sentence in prose.
- When the user asks for an explanation rather than a decision, invoke
  `explain-visually` with the question and the sources it concerns; it hands
  back the rendered explanation, after which shaping resumes.

A choice is settled when the user confirms it or it is made under authority the
user explicitly delegated for that class of decision. It becomes a project
decision contract only when future work should reuse it, its rationale prevents
reasonable re-litigation, and it came from a real trade-off; feature-local
choices stay in the spec.

Skip review only for an already confirmed pattern, routine presentation details,
or explicit user delegation. Record the reason and treat only agent-judged
reasons as assumptions.

## Write the product contract

Stop asking questions when every implementation-relevant decision is resolved
or explicitly deferred; do not wait for the user to declare completion.
Translate confirmed product-change requests into required behavior. Keep cheap
agent-chosen defaults as overridable assumptions; ask about or explicitly defer
consequential unsettled behavior and record its possible impact as a remaining
risk. Never record a deferred branch as a settled constraint. Interim behavior
the product needs while it stays open is written under the deferred point,
naming the decision that replaces it; where the contract states that behavior
again so it can be built and tested, mark it interim there too.

Give each deferred point the one thing that brings it back, because a point
nothing reopens is forgotten: a date, a condition on the result of other work,
or an issue in the repository's tracker. When that condition is a post-release
check falling short, write the follow-on work as that check's miss action
instead of a separate deferred point. When the point needs an issue and the
user gave no issue ID for it, leave it unlinked in the spec and list it in the
close-out as an issue to file; never create one while shaping.

When ready for implementation, write `docs/specs/<slug>/spec.md` as the stable
product contract, creating the kebab-case folder when needed. Include the
user-visible outcomes, approved scope, observable acceptance criteria, settled
constraints and rationale, assumptions, off-limits areas and why, deferred
points, remaining risks, setup before implementation, and the post-release
check. Record behavior and
decisions without predicting files, functions, code structure, technical
layers, or implementation steps. Carry only applicable app-level constraints
from `PRODUCT.md`; keep the file as their canonical product context rather than
duplicating its full contents. Write an acceptance criterion about the quality
of LLM output that varies run to run, including a skill's or agent's behavior,
as a metric, a target on held-out cases, and where the cases come from, so
implementation proves it with an eval and cannot lower the bar.

When this work depends on another spec folder finishing first, add a
`Blocked by: docs/specs/<other>/` line beside the linked sources, one per
folder, with that exact English label whatever language the spec uses. It is
repository information that later coordination reads, so write it whether or
not an issue tracker is set up.

Always write a `## Setup before implementation` section under that exact
English heading. List each piece of work outside the repository that
implementation needs, such as a vendor account, an issued key, or a console or
DNS setting, on one line: what is needed, the outcome it serves, and a done
condition observable without the work this spec delivers, such as console
state, a direct API call made outside the app, or a DNS lookup. Write `None.`
when nothing is needed, and never write a secret value. Leave who does each
item and how to implementation, and do none of it while shaping.

Always write a `## Post-release check` section under that exact English
heading. It holds what can only be judged once real use has run for a while,
such as a rate in production data, and a later session reads it without this
conversation to schedule and run each check. A check belongs here only when
the user set a success measure that waits on real use, or a decision was
deferred until real-use data arrives; behavior the acceptance criteria can
verify before release is not a check, and you add none on your own. Give each check five fields on
their own lines: the metric, the pass criterion, the period as a number of
days after release, the measurement as a file path inside this spec folder,
and what to do when the criterion is not met. The measurement is a file anyone
can run and get the same value, and it reports pass or fail against the
criterion itself, so whoever runs it never copies or compares numbers by hand.
Say what it reads and what it prints; implementation writes the file with the
rest of the spec. Write `None.` when nothing needs checking after release.

When the repository's `AGENTS.md` or `CLAUDE.md` carries an `## Issue tracker`
section and the user names an existing issue this work comes from, add an
`Issue: <tracker>:<id>` line beside the linked sources in the ID form its
convention records. Write it only from an ID the user gave; never search the
tracker by title to find one, and never create an issue while shaping. Without
the section, or without a known ID, write no such line.

Link the approved `prototype.html` when one exists and each decision contract
this work depends on, so implementation loads them as required sources instead
of judging them optional. Preserve a link an earlier `build-prototype` close-out
already wrote. Say what each linked source governs here, and leave its own
rules, thresholds, and screen compositions in that source instead of copying
them back into a constraint the spec states; keep the links beside the
contract's fields rather than turning them into one.

## Divide the change into spec folders

Before writing, decide how many spec folders the shaped change needs. Most
changes are one folder. Each folder costs its own implementation run, review,
and pull request, so divide only where this rule asks for it.

A folder holds an outcome that could land on the default branch and stay there
even if the rest never arrives. Preparation useful only to a later outcome, or
a part that would regress current behavior on its own, joins the folder of the
outcome that first needs it. Outcomes that pass that test still share one
folder unless one of these separates them:

- one is wanted earlier than the rest;
- a wait outside the repository, such as a legal review or a store release,
  stands between them;
- a later outcome builds on a foundation that needs its own review before a
  defect compounds through it, because the foundation carries a material risk
  that tests cannot settle, such as security, permissions, a data migration,
  or an external contract;
- they are unrelated changes with no reason to share a pull request.

Each reason must be a fact of this change that the user stated or the
repository shows. Dependence alone is not one: an outcome that needs an
earlier one usually shares its folder, and the general value of smaller
reviews never separates outcomes. A risk you infer from the kind of work, such
as authentication or a call to an outside provider, is not a stated fact. A
server, API, or data layer that only the rest of this change uses is a
technical layer, not an outcome that lands alone.

Operations or states inside one workflow, technical layers, and session size
never divide a folder. Work done only outside the repository never becomes a
folder: preparation goes under `Setup before implementation` of the folder
that needs it, and actions after release stay in the `Post-release check` of
the outcome they follow.

When the rule yields more than one folder, show the whole division at once
before writing anything: each folder's slug, the outcomes it delivers, why it
stands apart, and the folders it waits on. Write the folders only after the
user approves that division; one folder needs no separate approval. Give the
folders a shared slug prefix so they read as one group. Make each folder a
complete product contract and restate in it the shared constraints it needs,
because implementation reads one folder at a time. A folder that must wait for
another of them carries a `Blocked by:` line for each folder it waits on.

## Make the shaped change judgeable

Close by summarizing the complete product contract and making the approved
product change understandable and judgeable from the user's point of view. The
user should not need to inspect the spec or ask separately what the resulting
experience will look like.

Choose the explanation and approved visual evidence that best reveal the
intended change and its important downstream consequences. Give particular
attention to consequences that are easy to miss when reviewing only the
surface being changed.

List the setup items from the spec in the close-out so the user can finish
them before implementation starts. List each post-release check with its
period, and each deferred point waiting for an issue the user has not given,
under "issues to file" with a title and what should bring it back. When you
wrote several folders, list them with the order their `Blocked by:` lines set.

Distinguish the intended experience from implemented evidence, keep the
close-out consistent with the product contract, and do not prompt for another
action.
