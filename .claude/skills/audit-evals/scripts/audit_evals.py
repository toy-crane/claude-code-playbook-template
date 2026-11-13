#!/usr/bin/env python3
"""Count a regression suite's cell history and apply approved demotions.

  audit_evals.py report <cell-history.json> [--json] [--out <file>]
  audit_evals.py apply  <cell-history.json> <unit> [<unit> ...]

Every rule reads a cell's most recent 10 trials. A cell whose recent 10 all
passed is a demotion candidate, even when it failed before them; one with no
failure but fewer than 10 recorded trials is insufficient history; recent
results that mix passes and failures are flipping, and ones that are all
failures are always failing.

A unit is `suite/case/check`, `suite/*/check` (a whole check),
`suite/case/*` (a whole case), or `suite/~/check` (the candidate cells of a
check). Exit codes: 0 done, 2 invalid input or a refused unit, 3 no cell
history at the path.

The history file, version 2:

  {"version": 2, "suites": {"<suite>": {
     "reps": 2, "last_run_model": "<model>", "lower_tier_model": "<model>" | null,
     "checks": {"<check>": {"grader": "code" | "judge", "judge_call": "<id>"}},
     "cells": {"<case>": {"<check>": {"tier": "upper" | "lower",
        "baseline": "pass" | "fail" | null, "trials": 14, "passes": 13,
        "recent": "pppppppppp"}}}}}}

`trials` and `passes` are cumulative. `recent` holds the results of the cell's
most recent trials, oldest first, `p` pass and `f` fail: each new trial is
appended and the oldest dropped once it holds 10, so it holds min(trials, 10).
`judge_call` names the judge call a check is scored in; checks sharing one id
are scored together. Without it a judged check has its own call.
"""
import argparse
import json
import sys
from pathlib import Path

WINDOW = 10


class Invalid(Exception):
    pass


def load(path):
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise Invalid(f"{path}: not JSON ({error})")
    if not isinstance(data, dict) or data.get("version") != 2 or not isinstance(data.get("suites"), dict):
        raise Invalid(f"{path}: expected version 2 with a suites object")
    for suite, body in data["suites"].items():
        if "/" in suite:
            raise Invalid(f"suite name {suite!r} contains '/'")
        if not isinstance(body, dict):
            raise Invalid(f"{suite}: must be an object")
        reps = body.get("reps")
        if not isinstance(reps, int) or reps < 1:
            raise Invalid(f"{suite}: reps must be a positive integer")
        checks = body.get("checks")
        cells = body.get("cells")
        if not isinstance(checks, dict) or not isinstance(cells, dict):
            raise Invalid(f"{suite}: needs checks and cells objects")
        for check, meta in checks.items():
            if "/" in check or not isinstance(meta, dict) or meta.get("grader") not in ("code", "judge"):
                raise Invalid(f"{suite}/{check}: grader must be code or judge")
        for case, row in cells.items():
            if "/" in case or not isinstance(row, dict):
                raise Invalid(f"{suite}/{case}: case names hold no '/' and map checks to cells")
            for check, c in row.items():
                where = f"{suite}/{case}/{check}"
                if check not in checks:
                    raise Invalid(f"{where}: check {check} is missing from {suite}.checks")
                if not isinstance(c, dict) or c.get("tier") not in ("upper", "lower"):
                    raise Invalid(f"{where}: tier must be upper or lower")
                t, p = c.get("trials"), c.get("passes")
                if not (isinstance(t, int) and isinstance(p, int) and 0 <= p <= t):
                    raise Invalid(f"{where}: needs integer trials >= passes >= 0")
                r = c.get("recent")
                if not (isinstance(r, str) and set(r) <= {"p", "f"} and len(r) == min(t, WINDOW)
                        and r.count("p") <= p and r.count("f") <= t - p):
                    raise Invalid(f"{where}: recent must be the last min(trials, {WINDOW}) results as p and f,"
                                  " within the cell's passes and failures")
    return data


def all_cells(data):
    for suite in sorted(data["suites"]):
        body = data["suites"][suite]
        for case in sorted(body["cells"]):
            for check in sorted(body["cells"][case]):
                yield suite, case, check, body["cells"][case][check]


