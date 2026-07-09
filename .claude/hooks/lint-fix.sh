#!/bin/bash
# PostToolUse hook (Write|Edit): ESLint auto-fix
# exit 0 = continue, exit 2 = claude sees stderr and retries, exit 1 = hard failure

set -eo pipefail

FILE_PATH=$(jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

if [[ ! "$FILE_PATH" =~ \.(js|jsx|ts|tsx|mjs)$ ]]; then
  exit 0
fi

[ ! -f "$FILE_PATH" ] && exit 0

RESULT=$(bunx eslint --fix "$FILE_PATH" 2>&1)
ESLINT_EXIT=$?

if [ $ESLINT_EXIT -eq 0 ]; then
  exit 0
elif [ $ESLINT_EXIT -eq 1 ]; then
  echo "$RESULT" | head -30 >&2
  exit 2
else
  echo "$RESULT" | head -30 >&2
  exit 1
fi
