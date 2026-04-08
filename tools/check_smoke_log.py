#!/usr/bin/env python3
"""
Scan the latest PZ DebugLog for UT-related errors and warnings.

Finds the most recent DebugLog in ~/Zomboid/Logs and reports any errors
originating from UniversalTraits or UTCore mod files. This is an
informational check — it never blocks the gate.
"""

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_LOGS_ROOT = Path.home() / "Zomboid" / "Logs"

# Patterns that indicate a UT-related error in the log
UT_FILE_RE = re.compile(r"(UT_\w+\.lua|UTCore_\w+\.lua|UniversalTraits/|UTCore/)")
ERROR_MARKER_RE = re.compile(r"(RuntimeException|ERROR|FATAL|attempted to call nil|tried to call nil)")
SMOKE_RE = re.compile(r"\[UT_SMOKE\]\s+scenario=([A-Za-z0-9_.-]+)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scan PZ DebugLog for UT-related errors")
    parser.add_argument("--smoke-log", type=Path, help="Explicit debug log file to inspect")
    parser.add_argument("--logs-root", type=Path, default=DEFAULT_LOGS_ROOT,
                        help=f"Root log directory to search (default: {DEFAULT_LOGS_ROOT})")
    parser.add_argument("--max-age-hours", type=float,
                        help="Optional freshness limit for auto-discovered logs")
    parser.add_argument("--json", dest="json_output", action="store_true",
                        help="Emit machine-readable JSON")
    return parser.parse_args()


def discover_latest_log(logs_root: Path) -> Path | None:
    if not logs_root.exists():
        return None
    candidates = list(logs_root.rglob("*_DebugLog.txt")) + list(logs_root.rglob("DebugLog.txt"))
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def scan_log(path: Path) -> list[dict]:
    """Scan a DebugLog for UT-related errors. Returns a list of error dicts."""
    errors = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if this line mentions a UT file AND looks like an error
        if UT_FILE_RE.search(line) and ERROR_MARKER_RE.search(line):
            # Collect the stack trace (indented lines following the error)
            trace_lines = [line]
            j = i + 1
            while j < len(lines) and (lines[j].startswith("    ") or lines[j].startswith("\t")):
                trace_lines.append(lines[j])
                j += 1

            # Extract the UT file name from the error
            file_match = re.search(r"(UT_\w+\.lua|UTCore_\w+\.lua)", line)
            source_file = file_match.group(1) if file_match else "unknown"

            errors.append({
                "line_number": i + 1,
                "source_file": source_file,
                "message": line.strip(),
                "trace_length": len(trace_lines),
            })
            i = j
            continue

        i += 1

    return errors


def scan_smoke_markers(path: Path) -> list[str]:
    """Scan for [UT_SMOKE] markers (backwards compatibility)."""
    found = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = SMOKE_RE.search(line)
        if match:
            found.append(match.group(1))
    return sorted(set(found))


def main() -> None:
    args = parse_args()

    log_path = args.smoke_log or discover_latest_log(args.logs_root)
    if log_path is None:
        output = {"status": "no_log_found", "errors": [], "smoke_markers": []}
        if args.json_output:
            print(json.dumps(output, indent=2))
        else:
            print("Live session health:  no recent log found")
        sys.exit(0)  # Informational — never fails

    if args.max_age_hours is not None:
        mtime = datetime.fromtimestamp(log_path.stat().st_mtime, tz=timezone.utc)
        if mtime < datetime.now(timezone.utc) - timedelta(hours=args.max_age_hours):
            output = {"status": "stale_log", "log_file": str(log_path), "errors": [], "smoke_markers": []}
            if args.json_output:
                print(json.dumps(output, indent=2))
            else:
                print(f"Live session health:  stale log (older than {args.max_age_hours}h)")
                print(f"Log file: {log_path}")
            sys.exit(0)  # Informational — never fails

    errors = scan_log(log_path)
    smoke_markers = scan_smoke_markers(log_path)

    status = "errors_found" if errors else "clean"
    output = {
        "status": status,
        "log_file": str(log_path),
        "error_count": len(errors),
        "errors": errors,
        "smoke_markers": smoke_markers,
    }

    if args.json_output:
        print(json.dumps(output, indent=2))
    else:
        if errors:
            print(f"Live session health:  {len(errors)} UT errors found")
        else:
            print("Live session health:  clean (no UT errors)")
        print(f"Log file: {log_path}")
        if smoke_markers:
            print(f"Smoke markers: {len(smoke_markers)}")
        for err in errors:
            print(f"  [{err['source_file']}:{err['line_number']}] {err['message'][:120]}")

    sys.exit(0)  # Always exit 0 — informational only


if __name__ == "__main__":
    main()