---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

Apply these test-quality rules during each red → green cycle.

Read `GLOSSARY.md`, then use `docs/decisions/README.md` to load only the decision
subjects relevant to the behavior under test. If code, spec, and a decision
contract conflict at the decision level, surface the conflict instead of
silently choosing one. Use current terms in test names and public interfaces.

## Good tests

Test behavior through public interfaces so internal refactoring does not break
tests. Use specification-style names that state the capability under test.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking
guidelines.

## Seams

A **seam** is the public boundary where a test observes behavior without
reaching into internals.

Reuse an existing seam before creating one. Create a seam only for a stable use
case or domain concept, not an implementation helper whose name may change.

Write down the seams under test and confirm them with the user before the first
test. Write no test at an unconfirmed seam. Agreeing the seams directs effort to
critical paths and complex logic instead of trying to test everything.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private
  methods, or verifies through a side channel. It breaks when implementation
  changes but behavior does not.
- **Tautological**: derives the expected value using the same logic as the code,
  so the assertion passes by construction. Use an independent source such as a
  known literal, worked example, or spec.
- **Horizontal slicing**: writes many tests before any implementation. Implement
  one failing test and its minimal code before choosing the next test.

## Loop rules

- **Red before green.** Write the failing test first, then only enough code to
  pass it. Do not anticipate future tests or add speculative features.
- **One slice at a time.** Use one seam, one test, and one minimal implementation
  per cycle.
- **Refactor after green.** Refactor in a separate review stage with the
  code-review tooling available in the current harness.
