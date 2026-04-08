# Smoke System Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the DebugLog-based smoke gate with offline codebase verification, auto-generated in-game startup pings, and an informational log health check.

**Architecture:** The ping generator reads `pz_api_inventory.json` (produced by the existing verifier) and writes a Lua file with unguarded API pings. The verifier is cleaned of smoke-manifest logic. The log checker becomes an error scanner. The gate runner orchestrates the new pipeline.

**Tech Stack:** Python 3 (tooling), Lua 5.1/Kahlua (generated mod file)

---

## Task 1: Create the ping generator

**Files:**

- Create: `tools/generate_smoke_pings.py`

This is the core new tool. It reads the inventory JSON's `unique_surfaces` list, groups API calls by their chain root (the receiver variable that starts the call), and writes a Lua file with one unguarded ping per unique surface.

- [ ] **Step 1: Write `tools/generate_smoke_pings.py`**

```python
#!/usr/bin/env python3
"""
Generate UT_SmokePings.lua from the PZ API inventory.

Reads pz_api_inventory.json and writes a Lua file containing one unguarded
call per unique API surface. When loaded in-game at OnGameStart, any broken
API surface triggers PZ's native error handler immediately.
"""

import argparse
import json
import sys
from pathlib import Path
from collections import defaultdict

SCRIPT_DIR = Path(__file__).resolve().parent
UTMODS_ROOT = SCRIPT_DIR.parent
DEFAULT_INVENTORY = SCRIPT_DIR / "pz_api_inventory.json"
DEFAULT_OUTPUT = (
    UTMODS_ROOT
    / "UniversalTraits"
    / "media"
    / "lua"
    / "shared"
    / "UniversalTraits"
    / "UT_SmokePings.lua"
)

# How to obtain each receiver variable at OnGameStart time.
# Key: receiver name from the inventory.
# Value: Lua expression that yields the receiver, or None to skip.
#
# "chain" entries are obtained by calling a method on a parent receiver.
# They don't need a root expression — the generator builds the chain.
RECEIVER_ROOTS = {
    # Player object — the main root for most pings
    "player":     "getPlayer()",
    "character":  "getPlayer()",
    "attacker":   "getPlayer()",
    "target":     "getPlayer()",

    # Chained from player
    "stats":       None,  # player:getStats()
    "bodyDamage":  None,  # player:getBodyDamage()
    "bd":          None,  # player:getBodyDamage()
    "nutrition":   None,  # player:getBodyDamage():getNutrition()
    "inv":         None,  # player:getInventory()
    "inventory":   None,  # player:getInventory()
    "container":   None,  # player:getInventory()
    "pack":        None,  # player:getInventory()
    "wornItems":   None,  # player:getWornItems()
    "wornItem":    None,  # requires wornItems:getItemByIndex(0)
    "ENDURANCE":   None,  # player:getStats():getEndurance()

    # Items — need getPrimaryHandItem() which can be nil
    "weapon":      None,  # player:getPrimaryHandItem()
    "primary":     None,  # player:getPrimaryHandItem()
    "secondary":   None,  # player:getSecondaryHandItem()
    "item":        None,  # generic item — skip at startup (needs game context)
    "food":        None,  # Food subclass — skip at startup
    "sourceItem":  None,  # skip

    # Body parts — chained from bodyDamage
    "part":        None,
    "head":        None,

    # Environment globals
    "vehicle":     None,  # no vehicle at startup — skip
    "square":      None,  # player:getCurrentSquare()
    "sq":          None,  # player:getCurrentSquare()
    "cm":          "getClimateManager()",
    "gt":          "getGameTime()",

    # Zombie — no zombie at startup
    "zombie":      None,
    "chr":         None,

    # Lua PZ globals
    "ISEatFoodAction":    "ISEatFoodAction",
    "ISDrinkFluidAction": "ISDrinkFluidAction",
    "ISFitnessAction":    "ISFitnessAction",

    # Java collections — chained from other calls
    "spottedList": None,

    # Skip receivers (not PZ API — modData, strings, etc.)
    "obj":         None,
    "containerObj": None,
    "key":         None,
    "wtype":       None,
    "action":      None,
    "actionName":  None,
    "actionType":  None,
    "cats":        None,
    "trait":       None,
    "traitDefinition": None,
    "CharacterCreationProfession": None,
    "tree":        None,
    "md":          None,
    "fish":        None,
}

# Receivers that should be skipped entirely (no way to get them at startup,
# or they're not PZ API surfaces).
SKIP_RECEIVERS = {
    "obj", "key", "wtype", "action", "actionName", "actionType", "cats",
    "trait", "traitDefinition", "CharacterCreationProfession", "tree", "md",
    "fish", "containerObj",
}

# How to obtain chained receivers from a parent.
# (receiver_name, parent_receiver, method_on_parent)
CHAIN_SETUP = [
    # From player
    ("_stats",      "player",      "getStats()"),
    ("_bd",         "player",      "getBodyDamage()"),
    ("_nutrition",  "_bd",         "getNutrition()"),
    ("_inv",        "player",      "getInventory()"),
    ("_wornItems",  "player",      "getWornItems()"),
    ("_square",     "player",      "getCurrentSquare()"),
    # Body parts from BodyDamage (getBodyPart takes a BodyPartType enum)
    # Use getBodyParts():get(0) for a generic part ping
    ("_parts",      "_bd",         "getBodyParts()"),
]

# Maps inventory receivers to the local variable name used in the generated Lua.
RECEIVER_TO_LOCAL = {
    "player":     "player",
    "character":  "player",
    "attacker":   "player",
    "target":     "player",
    "stats":      "_stats",
    "bodyDamage": "_bd",
    "bd":         "_bd",
    "nutrition":  "_nutrition",
    "inv":        "_inv",
    "inventory":  "_inv",
    "container":  "_inv",
    "pack":       "_inv",
    "wornItems":  "_wornItems",
    "square":     "_square",
    "sq":         "_square",
    "cm":         "_cm",
    "gt":         "_gt",
    "ISEatFoodAction":    "ISEatFoodAction",
    "ISDrinkFluidAction": "ISDrinkFluidAction",
    "ISFitnessAction":    "ISFitnessAction",
    "ENDURANCE":  "_stats",
    "spottedList": "_parts",
    "part":       nil,       # handled specially
    "head":       nil,       # handled specially
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate UT_SmokePings.lua from PZ API inventory"
    )
    parser.add_argument(
        "--inventory",
        type=Path,
        default=DEFAULT_INVENTORY,
        help=f"Inventory JSON path (default: {DEFAULT_INVENTORY})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output Lua file path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated Lua to stdout instead of writing file",
    )
    return parser.parse_args()


def load_inventory(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_ping_groups(inventory: dict) -> dict[str, list[str]]:
    """Group unique surfaces by receiver, returning {receiver: [method, ...]}."""
    groups: dict[str, list[str]] = defaultdict(list)
    for surface in inventory.get("unique_surfaces", []):
        if surface["verification_kind"] == "script_xpboosts":
            continue
        receiver = surface["receiver"]
        if receiver in SKIP_RECEIVERS:
            continue
        method = surface["method"]
        groups[receiver].append(method)
    # Sort methods within each group for stable output
    return {r: sorted(set(methods)) for r, methods in groups.items()}


def generate_lua(ping_groups: dict[str, list[str]]) -> str:
    """Generate the Lua source for UT_SmokePings.lua."""
    lines = [
        "-- UT_SmokePings.lua",
        "-- Auto-generated by tools/generate_smoke_pings.py -- do not hand-edit.",
        "-- Fires every PZ API surface used by UniversalTraits at startup.",
        "-- If any call hits nil, PZ's error handler reports it immediately.",
        "",
        "local function runPings()",
        "    local player = getPlayer()",
        "    local _",
        "",
    ]

    # Set up chain roots
    lines.append("    -- Chain roots")
    for local_name, parent, method in CHAIN_SETUP:
        lines.append(f"    local {local_name} = {parent}:{method}")
    lines.append("")

    # Set up global roots
    lines.append("    -- Global roots")
    lines.append("    local _cm = getClimateManager()")
    lines.append("    local _gt = getGameTime()")
    lines.append("")

    # Group pings by the local variable they call on
    # Build a mapping: local_var -> [(method, comment), ...]
    var_pings: dict[str, list[tuple[str, str]]] = defaultdict(list)

    for receiver, methods in sorted(ping_groups.items()):
        local_var = RECEIVER_TO_LOCAL.get(receiver)
        if local_var is None:
            # Skip receivers we can't obtain at startup
            continue
        for method in methods:
            var_pings[local_var].append((method, receiver))

    # Emit pings grouped by local variable
    for local_var in sorted(var_pings.keys()):
        pings = var_pings[local_var]
        # Get a representative surface name for the comment
        receivers = sorted(set(p[1] for p in pings))
        lines.append(f"    -- {local_var} (receivers: {', '.join(receivers)})")
        for method, _receiver in sorted(pings):
            lines.append(f"    _ = {local_var}:{method}()")
        lines.append("")

    # Lua global existence checks (ISEatFoodAction etc.)
    lua_globals = []
    for receiver in sorted(ping_groups.keys()):
        if receiver in ("ISEatFoodAction", "ISDrinkFluidAction", "ISFitnessAction"):
            lua_globals.append(receiver)

    if lua_globals:
        lines.append("    -- Lua PZ globals")
        for g in lua_globals:
            methods = ping_groups[g]
            lines.append(f"    _ = {g}")
            for method in methods:
                lines.append(f"    _ = {g}.{method}")
        lines.append("")

    # ArrayList pings (spottedList etc.) via _parts
    if "spottedList" in ping_groups:
        lines.append("    -- Java collection interop (ArrayList)")
        for method in ping_groups["spottedList"]:
            lines.append(f"    _ = _parts:{method}()")
        lines.append("")

    lines.append("end")
    lines.append("")
    lines.append("Events.OnGameStart.Add(runPings)")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    inventory = load_inventory(args.inventory)
    ping_groups = build_ping_groups(inventory)

    lua_source = generate_lua(ping_groups)

    if args.dry_run:
        print(lua_source)
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(lua_source, encoding="utf-8")

    # Count pings
    ping_count = sum(len(methods) for methods in ping_groups.values())
    receiver_count = len(ping_groups)
    print(f"Generated {args.output}")
    print(f"  {ping_count} pings across {receiver_count} receivers")


if __name__ == "__main__":
    main()
```

