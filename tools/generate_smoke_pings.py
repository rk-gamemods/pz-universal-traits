#!/usr/bin/env python3
"""Generate deterministic, protocol-bearing UniversalTraits smoke pings."""

import argparse
import json
import os
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
DEFAULT_INVENTORY = SCRIPT_DIR / "pz_api_inventory.json"
DEFAULT_OUTPUT = ROOT / "UniversalTraits/media/lua/shared/UniversalTraits/UT_SmokePings.lua"
SAFE_METHOD_PREFIXES = ("get", "is", "has", "num", "size")
RECEIVER_EXPRESSIONS = {
    "ENDURANCE": "CharacterStat.ENDURANCE",
    "player": "player", "character": "player", "attacker": "player", "target": "player",
    "stats": "_stats", "bodyDamage": "_bd", "bd": "_bd", "nutrition": "_nutrition",
    "inv": "_inv", "inventory": "_inv", "container": "_inv", "pack": "_inv",
    "wornItems": "_wornItems", "square": "_square", "sq": "_square",
    "cm": "_cm", "gt": "_gt", "spottedList": "_parts",
}
RECEIVER_SURFACES = {"ENDURANCE": "CharacterStat"}
GLOBAL_RECEIVERS = {"ISEatFoodAction", "ISDrinkFluidAction", "ISFitnessAction"}
SETUP_CALLS = (
    ("getPlayer", "    local player = getPlayer()"),
    ("player.getStats", "    local _stats = player:getStats()"),
    ("player.getBodyDamage", "    local _bd = player:getBodyDamage()"),
    ("player.getNutrition", "    local _nutrition = player:getNutrition()"),
    ("player.getInventory", "    local _inv = player:getInventory()"),
    ("player.getWornItems", "    local _wornItems = player:getWornItems()"),
    ("player.getCurrentSquare", "    local _square = player:getCurrentSquare()"),
    ("bodyDamage.getBodyParts", "    local _parts = _bd:getBodyParts()"),
    ("getClimateManager", "    local _cm = getClimateManager()"),
    ("getGameTime", "    local _gt = getGameTime()"),
)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--allowlist", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def load_inventory(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or not isinstance(value.get("unique_surfaces"), list) \
            or not isinstance(value.get("call_sites"), list):
        raise ValueError("inventory must contain unique_surfaces and call_sites arrays")
    return value


def load_allowlist(path):
    if path is None:
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or any(not isinstance(k, str) or not isinstance(v, str) or not v.strip()
                                          for k, v in value.items()):
        raise ValueError("allowlist must map exact surface keys to non-empty reasons")
    return value


def eligible_surfaces(inventory):
    zero_arg = {(site.get("receiver"), site.get("method")) for site in inventory["call_sites"]
                if site.get("arg_count") == 0
                and "UT_SmokePings" not in site.get("relative_file", "")}
    return {(item.get("receiver"), item.get("method")) for item in inventory["unique_surfaces"]
            if item.get("verification_kind") != "script_xpboosts"
            and (item.get("receiver"), item.get("method")) in zero_arg
            and isinstance(item.get("receiver"), str) and isinstance(item.get("method"), str)
            and item["method"].startswith(SAFE_METHOD_PREFIXES)}


def build_plan(inventory, allowlist):
    eligible = eligible_surfaces(inventory)
    emitted, omitted = set(), {}
    for receiver, method in sorted(eligible):
        key = f"{receiver}.{method}"
        if key in allowlist:
            omitted[key] = allowlist[key]
        elif receiver in RECEIVER_EXPRESSIONS or receiver in GLOBAL_RECEIVERS:
            emitted.add((receiver, method))
        else:
            raise ValueError(f"eligible surface has no emitter or allowlisted omission: {key}")
    unused = sorted(set(allowlist) - {f"{r}.{m}" for r, m in eligible})
    if unused:
        raise ValueError("allowlist contains ineligible surfaces: " + ", ".join(unused))
    return sorted(emitted), omitted


def runtime_calls(emitted):
    return [surface for surface, _ in SETUP_CALLS] + [
        f"{RECEIVER_SURFACES.get(r, r)}.{m}" for r, m in sorted(emitted)]


def call_manifest(emitted):
    counts = {}
    order = []
    for surface in runtime_calls(emitted):
        if surface not in counts:
            order.append(surface)
            counts[surface] = 0
        counts[surface] += 1
    calls = [{"surface": surface, "count": counts[surface], "evidence": "marker"}
             for surface in order]
    marker_count = sum(counts.values())
    calls.extend([
        {"surface": "getTimestampMs", "count": marker_count, "evidence": "protocol"},
        {"surface": "print", "count": marker_count, "evidence": "protocol"},
        {"surface": "Events.OnGameStart.Add", "count": 1, "evidence": "protocol"},
    ])
    return calls


