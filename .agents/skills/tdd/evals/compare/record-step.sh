#!/usr/bin/env bash
# PostToolUse hook for comparison runs: record-step.sh <log>
# Logs every file edit and, whenever the agent runs the tests, the full TAP
# result of the suite at that moment, however the agent filtered its own output.
task_log=$1
task_input=$(cat)
task_tool=$(jq -r '.tool_name // empty' <<<"$task_input")
task_command=$(jq -r '.tool_input.command // empty' <<<"$task_input")
task_file=$(jq -r '.tool_input.file_path // empty' <<<"$task_input")
task_cwd=$(jq -r '.cwd // empty' <<<"$task_input")

if [ "$task_tool" = Bash ] \
  && grep -qE 'node[^|;&]*(--test|\.test\.[cm]?js)|npm +(run +)?test|npm +t( |$)|npx +[^|;&]*test' <<<"$task_command"; then
  {
    printf '=== test-run\n'
    (cd "$task_cwd" && node --test --test-reporter=tap 2>&1)
  } >> "$task_log"
elif [ -n "$task_file" ]; then
  printf '=== edit %s\n' "$task_file" >> "$task_log"
fi
exit 0