Note: The `RECEIVER_TO_LOCAL` map has `nil` for `part` and `head` — these need special handling since body parts require an index. Fix this: replace the `nil` references with `None` (Python, not Lua). The body-part pings will be handled through `_parts:get(0)` in the ArrayList section, which covers the `BodyPart` surface transitively. The `head` receiver specifically calls `getBodyPart(BodyPartType.Head)` which requires the Java enum — we skip direct head pings and rely on the `_bd:getBodyParts()` chain covering the surface.

- [ ] **Step 2: Run the generator with `--dry-run` to verify output**

Run: `python tools/generate_smoke_pings.py --dry-run`
Expected: Prints a Lua file with ~170+ pings grouped by receiver variable, no Python errors.

- [ ] **Step 3: Run the generator to write the actual file**

Run: `python tools/generate_smoke_pings.py`
Expected: Writes `UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua` and prints a summary like "170 pings across 25 receivers".

- [ ] **Step 4: Verify the generated Lua is syntactically valid**

Run: `"C:/Users/Admin/AppData/Local/Programs/Lua/bin/lua.exe" -e "loadfile('UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua')"`
Expected: No syntax errors. (This only checks parse, not runtime — that's expected.)

- [ ] **Step 5: Commit**

```bash
git add tools/generate_smoke_pings.py UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua
git commit -m "feat: add ping generator and first generated UT_SmokePings.lua

Reads pz_api_inventory.json and writes a Lua file with one unguarded
call per unique API surface. Fires at OnGameStart to surface broken
APIs through PZ's native error handler."
```

---

### Task 2: Rewrite `check_smoke_log.py` as a DebugLog error scanner

**Files:**

- Modify: `tools/check_smoke_log.py`

Rewrite from a smoke-marker checker to a general UT error scanner.

- [ ] **Step 1: Rewrite `tools/check_smoke_log.py`**

```python
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
```

- [ ] **Step 2: Test against the current DebugLog**

Run: `python tools/check_smoke_log.py`
Expected: Either "clean (no UT errors)" or a list of errors from the last session. Exit code 0 either way.

Run: `python tools/check_smoke_log.py --json`
Expected: JSON output with `status`, `error_count`, `errors` array. Exit code 0.

- [ ] **Step 3: Commit**

```bash
git add tools/check_smoke_log.py
git commit -m "refactor: rewrite check_smoke_log.py as informational error scanner

No longer checks for specific [UT_SMOKE] markers. Instead scans the
latest DebugLog for any UT-related RuntimeExceptions or errors.
Always exits 0 — informational only, never blocks the gate."
```

---

### Task 3: Clean smoke-manifest logic from the verifier

**Files:**

- Modify: `tools/verify_pz_api.py` (lines 41-42, 742-790, 820-906, 908-1025, 1152-1440)

Remove the smoke manifest loading, scenario assignment, and coverage enforcement from the verifier. The inventory still records `surface_name`, `receiver`, `method` etc. — the ping generator needs those. But the `smoke_required`, `smoke_scenarios`, `smoke_rule_ids`, `smoke_state` fields and all manifest-related code are removed.

- [ ] **Step 1: Remove smoke-related constants and imports**

In `verify_pz_api.py`, remove:

- Line 41: `DEFAULT_SMOKE_MANIFEST = SCRIPT_DIR / "pz_api_smoke_manifest.json"`
- The `--smoke-manifest` and `--require-smoke-coverage` arguments from `parse_args()` (lines ~763-770)
- The `load_smoke_manifest` function (line 820)
- The `match_allowed` function (line 848)
- The `match_path` function (line 856)
- The `inventory_entry_matches_rule` function (line 879)
- The `assign_smoke_scenarios` function (line 896)

- [ ] **Step 2: Simplify `build_inventory_entry` to remove smoke fields**

Replace the function to remove `smoke_required`, `smoke_scenarios`, `smoke_rule_ids`, `smoke_state`:

```python
def build_inventory_entry(result: VerifyResult) -> dict:
    rel_file = normalize_rel_path(result.call.file)
    owner = classify_owner(rel_file)
    verification_source = "script_xpboosts" if result.call.receiver == "XPBoosts" else "pz_api_scan"
    verification_kind = "script_xpboosts" if result.call.receiver == "XPBoosts" else "method_call"

    return {
        "id": f"{rel_file}:{result.call.line_num}:{result.call.receiver}:{result.call.method}",
        "relative_file": rel_file,
        "line": result.call.line_num,
        "receiver": result.call.receiver,
        "method": result.call.method,
        "arg_count": result.call.arg_count,
        "status": result.status,
        "matched_class": result.matched_class,
        "surface_name": infer_surface_name(result),
        "matched_method": result.matched_method,
        "detail": result.detail,
        "line_text": result.call.line_text,
        "owner": owner,
        "verification_source": verification_source,
        "verification_kind": verification_kind,
    }
```

- [ ] **Step 3: Simplify `build_inventory` to remove smoke fields**

Update `build_inventory` signature to remove `smoke_manifest` parameter. Remove `smoke_scenarios` from the unique surface aggregation. Remove the `smoke_manifest` metadata from the output dict. Remove `smoke_required`, `smoke_covered`, `smoke_unassigned` from the summary.

Updated signature: `def build_inventory(results: list[VerifyResult], pz_metadata: dict) -> dict`

The `build_inventory_entry` call becomes: `build_inventory_entry(result)` (no smoke_manifest arg).

Remove from the unique surface aggregate: `"smoke_scenarios": set()` and `aggregate["smoke_scenarios"].update(...)` and `"smoke_scenarios": sorted(...)`.

Remove from the return dict: the `"smoke_manifest"` key and the three `smoke_*` summary keys.

- [ ] **Step 4: Update `main()` to remove smoke logic**

In `main()`:

- Remove the `smoke_manifest = load_smoke_manifest(...)` block
- Change `build_inventory(results, smoke_manifest, pz_metadata)` to `build_inventory(results, pz_metadata)`
- Remove `smoke_unassigned_entries` computation
- Remove `smoke_unassigned` from JSON output
- Remove `smoke_required`, `smoke_covered`, `smoke_unassigned` from JSON summary
- Remove the `args.require_smoke_coverage and smoke_unassigned_entries` check from exit logic
- Remove smoke coverage gap text output block
- Remove smoke summary lines from text output

- [ ] **Step 5: Run the verifier to confirm it still works**

Run: `cd UTMods && python tools/verify_pz_api.py --json --inventory-out tools/pz_api_inventory.json --baseline-file tools/pz_api_baseline.json --compare-baseline`
Expected: JSON output with 0 fail, 0 warn. No smoke-related fields in output. `pz_api_inventory.json` written without smoke fields.

- [ ] **Step 6: Verify the ping generator still works with the simplified inventory**

Run: `python tools/generate_smoke_pings.py --dry-run`
Expected: Same Lua output as before — the ping generator reads `unique_surfaces` which still has `receiver` and `method`.

- [ ] **Step 7: Commit**

```bash
git add tools/verify_pz_api.py tools/pz_api_inventory.json
git commit -m "refactor: remove smoke manifest logic from verifier

The verifier no longer loads pz_api_smoke_manifest.json or assigns
smoke scenarios to call sites. Inventory still records receiver,
method, and surface_name for the ping generator to consume."
```

---

### Task 4: Update the gate runner

**Files:**

- Modify: `tools/run_update_safe_gate.py`

Remove smoke manifest handling, add ping generation step, make log check informational.

- [ ] **Step 1: Rewrite `tools/run_update_safe_gate.py`**

```python
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
```

- [ ] **Step 2: Run the full gate**

Run: `cd UTMods && python tools/run_update_safe_gate.py`
Expected: All steps pass. Ping file is regenerated. DebugLog check reports informational results. Gate passes.

- [ ] **Step 3: Commit**

```bash
git add tools/run_update_safe_gate.py
git commit -m "refactor: simplify gate runner for new smoke system

Removes smoke manifest handling. Adds ping generation step.
Log check is now informational only — never blocks the gate."
```

---

### Task 5: Remove obsolete files and sync deployment

**Files:**

- Remove: `tools/pz_api_smoke_manifest.json`
- Remove: `UT_CORE/media/lua/shared/UTCore/UTCore_SmokeRecorder.lua`
- Remove: `UT_CORE/release/UT_CORE/42/media/lua/shared/UTCore/UTCore_SmokeRecorder.lua`
- Remove: `UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokeStartup.lua`
- Remove: `UniversalTraits/release/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokeStartup.lua`
- Sync: `UniversalTraits/release/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokePings.lua`
- Sync: Live mod folders

- [ ] **Step 1: Delete obsolete files from repo**

```bash
git rm tools/pz_api_smoke_manifest.json
git rm UT_CORE/media/lua/shared/UTCore/UTCore_SmokeRecorder.lua
git rm UT_CORE/release/UT_CORE/42/media/lua/shared/UTCore/UTCore_SmokeRecorder.lua
git rm UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokeStartup.lua
git rm UniversalTraits/release/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokeStartup.lua
```

- [ ] **Step 2: Copy generated ping file to release folder**

```bash
cp UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua \
   UniversalTraits/release/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokePings.lua
```

- [ ] **Step 3: Sync to live mod folders**

```bash
# Remove obsolete files from live mods
rm -f "C:/Users/Admin/Zomboid/mods/UT_CORE/42/media/lua/shared/UTCore/UTCore_SmokeRecorder.lua"
rm -f "C:/Users/Admin/Zomboid/mods/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokeStartup.lua"

# Copy new ping file to live mod
cp UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua \
   "C:/Users/Admin/Zomboid/mods/UniversalTraits/42/media/lua/shared/UniversalTraits/UT_SmokePings.lua"
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove obsolete smoke files, sync deployment

Removes UTCore_SmokeRecorder.lua, UT_SmokeStartup.lua, and
pz_api_smoke_manifest.json. Adds generated UT_SmokePings.lua to
release folder."
```

---

### Task 6: Update baseline and run final gate verification

**Files:**

- Modify: `tools/pz_api_baseline.json` (rewritten by verifier)

The inventory format changed (no smoke fields), so the baseline needs to be rewritten.

- [ ] **Step 1: Write new baseline**

Run: `cd UTMods && python tools/verify_pz_api.py --inventory-out tools/pz_api_inventory.json --baseline-file tools/pz_api_baseline.json --write-baseline`
Expected: Baseline written successfully. No FAIL/WARN results.

- [ ] **Step 2: Run the full gate end-to-end**

Run: `cd UTMods && python tools/run_update_safe_gate.py`
Expected: All 5 steps pass. Gate summary shows all PASS, ping generation OK, and DebugLog health status. "Update-safety gate passed" at the end.

- [ ] **Step 3: Commit**

```bash
git add tools/pz_api_baseline.json tools/pz_api_inventory.json
git commit -m "chore: update baseline and inventory for smoke-free verifier

Baseline and inventory no longer contain smoke manifest fields."
```

---

### Task 7: Update documentation

**Files:**

- Modify: `AGENTS.md` (update gate pipeline description and smoke workflow references)

- [ ] **Step 1: Update AGENTS.md**

Find and update any sections that reference:

- The smoke manifest or `pz_api_smoke_manifest.json`
- `UTCore_SmokeRecorder.lua` or `UT_SmokeStartup.lua`
- `--require-smoke-coverage` or `--skip-live-smoke`
- The old 13-scenario smoke concept

Replace with references to:

- `generate_smoke_pings.py` and `UT_SmokePings.lua`
- The new gate pipeline (steps 1-5)
- The informational DebugLog health check

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for new smoke ping system"
```