def generate_lua(emitted):
    emitted = sorted(emitted)
    lines = [
        "-- UT_SmokePings.lua", "-- Auto-generated; do not hand-edit.",
        "local function runPings()",
        "    local runId = tostring(UT_SMOKE_RUN_ID or '')",
        "    local challenge = tostring(UT_SMOKE_CHALLENGE or '')",
        "    if runId == '' or challenge == '' then error('UT smoke run proof is not configured') end",
        "    local function mark(surface)",
        "        print('[UT_SMOKE] run=' .. runId .. ' challenge=' .. challenge .. ' timestamp=' .. tostring(getTimestampMs()) .. ' surface=' .. surface)",
        "    end",
    ]
    for surface, expression in SETUP_CALLS:
        lines.extend([expression, f"    mark('{surface}')"])
    for receiver, method in emitted:
        key = f"{RECEIVER_SURFACES.get(receiver, receiver)}.{method}"
        if receiver in GLOBAL_RECEIVERS:
            lines.extend([
                f"    if type({receiver}) ~= 'table' then error('{receiver} is missing or not a table') end",
                f"    if type({receiver}.{method}) ~= 'function' then error('{key} is missing or not callable') end",
                f"    local _ = {receiver}.{method}",
            ])
        else:
            lines.append(f"    local _ = {RECEIVER_EXPRESSIONS[receiver]}:{method}()")
        lines.append(f"    mark('{key}')")
    lines.extend(["end", "", "Events.OnGameStart.Add(runPings)", ""])
    return "\n".join(lines)


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def _stage_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        return Path(temporary)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def _validate_staged_pair(output_stage, report_stage, source, report):
    if output_stage.read_bytes() != source.encode("utf-8"):
        raise ValueError("staged smoke output is not deterministic")
    loaded = json.loads(report_stage.read_text(encoding="utf-8"))
    calls = loaded.get("calls") if isinstance(loaded, dict) else None
    if loaded != report or not isinstance(calls, list) or any(not isinstance(item, dict) for item in calls):
        raise ValueError("staged smoke report does not match generated calls")
    if any(not isinstance(item.get("surface"), str) or not item["surface"]
           or not isinstance(item.get("count"), int) or item["count"] <= 0
           or item.get("evidence") not in {"marker", "protocol"} for item in calls) \
            or len({item["surface"] for item in calls}) != len(calls):
        raise ValueError("staged smoke report has an invalid call manifest")
    marker_calls = [item for item in calls if item.get("evidence") == "marker"]
    if loaded.get("surfaces") != [item.get("surface") for item in marker_calls]:
        raise ValueError("staged smoke report does not match generated calls")
    for item in marker_calls:
        surface, count = item.get("surface"), item.get("count")
        if not isinstance(surface, str) or not isinstance(count, int) or count <= 0 \
                or source.count(f"mark('{surface}')") != count:
            raise ValueError("staged smoke report has an invalid call multiplicity")
    protocol = {item.get("surface"): item for item in calls if item.get("evidence") == "protocol"}
    marker_count = sum(item["count"] for item in marker_calls)
    expected_protocol = {
        "getTimestampMs": (marker_count, source.count("getTimestampMs()") == 1),
        "print": (marker_count, source.count("        print('[UT_SMOKE]") == 1),
        "Events.OnGameStart.Add": (1, source.count("Events.OnGameStart.Add(runPings)") == 1),
    }
    if set(protocol) != set(expected_protocol):
        raise ValueError("staged smoke report has an invalid protocol-call manifest")
    for surface, (count, source_exact) in expected_protocol.items():
        if protocol[surface].get("count") != count or not source_exact:
            raise ValueError("staged smoke report has an invalid protocol-call multiplicity")


def promote_pair(output_path, source, report_path, report):
    """Promote output and report together, restoring both old files on any failure."""
    report_text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    output_stage = None
    report_stage = None
    backups = []
    promoted = []
    try:
        output_stage = _stage_text(output_path, source)
        report_stage = _stage_text(report_path, report_text)
        _validate_staged_pair(output_stage, report_stage, source, report)
        for destination, stage in ((output_path, output_stage), (report_path, report_stage)):
            backup = None
            if destination.exists():
                descriptor, name = tempfile.mkstemp(prefix=f".{destination.name}.rollback.", dir=destination.parent)
                os.close(descriptor)
                backup = Path(name)
                backup.unlink()
                try:
                    os.replace(destination, backup)
                except BaseException:
                    backup.unlink(missing_ok=True)
                    raise
            backups.append((destination, backup))
            try:
                os.replace(stage, destination)
            except BaseException:
                if backup is not None:
                    os.replace(backup, destination)
                raise
            promoted.append(destination)
        for _, backup in backups:
            if backup is not None:
                try:
                    backup.unlink(missing_ok=True)
                except OSError:
                    pass
    except BaseException:
        for destination, backup in reversed(backups):
            if destination in promoted:
                destination.unlink(missing_ok=True)
            if backup is not None and backup.exists():
                os.replace(backup, destination)
        raise
    finally:
        if output_stage is not None:
            output_stage.unlink(missing_ok=True)
        if report_stage is not None:
            report_stage.unlink(missing_ok=True)


def generate(inventory_path, output_path, allowlist_path=None):
    emitted, omitted = build_plan(load_inventory(inventory_path), load_allowlist(allowlist_path))
    source = generate_lua(emitted)
    calls = call_manifest(emitted)
    report = {"version": 2, "status": "generated",
              "surfaces": [item["surface"] for item in calls if item["evidence"] == "marker"],
              "calls": calls,
              "omitted": omitted}
    if output_path is not None:
        atomic_write(output_path, source)
    return source, report


def main(argv=None):
    args = parse_args(argv)
    source, report = generate(args.inventory, None, args.allowlist)
    if not args.dry_run and args.report:
        promote_pair(args.output, source, args.report, report)
    elif not args.dry_run:
        atomic_write(args.output, source)
    if args.dry_run:
        print(source, end="")
    else:
        print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