def judge_call(body, check):
    meta = body["checks"][check]
    if meta["grader"] != "judge":
        return None
    return meta.get("judge_call", check)


def savings(data, chosen):
    """Runs and judge calls one upper-tier run no longer makes once `chosen` cells leave it."""
    runs = calls = 0
    for suite, body in data["suites"].items():
        for case, row in body["cells"].items():
            upper = {k for k, c in row.items() if c["tier"] == "upper"}
            if not upper:
                continue
            if all((suite, case, k) in chosen for k in upper):
                runs += body["reps"]
            groups = {}
            for k in upper:
                g = judge_call(body, k)
                if g is not None:
                    groups.setdefault(g, set()).add(k)
            for members in groups.values():
                if all((suite, case, k) in chosen for k in members):
                    calls += body["reps"]
    return runs, calls


def is_candidate(c):
    return c["recent"] == "p" * WINDOW


def failures(c):
    return c["trials"] - c["passes"]


def analyze(data):
    candidates, short, flipping, failing = [], [], [], []
    for suite, case, check, c in all_cells(data):
        cid = (suite, case, check)
        r = c["recent"]
        if is_candidate(c):
            candidates.append(cid)
        elif "f" not in r:
            # No failure yet, but fewer than 10 trials to show it.
            short.append(cid)
        elif "p" not in r:
            failing.append(cid)
        else:
            flipping.append(cid)

    identical = []
    for suite in sorted(data["suites"]):
        body = data["suites"][suite]
        signatures = {}
        for check in sorted(body["checks"]):
            # The recent results case by case; checks that never failed in it are not compared.
            sig = tuple(sorted((case, row[check]["recent"]) for case, row in body["cells"].items() if check in row))
            if any("f" in r for _, r in sig):
                signatures.setdefault(sig, []).append(f"{suite}/{check}")
        identical += [group for group in signatures.values() if len(group) > 1]
    identical.sort()

    eligible = {cid for cid in candidates if cell_of(data, cid)["tier"] == "upper"}
    proposals, covered = [], set()

    def upper_cells(suite, case=None, check=None):
        body = data["suites"][suite]
        return {(suite, cs, k) for cs, row in body["cells"].items() for k, c in row.items()
                if c["tier"] == "upper" and (case is None or cs == case) and (check is None or k == check)}

    def propose(unit, cells):
        runs, calls = savings(data, cells)
        proposals.append({"unit": unit, "cells": len(cells), "runs_saved": runs, "judge_calls_saved": calls,
                          "total_failures": sum(failures(cell_of(data, c)) for c in cells)})
        covered.update(cells)

    for suite in sorted(data["suites"]):
        for check in sorted(data["suites"][suite]["checks"]):
            cells = upper_cells(suite, check=check)
            if cells and cells <= eligible:
                propose(f"{suite}/*/{check}", cells)
    for suite in sorted(data["suites"]):
        for case in sorted(data["suites"][suite]["cells"]):
            cells = upper_cells(suite, case=case)
            if cells and cells <= eligible and cells - covered:
                propose(f"{suite}/{case}/*", cells)
    for suite, check in sorted({(cid[0], cid[2]) for cid in eligible - covered}):
        propose(f"{suite}/~/{check}", {cid for cid in eligible if cid[0] == suite and cid[2] == check})

    verification = []
    for suite in sorted(data["suites"]):
        body = data["suites"][suite]
        for check in sorted(body["checks"]):
            if body["checks"][check]["grader"] != "judge":
                continue
            # No failure in the whole history, over at least a full window in every cell.
            cells = [row[check] for row in body["cells"].values() if check in row]
            if cells and all(failures(c) == 0 and c["trials"] >= WINDOW for c in cells):
                verification.append(f"{suite}/{check}")

    ids = lambda cells: ["/".join(c) for c in cells]
    return {
        "window": WINDOW,
        "cells": sum(1 for _ in all_cells(data)),
        "recent_all_passed": ids(candidates),
        "total_failures": {"/".join(c): failures(cell_of(data, c)) for c in candidates if failures(cell_of(data, c))},
        "insufficient_history": ids(short),
        "identical_checks": identical,
        "flipping": ids(flipping),
        "always_failing": ids(failing),
        "proposals": proposals,
        "verification_candidates": verification,
    }


