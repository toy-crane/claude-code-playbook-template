# Writing feedback behavioral checks

The seam is the invoked skill's response and actual repository files. These
checks require real fresh sessions; matching words in SKILL.md is not a pass.
Use only the synthetic fixtures here, never a user's blog or session history.

For each independent entry in `evals.json`, copy its fixture into a temporary
Git repository, install the selected skill there, and apply `setup.write` and
`setup.remove` when present before invoking the prompt. Run without
`project-knowledge` to exercise standalone preservation. Compare the unchanged
source revision and the candidate on identical inputs. Retain temporary CLI
traces and changed files for inspection. Authentication, permission, API, timeout,
missing-agent, and incomplete-turn failures are invalid runs, not behavioral
failures or empty successes. A successful CLI exit alone is not a passing result.

## Cross-client transfer

1. Start from `fixtures/writing-feedback` with only `draft-piece` installed.
   Run draft eval 3 in Claude. Inspect the actual decision file for capture,
   merged brevity and claim criteria, rationale, scope and confirmation evidence.
2. Start a fresh Codex session in that resulting repository with `define-piece`
   installed. Run define-piece eval 5 without its synthetic `setup` override;
   the only preference evidence must be what Claude actually wrote. Confirm
   the new topic's proposed headings express claims without copying backup facts.
3. Reverse the clients in a new fixture: Codex records via draft eval 3, then a
   fresh Claude plans via define-piece eval 5. Share files only, not the prior
   dialogue or a summary of its preferences.
4. Repeat capture through define-piece eval 4, which must preserve the decision
   before a whole brief is written. Use an unseen topic for the next planning
   or drafting turn rather than tuning only to the fixture's heading.

## Continued correction and verification

From a captured repository, run draft evals 4, 5 and 8 separately on copies to
check exceptions, local replacements and accepted-example maintenance. Run eval
7 after resetting only the article heading to its original topic-only heading;
retain the captured criteria. Its reader questions remain answerable, so the
style violation must be found separately. Run eval 6 with the brief removed.

Also retain the original draft evals: executable commands and fresh-context
reader verification on `blog-monorepo`, and the thesis-change boundary. Preserve
existing define-piece opening and publication write/update controls. Publication
evals 4–6 exercise recommendation, a held-out reaction, and accepted preservation;
follow an actual recommended paragraph with rejection and acceptance turns when
checking conversational continuity. A proposal must remain unsettled until the
user accepts it.

Report inspected outcomes by case and client, with source revision and any
unmet checks. These bounded probes establish exercised behaviors, not a general
writing-quality score or an improvement percentage.
