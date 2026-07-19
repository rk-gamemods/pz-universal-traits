#!/usr/bin/env python3
"""Run the complete UTMods update-safe gate without writing repository outputs."""

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
DEFAULT_LUA = Path(r"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe")
DEFAULT_BASELINE = SCRIPT_DIR / "pz_api_baseline.json"
GENERATED_SMOKE = ROOT / "UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua"
RELEASE_SMOKE = ROOT / "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/UT_SmokePings.lua"
IGNORED_PARTS = {".git", "__pycache__", ".pytest_cache"}
TAIL_BYTES = 16_384


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua-exe", type=Path, default=DEFAULT_LUA)
    parser.add_argument("--baseline-file", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--smoke-log", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--challenge", required=True)
    parser.add_argument("--max-age-hours", type=float, default=4.0)
    parser.add_argument("--smoke-allowlist", type=Path)
    parser.add_argument("--step-timeout-seconds", type=float, default=300.0)
    args = parser.parse_args(argv)
    if args.max_age_hours <= 0 or args.step_timeout_seconds <= 0:
        parser.error("freshness and timeout values must be positive")
    return args


def snapshot_tree(root):
    snapshot = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file() or any(part in IGNORED_PARTS for part in path.relative_to(root).parts):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        snapshot[path.relative_to(root).as_posix()] = (path.stat().st_size, digest)
    return snapshot


def _tail(path):
    with path.open("rb") as stream:
        stream.seek(max(0, path.stat().st_size - TAIL_BYTES))
        return stream.read().decode("utf-8", errors="replace")


def run_step(label, command, timeout):
    with tempfile.TemporaryDirectory(prefix="utmods-step-") as temp:
        stdout_path, stderr_path = Path(temp) / "stdout", Path(temp) / "stderr"
        try:
            with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
                completed = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                                           timeout=timeout, check=False)
            return {"label": label, "returncode": completed.returncode,
                    "stdout_tail": _tail(stdout_path), "stderr_tail": _tail(stderr_path)}
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"label": label, "returncode": 124, "stdout_tail": "",
                    "stderr_tail": str(exc)}


def gate_status(steps):
    """Only a complete list of successful steps passes."""
    return "pass" if steps and all(step.get("returncode") == 0 for step in steps) else "fail"


def validate_generation_report(value):
    if not isinstance(value, dict) or value.get("version") != 2 or value.get("status") != "generated":
        raise ValueError("generation report has an invalid schema")
    surfaces, calls = value.get("surfaces"), value.get("calls")
    if not isinstance(surfaces, list) or not surfaces or not isinstance(calls, list):
        raise ValueError("generation report has an invalid call manifest")
    call_surfaces = []
    seen = set()
    for item in calls:
        if not isinstance(item, dict) or not isinstance(item.get("surface"), str) \
                or not item["surface"] or not isinstance(item.get("count"), int) or item["count"] <= 0 \
                or item.get("evidence") not in {"marker", "protocol"} or item["surface"] in seen:
            raise ValueError("generation report has an invalid call entry")
        seen.add(item["surface"])
        if item["evidence"] == "marker":
            call_surfaces.append(item["surface"])
    if call_surfaces != surfaces or len(surfaces) != len(set(surfaces)):
        raise ValueError("generation report surfaces do not exactly match calls")
    protocol = {item["surface"]: item for item in calls if item["evidence"] == "protocol"}
    marker_count = sum(item["count"] for item in calls if item["evidence"] == "marker")
    if set(protocol) != {"getTimestampMs", "print", "Events.OnGameStart.Add"} \
            or protocol["getTimestampMs"]["count"] != marker_count \
            or protocol["print"]["count"] != marker_count \
            or protocol["Events.OnGameStart.Add"]["count"] != 1:
        raise ValueError("generation report has an invalid protocol-call manifest")
    return value


def main(argv=None):
    args = parse_args(argv)
    not_before_ms = time.time_ns() // 1_000_000
    before = snapshot_tree(ROOT)
    steps = []
    with tempfile.TemporaryDirectory(prefix="utmods-gate-") as temp:
        temp_root = Path(temp)
        inventory = temp_root / "pz_api_inventory.json"
        generated = temp_root / "UT_SmokePings.lua"
        report = temp_root / "smoke_report.json"
        commands = [
            ("UT_CORE tests", [str(args.lua_exe), "UT_CORE/test/run_tests.lua"]),
            ("UniversalTraits tests", [str(args.lua_exe), "UniversalTraits/test/run_tests.lua"]),
            ("PZ API verifier", [sys.executable, "tools/verify_pz_api.py", "--json", "--inventory-out",
                                 str(inventory), "--baseline-file", str(args.baseline_file), "--compare-baseline"]),
        ]
        for label, command in commands:
            steps.append(run_step(label, command, args.step_timeout_seconds))
        generation = [sys.executable, "tools/generate_smoke_pings.py", "--inventory", str(inventory),
                      "--output", str(generated), "--report", str(report)]
        if args.smoke_allowlist:
            generation.extend(["--allowlist", str(args.smoke_allowlist)])
        steps.append(run_step("Smoke generation", generation, args.step_timeout_seconds))
        for label, artifact in (("source", GENERATED_SMOKE), ("release-42.0", RELEASE_SMOKE)):
            diff_ok = generated.is_file() and artifact.is_file() \
                and generated.read_bytes() == artifact.read_bytes()
            steps.append({"label": f"Generated smoke diff ({label})",
                          "returncode": 0 if diff_ok else 1, "stdout_tail": "",
                          "stderr_tail": "" if diff_ok else f"generated smoke differs from {artifact}"})
        try:
            manifest = validate_generation_report(json.loads(report.read_text(encoding="utf-8")))
        except (OSError, ValueError, json.JSONDecodeError, AttributeError) as exc:
            steps.append({"label": "Smoke log validation inputs", "returncode": 1,
                          "stdout_tail": "", "stderr_tail": str(exc)})
        else:
            not_after_ms = time.time_ns() // 1_000_000
            steps.append(run_step("Smoke log validation", [sys.executable, "tools/check_smoke_log.py",
                "--json", "--smoke-log", str(args.smoke_log), "--manifest", str(report),
                "--run-id", args.run_id, "--challenge", args.challenge,
                "--not-before-ms", str(not_before_ms), "--not-after-ms", str(not_after_ms)],
                args.step_timeout_seconds))
    after = snapshot_tree(ROOT)
    mutation = before != after
    steps.append({"label": "Worktree mutation check", "returncode": 1 if mutation else 0,
                  "stdout_tail": "", "stderr_tail": "repository files changed during gate" if mutation else ""})
    output = {"status": gate_status(steps), "run_id": args.run_id,
              "challenge": args.challenge, "not_before_ms": not_before_ms,
              "steps": steps, "mutation_detected": mutation}
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0 if output["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