def cell_of(data, cid):
    suite, case, check = cid
    return data["suites"][suite]["cells"][case][check]


def compact(data, cids):
    """Write a set of cells with whole checks as suite/*/check and whole cases as suite/case/*."""
    chosen, lines, shown = set(cids), [], set()
    for suite in sorted(data["suites"]):
        body = data["suites"][suite]
        for check in sorted(body["checks"]):
            cells = {(suite, cs, check) for cs, row in body["cells"].items() if check in row}
            if len(cells) > 1 and cells <= chosen:
                lines.append(f"{suite}/*/{check} ({len(cells)} cells)")
                shown |= cells
        for case in sorted(body["cells"]):
            cells = {(suite, case, k) for k in body["cells"][case]}
            if len(cells) > 1 and cells <= chosen and cells - shown:
                lines.append(f"{suite}/{case}/* ({len(cells)} cells)")
                shown |= cells
    lines += ["/".join(c) for c in sorted(chosen - shown)]
    return lines


def cells_text(data, p):
    """How many cells a proposal moves; a suite/~/check unit also names the upper cells it leaves out."""
    suite, case, check = p["unit"].split("/")
    if case != "~":
        return f"{p['cells']} upper cells"
    body = data["suites"][suite]
    out = sorted(f"{suite}/{cs}/{check}" for cs, row in body["cells"].items()
                 if check in row and row[check]["tier"] == "upper" and not is_candidate(row[check]))
    named = ", ".join(out[:5]) + (f" and {len(out) - 5} more" if len(out) > 5 else "")
    return f"{p['cells']} of {p['cells'] + len(out)} upper cells, leaving out {named}"


def markdown(data, result, path):
    split = lambda ids: [tuple(i.split("/")) for i in ids]
    out = [f"# Cell history audit: {path}", "",
           f"{result['cells']} cells, each judged by its most recent {WINDOW} trials, shown oldest first"
           " (p pass, f fail). A cell whose recent 10 all passed is a demotion candidate even when it failed before.", ""]

    def section(title, lines):
        out.append(f"## {title}")
        out.extend(f"- {line}" for line in lines) if lines else out.append("- none")
        out.append("")

    def shown(ids):
        lines = []
        for i in ids:
            c = cell_of(data, tuple(i.split("/")))
            lines.append(f"{i} {c['recent'] or '(no trials)'} ({c['passes']}/{c['trials']} in total,"
                         f" baseline {c.get('baseline') or 'unknown'})")
        return lines

    n = len(result["recent_all_passed"])
    section(f"Recent {WINDOW} all passed ({n})", compact(data, split(result["recent_all_passed"])))
    earlier = result["total_failures"]
    section(f"Candidates that failed before their recent {WINDOW} ({len(earlier)})",
            [f"{i}: {k} failure{'s' if k != 1 else ''} in total" for i, k in earlier.items()])
    section(f"Insufficient history ({len(result['insufficient_history'])})", shown(result["insufficient_history"]))
    section(f"Identical recent histories ({len(result['identical_checks'])})", [" = ".join(g) for g in result["identical_checks"]])
    section(f"Flipping ({len(result['flipping'])})", shown(result["flipping"]))
    section(f"Always failing ({len(result['always_failing'])})", shown(result["always_failing"]))
    section(f"Demotion proposals ({len(result['proposals'])})",
            [f"{p['unit']}: {cells_text(data, p)}; total failures {p['total_failures']};"
             f" saves {p['runs_saved']} runs and {p['judge_calls_saved']} judge calls per suite run"
             for p in result["proposals"]])
    section(f"Judged checks that never failed in their whole history ({len(result['verification_candidates'])})",
            result["verification_candidates"])
    return "\n".join(out)


