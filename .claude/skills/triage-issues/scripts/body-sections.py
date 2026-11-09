#!/usr/bin/env python3
"""Render one bounded AI-owned section without rewriting human issue content."""

import argparse
import sys
from pathlib import Path


TITLES = {"triage": "Triage 요약", "spec": "Spec"}


def upsert(body: str, section: str, content: str) -> str:
    start = f"<!-- triage-issues:{section}:start -->"
    end = f"<!-- triage-issues:{section}:end -->"
    if start in content or end in content:
        raise ValueError("content contains a managed boundary")
    starts = body.count(start)
    ends = body.count(end)
    if starts != ends or starts > 1:
        raise ValueError("missing or duplicate managed boundary")

    rendered = f"{start}\n## {TITLES[section]}\n\n{content.rstrip()}\n{end}"
    if starts == 0:
        if not body:
            return rendered + "\n"
        separator = "" if body.endswith("\n\n") else "\n" if body.endswith("\n") else "\n\n"
        return body + separator + rendered + "\n"

    left = body.index(start)
    right = body.index(end)
    if right < left:
        raise ValueError("managed boundaries are out of order")
    return body[:left] + rendered + body[right + len(end) :]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["upsert"])
    parser.add_argument("--body", required=True, type=Path)
    parser.add_argument("--content", required=True, type=Path)
    parser.add_argument("--section", required=True, choices=TITLES)
    args = parser.parse_args()
    try:
        body = args.body.read_text(encoding="utf-8")
        content = args.content.read_text(encoding="utf-8")
        sys.stdout.write(upsert(body, args.section, content))
    except (OSError, ValueError) as error:
        print(f"triage body: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
