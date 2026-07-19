#!/usr/bin/env python3
"""Validate one fresh, complete UT smoke run in a bounded log interval."""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

MARKER_RE = re.compile(
    r"\[UT_SMOKE\]\s+run=(?P<run>[A-Za-z0-9_.-]+)\s+"
    r"challenge=(?P<challenge>[A-Za-z0-9_.-]+)\s+"
    r"timestamp=(?P<timestamp>\d+)\s+surface=(?P<surface>[^\s]+)"
)
UT_FILE_RE = re.compile(r"(UT_\w+\.lua|UTCore_\w+\.lua|UniversalTraits/|UTCore/)")
ERROR_RE = re.compile(r"(RuntimeException|ERROR|FATAL|attempted to call nil|tried to call nil)")
TRACE_BLOCK_LINES = 12
TRACE_CONTINUATION_RE = re.compile(r"^\s*(?:$|stack traceback:|at\s|function:|\[|\.\.\.|Caused by:)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a UT smoke-run proof")
    parser.add_argument("--smoke-log", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--challenge", required=True)
    parser.add_argument("--not-before-ms", type=int, required=True)
    parser.add_argument("--not-after-ms", type=int, required=True)
    parser.add_argument("--json", dest="json_output", action="store_true")
    return parser.parse_args()


def load_manifest(path: Path) -> Counter:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("manifest must be a generated version 2 call manifest")
    calls = value.get("calls") if isinstance(value, dict) else None
    if value.get("version") != 2 or value.get("status") != "generated" or not isinstance(calls, list) or not calls:
        raise ValueError("manifest must be a generated version 2 call manifest")
    expected = Counter()
    seen = set()
    protocol = {}
    for item in calls:
        if not isinstance(item, dict) or not isinstance(item.get("surface"), str) \
                or not item["surface"] or not isinstance(item.get("count"), int) or item["count"] <= 0 \
                or item.get("evidence") not in {"marker", "protocol"}:
            raise ValueError("manifest calls must contain a surface, evidence, and positive integer count")
        if item["surface"] in seen:
            raise ValueError("manifest contains duplicate call entries")
        seen.add(item["surface"])
        if item["evidence"] == "marker":
            expected[item["surface"]] = item["count"]
        else:
            protocol[item["surface"]] = item["count"]
    if value.get("surfaces") != list(expected):
        raise ValueError("manifest surfaces do not exactly match calls")
    marker_count = sum(expected.values())
    if protocol != {"getTimestampMs": marker_count, "print": marker_count,
                    "Events.OnGameStart.Add": 1}:
        raise ValueError("manifest protocol-call multiplicities do not match markers")
    return expected


def find_ut_errors(lines):
    errors = []
    pending = []
    for number, line in enumerate(lines, 1):
        pending = [(header, remaining - 1) for header, remaining in pending if remaining > 1]
        same_line = UT_FILE_RE.search(line) and ERROR_RE.search(line)
        if same_line:
            errors.append({"line_number": number, "message": line.strip()[:500]})
        elif UT_FILE_RE.search(line) and pending and TRACE_CONTINUATION_RE.search(line):
            header, _ = pending[-1]
            errors.append({"line_number": header, "trace_line_number": number,
                           "message": line.strip()[:500]})
            pending.clear()
        elif pending and not TRACE_CONTINUATION_RE.search(line):
            pending.clear()
        if ERROR_RE.search(line) and not UT_FILE_RE.search(line):
            pending.append((number, TRACE_BLOCK_LINES))
    return errors


def validate(log_path: Path, manifest_path: Path, run_id: str, challenge: str,
             not_before_ms: int, not_after_ms: int) -> dict:
    if not_before_ms > not_after_ms:
        raise ValueError("invalid verification interval")
    expected = load_manifest(manifest_path)
    lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    parsed = []
    malformed = []
    for number, line in enumerate(lines, 1):
        match = MARKER_RE.search(line)
        if match:
            marker = match.groupdict()
            marker["timestamp"] = int(marker["timestamp"])
            marker["line_number"] = number
            if not_before_ms <= marker["timestamp"] <= not_after_ms:
                parsed.append(marker)
        elif "[UT_SMOKE]" in line:
            malformed.append({"line_number": number, "message": line.strip()[:500]})
    errors = find_ut_errors(lines)

    foreign = [m for m in parsed if m["run"] != run_id or m["challenge"] != challenge]
    accepted = [m for m in parsed if m["run"] == run_id and m["challenge"] == challenge]
    counts = Counter(m["surface"] for m in accepted)
    expected_set = set(expected)
    missing = [surface for surface, count in expected.items() if counts[surface] < count]
    duplicates = sorted(surface for surface, count in counts.items() if count > expected.get(surface, 0))
    extras = sorted(set(counts) - expected_set)
    clean = not (foreign or malformed or missing or duplicates or extras or errors)
    return {
        "status": "clean" if clean else "failed",
        "run_id": run_id,
        "challenge": challenge,
        "interval": {"not_before_ms": not_before_ms, "not_after_ms": not_after_ms},
        "expected_count": sum(expected.values()),
        "observed_count": len(accepted),
        "missing": missing,
        "duplicates": duplicates,
        "extras": extras,
        "foreign_markers": foreign,
        "malformed_markers": malformed,
        "errors": errors,
    }


def main() -> None:
    args = parse_args()
    try:
        if not args.smoke_log.is_file():
            raise FileNotFoundError(f"smoke log not found: {args.smoke_log}")
        result = validate(args.smoke_log, args.manifest, args.run_id, args.challenge,
                          args.not_before_ms, args.not_after_ms)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {"status": "invalid_input", "error": str(exc)}
    if args.json_output:
        print(json.dumps(result, sort_keys=True))
    else:
        print(f"Smoke proof: {result['status']}")
    raise SystemExit(0 if result["status"] == "clean" else 1)


if __name__ == "__main__":
    main()
