# Running the build-prototype evals

`evals.json` contains independent requests except entries with
`type: "multi_turn"`. Case 21 is a sequential Compare → choice → new Prototype
test. Running only its top-level `prompt` does not execute the case.

For case 21:

1. Copy its input fixture into an empty temporary project, preserving the
   fixture-relative paths (`project.md` at the project root). Keep evaluator
   evidence outside that project. Give an executor the skill path, project
   directory, and top-level prompt; withhold the later turns and expectations.
2. Execute each entry in `turns` in order. Check and snapshot the actual files
   and browser behavior at each checkpoint before sending the next prompt.
   `prompt_source: "prompt"` refers to the top-level prompt.
3. `same_agent` continues the preceding executor. `fresh_agent_files_only`
   starts a new agent with no prior conversation, supplying only the skill
   path, current project directory, and that turn's prompt. Carry forward the
   real files without adding, rewriting, or explaining the decision record.
4. Fail the relevant assertion if the record is missing, the comparison is not
   deleted, a prototype is built early, or the fresh run loses the choice.
   Keep any repair run separate from the first result. Inspect behavior in a
   browser; finding the expected text in HTML is insufficient.
5. Save prompts, checkpoint evidence, browser observations, and per-expectation
   results outside the project. Report one multi-turn run separately from its
   browser assertions and from the rest of the eval suite.

This case tests continuity through project files, including loss of conversation
history. It does not require a particular decision-record filename. The final
prompt deliberately omits the chosen option and its behavior.
