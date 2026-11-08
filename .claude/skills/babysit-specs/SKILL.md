---
name: babysit-specs
description: Revise active `docs/specs/SLUG/` specs so they match what has shipped since they were written. Use when earlier work has landed and queued specs may now rest on stale assumptions, acceptance criteria, constraints, terms, or prototypes, or when implementation reports a spec as stale before changing source. Takes one or more spec folders, or every folder under `docs/specs/` when none is named. Do not use to shape a new spec from a problem and direction, which belongs to `shape-idea`, or to reconcile durable project context and retire shipped folders, which belongs to `maintain-project-context`.
---

# Babysit Specs

This skill requires `project-knowledge` and `build-prototype`. Before doing
any work, confirm each one is installed. When one is missing, stop and report
it with its install command,
`npx skills@latest add toy-crane/skills --skill <name>`, using the project's
package manager runner where it pins one.

## Select the specs and establish the baseline

Take the spec folders the user names. With none named, take every folder
present under `docs/specs/`. Handle one spec at a time.

For each spec, read `spec.md`, the prototype and decision contracts the spec
links, and `GLOSSARY.md` when it exists, since a
term the shipped work renamed now lives there.

The baseline is that spec's last commit, including a previous revision of your
own. Establish what changed since it from the repository's Git history and from
the current behavior of the surfaces the spec names. A sibling spec folder that
has disappeared since the baseline has shipped. When a spec was never
committed, compare against the current state alone and say so in the report.
When a spec has uncommitted edits, compare from its last committed version and
say so.

## Compare the contract with current truth

Check every field of the product contract against what you established, and
list only the points that no longer hold:

- an assumption the shipped work made false;
- an acceptance criterion the shipped work already satisfies;
- a settled constraint the current code contradicts;
- a term, pattern, or path the shipped work introduced that this spec should
  now use;
- an off-limits area the shipped work entered;
- a deferred point the shipped work settled;
- a linked prototype that no longer matches the current surface.

Compare the prototype as screens, not as code. Render the linked
`prototype.html` and compare its screens and states with the current product
surface, running the product when the repository exposes it. When no runnable
surface exists, compare against the current code and design system files
instead and record in the report that the comparison was weaker.

Resolve what the repository can answer before asking the user. Leave decisions
the shipped work does not touch closed.

## Triage each point by meaning

A point whose correction preserves what the user approved is yours to fix.
Update it in place, mark it as an agent-chosen assumption the user can
override, and give its reason in the report. A renamed term, a criterion
another work unit already delivered, a moved path, and a link pointing at a
retired folder are examples: the product the user gets does not change, even
though approved text does.

A point whose correction would change what the user approved belongs to the
user. Ask one question about it, include a recommended answer and a concise
reason, and wait. Ask one question at a time however many specs are in scope,
rather than collecting them into a list. An outcome the shipped work makes
redundant or impossible, a design its new pattern contradicts, a constraint
its code breaks where the break may have been intentional, and an entered
off-limits area are examples.

The axis is whether the approved meaning survives, not whether the edit is
cheap. A choice is settled only when the user confirms it or it is made under
authority the user explicitly delegated for that class of decision. Your own
correction is an assumption under standing veto, never a settled constraint.

## Write the revision

Rewrite `spec.md` in place under the same slug. Keep the product contract's own
fields: user-visible outcomes, approved scope, observable acceptance criteria,
settled constraints and rationale, assumptions, off-limits areas and why,
deferred points, remaining risks, and setup before implementation. Preserve its
links to the approved prototype and to the decision contracts the work depends
on, pointing at each rather than restating it. Where a deferred point's interim
behavior is stated again elsewhere in the contract, keep it marked interim
there.

Add no change log section and no revision file; Git holds the history. Never
edit product source, configuration, or dependencies, and run any experiment in
a scratch directory outside the working tree. Record a settled outcome that
future work should reuse through `project-knowledge`, handing it the decision,
its rationale, and the rejected alternatives, and link the
`docs/decisions/<subject>.md` path it reports from the spec.

## Hand off what you do not own

- A folder whose revised outcomes no longer belong together: report it for
  `shape-idea` to re-divide, and do not split or merge folders yourself. A
  folder belongs together when its outcome could land on the default branch
  and stay there even if the rest never arrives, and nothing separates its
  parts. It no longer fits when the revision lets one part land alone while
  that part is wanted earlier than the rest, a wait outside the repository
  such as a legal review or store release now stands between the parts, a
  later part builds on a foundation whose material risk tests cannot settle,
  such as security, permissions, a data migration, or an external contract,
  or the parts became unrelated; or when the folder's outcome can no longer
  land without work held in another folder. Each reason must be a fact the
  shipped work or the user establishes. Dependence between parts, a risk
  inferred from the kind of work, or a technical layer never separates them.
- A drifted prototype: regenerate the affected screens through
  `build-prototype`, handing it the drifted screens and states and the
  current surface they must match; it hands back the updated
  `prototype.html`, which the spec keeps linking.
- A spec whose acceptance criteria all pass against the current repository:
  report it as a retirement candidate. Deleting the folder belongs to
  `maintain-project-context` or the user.

## Report

Finish when every selected spec is either current or waiting on a user
decision. Report, in conversation and without writing a report file:

- what you updated without asking, and why each point preserved the approved
  meaning;
- what you asked and how it settled;
- which specs are retirement candidates;
- which folders await re-dividing and which prototypes await a follow-up
  pass;
- any comparison that was weaker than a rendered or committed one, and why.
