#!/usr/bin/env bash
set -euo pipefail

script=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/body-sections.py
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

printf 'Original report\n\nSteps to reproduce.\n' > "$scratch/body.md"
printf 'Facts confirmed.\n' > "$scratch/triage.md"
python3 "$script" upsert --body "$scratch/body.md" --content "$scratch/triage.md" \
  --section triage > "$scratch/updated.md"
grep -Fq 'Original report' "$scratch/updated.md"
grep -Fq 'Facts confirmed.' "$scratch/updated.md"
python3 - "$scratch/body.md" "$scratch/updated.md" <<'PY'
from pathlib import Path
import sys
assert Path(sys.argv[2]).read_bytes().startswith(Path(sys.argv[1]).read_bytes())
PY

printf '\nHuman added new details.\n' >> "$scratch/updated.md"
printf 'Next action: implement.\n' > "$scratch/triage.md"
python3 "$script" upsert --body "$scratch/updated.md" --content "$scratch/triage.md" \
  --section triage > "$scratch/final.md"
grep -Fq 'Human added new details.' "$scratch/final.md"
grep -Fq 'Next action: implement.' "$scratch/final.md"
if grep -Fq 'Facts confirmed.' "$scratch/final.md"; then
  echo 'old AI section survived replacement' >&2
  exit 1
fi

printf '<!-- triage-issues:triage:start -->\nmissing end\n' > "$scratch/broken.md"
if python3 "$script" upsert --body "$scratch/broken.md" --content "$scratch/triage.md" \
  --section triage > "$scratch/should-not-exist.md" 2>/dev/null; then
  echo 'malformed boundary was overwritten' >&2
  exit 1
fi

echo 'body section behavior passed'