def summary(data, result, path, out):
    eligible = {tuple(i.split("/")) for i in result["recent_all_passed"] if cell_of(data, tuple(i.split("/")))["tier"] == "upper"}
    runs, calls = savings(data, eligible)
    ranked = sorted(result["proposals"], key=lambda p: (-p["runs_saved"], -p["judge_calls_saved"], -p["cells"], p["unit"]))
    lines = [
        f"Cell history audit of {path} ({result['cells']} cells, judged by their recent {WINDOW} trials).",
        f"Full report: {out}",
        f"recent {WINDOW} all passed {len(result['recent_all_passed'])}"
        f" (of them {len(result['total_failures'])} failed before) · insufficient history {len(result['insufficient_history'])} · "
        f"identical histories {len(result['identical_checks'])} · flipping {len(result['flipping'])} · "
        f"always failing {len(result['always_failing'])}",
        f"{len(result['proposals'])} demotion proposals; all of them together save {runs} runs and {calls} judge calls per suite run.",
    ]
    if ranked:
        lines.append("Largest savings:")
        lines += [f"- {p['unit']}: {cells_text(data, p)} (total failures {p['total_failures']}),"
                  f" {p['runs_saved']} runs and {p['judge_calls_saved']} judge calls" for p in ranked[:10]]
    lines.append(f"Judged checks that never failed in their whole history: {len(result['verification_candidates'])}")
    return "\n".join(lines)


def parse_unit(data, unit):
    parts = unit.split("/")
    if len(parts) != 3 or parts[0] not in data["suites"]:
        raise Invalid(f"{unit}: not suite/case/check, suite/*/check, suite/case/*, or suite/~/check")
    suite, case, check = parts
    body = data["suites"][suite]
    if case == "~" and check in body["checks"]:
        return {(suite, cs, check) for cs, row in body["cells"].items() if check in row
                and row[check]["tier"] == "upper" and is_candidate(row[check])}
    if case != "*" and case not in body["cells"]:
        raise Invalid(f"{unit}: no case {case} in {suite}")
    if check != "*" and check not in body["checks"]:
        raise Invalid(f"{unit}: no check {check} in {suite}")
    return {(suite, cs, k) for cs, row in body["cells"].items() for k in row
            if (case == "*" or cs == case) and (check == "*" or k == check)}


def apply(data, units):
    moves = set()
    for unit in units:
        cells = {c for c in parse_unit(data, unit) if cell_of(data, c)["tier"] == "upper"}
        if not cells:
            raise Invalid(f"{unit}: holds no upper-tier cell")
        blocked = sorted("/".join(c) for c in cells if not is_candidate(cell_of(data, c)))
        if blocked:
            raise Invalid(f"{unit}: not every upper cell passed its recent {WINDOW} trials: {', '.join(blocked)}")
        moves |= cells
    for suite, case, check in sorted(moves):
        body = data["suites"][suite]
        body["cells"][case][check]["tier"] = "lower"
        if body.get("lower_tier_model") is None:
            body["lower_tier_model"] = body.get("last_run_model")
    return sorted("/".join(c) for c in moves)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    rep = sub.add_parser("report")
    rep.add_argument("history", type=Path)
    rep.add_argument("--json", action="store_true", help="print every list as JSON and write no file")
    rep.add_argument("--out", type=Path, help="where to write the full report (default: audit-report.md at the eval root, the history's grandparent)")
    app = sub.add_parser("apply")
    app.add_argument("history", type=Path)
    app.add_argument("units", nargs="+")
    args = parser.parse_args(argv)

    try:
        data = load(args.history)
        if data is None:
            print(f"No cell history at {args.history}. Nothing can be judged until regression runs record one.")
            return 3
        if args.command == "report":
            result = analyze(data)
            if args.json:
                print(json.dumps(result, indent=2))
                return 0
            # The eval root, outside regression/, whose files are all committed.
            out = args.out or args.history.parent.parent / "audit-report.md"
            out.write_text(markdown(data, result, args.history) + "\n")
            print(summary(data, result, args.history, out))
            return 0
        moved = apply(data, args.units)
        args.history.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print(f"Moved {len(moved)} cells to the lower tier:")
        print("\n".join(f"- {c}" for c in moved))
        return 0
    except Invalid as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
