#!/usr/bin/env bash
set -euo pipefail
dir=${1:?usage: tally.sh <folder>}
total=0
while IFS= read -r f; do
  n=$(wc -l < "$f" | tr -d ' ')
  printf '%s\t%s\n' "$n" "$f"
  total=$((total + n))
done < <(find "$dir" -name '*.md' | sort)
printf 'total\t%s\n' "$total"
