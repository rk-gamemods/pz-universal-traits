#!/usr/bin/env python3
"""
Run the local UniversalTraits update-safety gate.

Pipeline:
  1. UT_CORE Lua test suite                    (pass/fail)
  2. UniversalTraits Lua test suite            (pass/fail)
  3. PZ API verifier + baseline comparison     (pass/fail)
  4. Generate smoke pings from inventory       (always succeeds)
  5. Scan latest DebugLog for UT errors        (informational)
"""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
UTMODS_ROOT = SCRIPT_DIR.parent
DEFAULT_LUA = Path(r"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe")
DEFAULT_BASELINE = SCRIPT_DIR / "pz_api_baseline.json"
DEFAULT_PINGS_OUTPUT = (
    UTMODS_ROOT
    / "UniversalTraits"
    / "media"
    / "lua"
    / "shared"
    / "UniversalTraits"
    / "UT_SmokePings.lua"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the local UTMods update-safety gate")
    parser.add_argument(
        "--lua-exe",
        type=Path,
        default=DEFAULT_LUA,
        help=f"Lua interpreter path (default: {DEFAULT_LUA})",
    )
    parser.add_argument(
        "--inventory-out",
        type=Path,
        help="Optional path to write the machine-readable PZ API inventory JSON",
    )
    parser.add_argument(
        "--baseline-file",
        type=Path,
        default=DEFAULT_BASELINE,
        help=f"Baseline snapshot path (default: {DEFAULT_BASELINE})",
    )
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="Write the current verifier inventory as the accepted baseline snapshot",
    )
    parser.add_argument(
        "--smoke-log",
        type=Path,
        help="Optional explicit smoke log file for DebugLog health check",
    )
    parser.add_argument(
        "--max-age-hours",
        type=float,
        default=4.0,
        help="Freshness limit for auto-discovered DebugLogs (default: 4 hours)",
    )
    parser.add_argument(
        "--skip-log-check",
        action="store_true",
        help="Skip the DebugLog health check",
    )
    return parser.parse_args()


def run_step(label: str, command: list[str]) -> subprocess.CompletedProcess[str]:
    print("=" * 70)
    print(label)
    print("=" * 70)
    print(" ".join(command))
    result = subprocess.run(command, cwd=UTMODS_ROOT, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    return result


def main() -> None:
    args = parse_args()

    if not args.lua_exe.exists():
        raise SystemExit(f"Lua interpreter not found: {args.lua_exe}")

    with tempfile.TemporaryDirectory() as temp_dir:
        inventory_path = args.inventory_out or (Path(temp_dir) / "pz_api_inventory.json")

        # Step 1: UT_CORE tests
        ut_core_result = run_step(
            "Step 1: UT_CORE test suite",
            [str(args.lua_exe), "UT_CORE/test/run_tests.lua"],
        )

        # Step 2: UniversalTraits tests
        universal_traits_result = run_step(
            "Step 2: UniversalTraits test suite",
            [str(args.lua_exe), "UniversalTraits/test/run_tests.lua"],
        )

        # Step 3: PZ API verifier
        verifier_cmd = [
            sys.executable,
            "tools/verify_pz_api.py",
            "--json",
            "--inventory-out",
            str(inventory_path),
            "--baseline-file",
            str(args.baseline_file),
        ]
        if args.write_baseline:
            verifier_cmd.append("--write-baseline")
        else:
            verifier_cmd.append("--compare-baseline")

        verifier_result = run_step("Step 3: PZ API verifier + baseline comparison", verifier_cmd)
        verifier_json = None
        if verifier_result.stdout:
            try:
                verifier_json = json.loads(verifier_result.stdout)
            except json.JSONDecodeError:
                pass

        # Step 4: Generate smoke pings
        ping_result = run_step(
            "Step 4: Generate smoke pings",
            [sys.executable, "tools/generate_smoke_pings.py", "--inventory", str(inventory_path)],
        )

        # Step 5: DebugLog health check (informational)
        log_json = None
        if not args.skip_log_check:
            log_cmd = [
                sys.executable,
                "tools/check_smoke_log.py",
                "--json",
            ]
            if args.smoke_log:
                log_cmd.extend(["--smoke-log", str(args.smoke_log)])
            if args.max_age_hours is not None:
                log_cmd.extend(["--max-age-hours", str(args.max_age_hours)])
            log_result = run_step("Step 5: DebugLog health check (informational)", log_cmd)
            if log_result.stdout:
                try:
                    log_json = json.loads(log_result.stdout)
                except json.JSONDecodeError:
                    pass

    # Gate summary
    print("=" * 70)
    print("Gate Summary")
    print("=" * 70)
    print(f"UT_CORE tests:               {'PASS' if ut_core_result.returncode == 0 else 'FAIL'}")
    print(f"UniversalTraits tests:       {'PASS' if universal_traits_result.returncode == 0 else 'FAIL'}")
    if verifier_json is not None:
        baseline = verifier_json.get("baseline") or {}
        print(f"Verifier fail/warn:          {verifier_json['summary']['fail']}/{verifier_json['summary']['warn']}")
        print(f"Baseline classification:     {baseline.get('status', 'not-run')}")
    print(f"Ping generation:             {'OK' if ping_result.returncode == 0 else 'WARN'}")
    if log_json is not None:
        status = log_json.get("status", "not-run")
        error_count = log_json.get("error_count", 0)
        if status == "clean":
            print("Live session health:         clean")
        elif status == "errors_found":
            print(f"Live session health:         {error_count} errors found (informational)")
        else:
            print(f"Live session health:         {status}")

    print("=" * 70)

    # Gate pass/fail — only steps 1-3 matter
    gate_pass = (
        ut_core_result.returncode == 0
        and universal_traits_result.returncode == 0
        and verifier_result.returncode == 0
    )

    if gate_pass:
        print("Update-safety gate passed")
        print("=" * 70)
        return

    print("Update-safety gate FAILED")
    print("=" * 70)

    if ut_core_result.returncode != 0:
        raise SystemExit(ut_core_result.returncode)
    elif universal_traits_result.returncode != 0:
        raise SystemExit(universal_traits_result.returncode)
    else:
        raise SystemExit(verifier_result.returncode)


if __name__ == "__main__":
    main()