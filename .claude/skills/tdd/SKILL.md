---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions TDD or "red-green-refactor", asks for tests that prove a behavior, wants a bug reproduced as a failing test, or wants integration tests. Not for only running an existing test suite.
---

# Test-Driven Development

Write each new behavior's test before that behavior exists and see it fail
first. Several tests may come before one implementation that makes them pass;
work one test at a time only when the user asks for that or for
red-green-refactor.

Read `GLOSSARY.md`, then use `docs/decisions/README.md` to load only the decision
subjects relevant to the behavior under test. If code, spec, and a decision
contract conflict at the decision level, surface the conflict instead of
silently choosing one. Use current terms in test names and public interfaces.

## Start from the behavior

When `implement` hands over work, it names the active outcome, the acceptance
criteria to prove by automated tests, the approved references that apply to
it, and the spec as design context. Build only that outcome; the spec does not
authorize later outcomes. Invoked on its own,
derive the expected behavior from the user's request, and for a bug, from the
reported wrong behavior.

Design from the whole outcome before writing code. Write no code that no
criterion or named reason below requires.

## Choose what to test

Every handed acceptance criterion gets a test. Any further test names what it
protects: a reproduced bug, a risk in logic the criteria do not reach, or
existing behavior the change touches. Do not write a test that can name none of
these. A handed criterion that no automated test can prove goes back with the
reason. A criterion about the quality of LLM output that varies run to run is
one of these: a test against a mocked model call proves only the code around
the model, so test that code and hand the criterion back.

## Seams

A **seam** is the public boundary where a test observes behavior without
reaching into internals.

Reuse an existing seam before creating one. Create a seam only for a stable use
case or domain concept, not an implementation helper whose name may change.
Select seams from the agreed behavior and existing public interfaces,
prioritizing critical paths and complex logic.

Resolve technical uncertainty through repository evidence. Ask the user
only when the expected behavior remains unclear or proceeding would
change the agreed product contract.

## See every test fail for the right reason

- **New behavior**: write the test before the behavior. Stub any missing name
  so the test runs, then see it fail on an assertion that shows the wrong or
  missing behavior. A compile error, a missing symbol, or a failed import is
  not that failure.
- **Bug fix**: write the reproduction first and see it fail against the
  existing code on the wrong behavior, before changing that code.
- **Existing behavior**: see the guard fail by breaking the implementation or
  by running it against the unfixed code.

Keep the observed failing assertion output, expected against actual, for the
hand-back.

## Keep failing tests honest

Make a failing test pass by changing the implementation. Never delete, skip,
or weaken a test to reach green. To change a test after it has run against the
implementation, cite the line of the approved contract or the user's request
that shows the test was wrong.

Before finishing, find and run the existing tests that cover code the change
touches.

## Good tests

Test behavior through public interfaces so internal refactoring does not break
tests. Use specification-style names that state the capability under test.

Mock only at system boundaries such as external APIs, time, and randomness;
prefer a real test database over a mocked one.

- **Implementation-coupled** tests mock internal collaborators, test private
  methods, or verify through a side channel. They break when implementation
  changes but behavior does not.
- **Tautological** tests derive the expected value the way the code does, or
  copy it from running the code, so they pass by construction. Take expected
  values from an independent source such as a known literal, a worked example,
  or the spec.

## Refactor and hand back

Refactor only while the tests stay green. This skill opens no review of its
own: reviewing the finished diff belongs to whatever workflow owns it, or to a
review the user runs.

Hand back:

- the code change;
- one line per new test: its name, the criterion or named reason it serves,
  and an excerpt of the failing assertion it was seen to produce;
- each handed criterion no automated test could prove, with the reason.
