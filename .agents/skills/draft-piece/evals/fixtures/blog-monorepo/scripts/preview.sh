#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
for f in content/posts/*.md; do
  [ -e "$f" ] || continue
  out="dist/$(basename "${f%.md}").html"
  { printf '<!doctype html><pre>'; cat "$f"; printf '</pre>'; } > "$out"
  printf '%s\n' "$out"
done
