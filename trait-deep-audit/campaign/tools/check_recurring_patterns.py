"""Detect recurring audit defect patterns without modifying product sources."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

from campaign_cli import no_arg_command


CAMPAIGN_ROOT = Path(__file__).resolve().parents[1]
UTMODS_ROOT = CAMPAIGN_ROOT.parents[1]
PZCODEBASE_ROOT = UTMODS_ROOT.parent / "PZCodebase"
OUTPUT_PATH = CAMPAIGN_ROOT / "recurring_pattern_findings.json"


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _relative(path: Path) -> str:
    try:
        return path.relative_to(UTMODS_ROOT.parent).as_posix()
    except ValueError:
        return path.as_posix()


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _finding(
    finding_id: str,
    severity: str,
    title: str,
    anchors: list[str],
    affected_surfaces: list[str],
    reproduction_evidence: str,
    recommended_correction: str,
    smallest_regression_test: str,
    *,
    confidence: str = "high",
    missing_proof: str = "",
) -> dict[str, Any]:
    return {
        "id": finding_id,
        "state": "confirmed-defect",
        "severity": severity,
        "confidence": confidence,
        "title": title,
        "anchors": sorted(anchors),
        "affected_surfaces": sorted(affected_surfaces),
        "reproduction_evidence": reproduction_evidence,
        "missing_proof": missing_proof,
        "recommended_correction": recommended_correction,
        "smallest_regression_test": smallest_regression_test,
    }


def engine_event_names(pzcodebase_root: Path) -> set[str]:
    names: set[str] = set()
    paths = [pzcodebase_root / "Java" / "source" / "zombie" / "Lua" / "LuaEventManager.java"]
    paths.extend((pzcodebase_root / "Lua").rglob("*.lua"))
    pattern = re.compile(r"(?:LuaEventManager\.)?AddEvent\(\s*[\"']([^\"']+)[\"']\s*\)")
    for path in paths:
        if path.is_file():
            names.update(pattern.findall(path.read_text(encoding="utf-8", errors="replace")))
    return names


def lua_event_registrations(path: Path) -> list[tuple[str, str, int]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    result = []
    pattern = re.compile(r"Events\.([A-Za-z0-9_]+)\.Add\s*\(\s*([A-Za-z0-9_\.]+)")
    for match in pattern.finditer(text):
        result.append((match.group(1), match.group(2), _line_number(text, match.start())))
    return result


def weapon_hit_signature_inversions(path: Path) -> list[tuple[str, int, list[str]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    definitions: dict[str, tuple[int, list[str]]] = {}
    definition_pattern = re.compile(
        r"(?:local\s+)?function\s+([A-Za-z0-9_\.]+)\s*\(([^)]*)\)"
    )
    for match in definition_pattern.finditer(text):
        params = [item.strip().lower() for item in match.group(2).split(",") if item.strip()]
        definitions[match.group(1)] = (_line_number(text, match.start()), params)

    inversions = []
    target_words = {"target", "victim", "character", "defender", "hitcharacter"}
    weapon_words = {"weapon", "handweapon", "item"}
    for event, handler, _ in lua_event_registrations(path):
        if event != "OnWeaponHitCharacter" or handler not in definitions:
            continue
        line, params = definitions[handler]
        if len(params) >= 3 and params[1] in weapon_words and params[2] in target_words:
            inversions.append((handler, line, params))
    return inversions


def fractional_time_of_day_thresholds(path: Path) -> list[int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    if "getTimeOfDay" not in text:
        return []
    pattern = re.compile(r"(?:<=?|>=?|==)\s*0\.(?:25|75)\b")
    return sorted({_line_number(text, match.start()) for match in pattern.finditer(text)})


def translator_mutated_percent_keys(ui_json_path: Path) -> list[str]:
    values = json.loads(ui_json_path.read_text(encoding="utf-8"))
    affected = []
    for key, value in values.items():
        if not isinstance(value, str):
            continue
        rendered = re.sub(r"%(?=[^ds.]|$)", "%%", value)
        rendered = re.sub(r"%%(\d+)", r"%\1$s", rendered)
        if rendered != value:
            affected.append(key)
    return sorted(affected)


def tree_parity(source: Path, release: Path) -> dict[str, list[str]]:
    source_files = {path.relative_to(source).as_posix(): path for path in source.rglob("*") if path.is_file()}
    release_files = {path.relative_to(release).as_posix(): path for path in release.rglob("*") if path.is_file()}
    common = set(source_files).intersection(release_files)
    return {
        "missing_in_release": sorted(set(source_files) - set(release_files)),
        "extra_in_release": sorted(set(release_files) - set(source_files)),
        "content_mismatch": sorted(
            name for name in common if _sha256(source_files[name]) != _sha256(release_files[name])
        ),
    }


def build_report(
    utmods_root: Path = UTMODS_ROOT,
    pzcodebase_root: Path = PZCODEBASE_ROOT,
) -> dict[str, Any]:
    lua_roots = [utmods_root / "UT_CORE" / "media", utmods_root / "UniversalTraits" / "media"]
    lua_files = sorted(path for root in lua_roots for path in root.rglob("*.lua"))
    known_events = engine_event_names(pzcodebase_root)
    findings: list[dict[str, Any]] = []

    unknown_events: dict[str, list[tuple[Path, int]]] = defaultdict(list)
    for path in lua_files:
        for event, _handler, line in lua_event_registrations(path):
            if event not in known_events:
                unknown_events[event].append((path, line))
    for event, occurrences in sorted(unknown_events.items()):
        anchors = [f"{_relative(path)}:{line}" for path, line in occurrences]
        findings.append(
            _finding(
                f"RP-EVENT-UNKNOWN-{event.upper()}",
                "high",
                f"Runtime registers event {event} absent from the current engine event registry",
                anchors,
                ["event-lifecycle", "runtime", "tests"],
                f"The current PZCodebase event registry contains {len(known_events)} names but not {event}; "
                f"UTMods registers it at {len(occurrences)} call site(s).",
                "Use the current engine event name and contract, or implement an explicit project-owned event producer.",
                f"Build the engine event set and assert {event} is registered before any Events.{event}.Add call is accepted.",
            )
        )

    for path in lua_files:
        for handler, line, params in weapon_hit_signature_inversions(path):
            findings.append(
                _finding(
                    f"RP-EVENT-ARGS-{path.stem.upper()}",
                    "high",
                    "OnWeaponHitCharacter handler swaps target and weapon positions",
                    [f"{_relative(path)}:{line}"],
                    ["event-contract", "runtime", "tests"],
                    "PZ triggers OnWeaponHitCharacter as (wielder, target, weapon, damage); "
                    f"{handler} declares ({', '.join(params)}).",
                    "Declare and consume the callback as (attacker, target, weapon, damage).",
                    "Invoke the handler through an event mock using the engine argument order and assert the target and weapon operations hit the correct objects.",
                )
            )

        time_lines = fractional_time_of_day_thresholds(path)
        if time_lines:
            findings.append(
                _finding(
                    f"RP-TIME-RANGE-{path.stem.upper()}",
                    "high",
                    "getTimeOfDay result is compared to fractional-day thresholds",
                    [f"{_relative(path)}:{line}" for line in time_lines],
                    ["numerical-behavior", "runtime", "tests"],
                    "Current PZ getTimeOfDay returns an hour on a 0..24 scale; the file compares it to 0.25/0.75.",
                    "Use hour thresholds such as 6 and 18, with explicit boundary behavior.",
                    "Run boundary cases at 0, 5.99, 6, 17.99, 18, and 23.99 on a 0..24 mock clock.",
                )
            )

    ui_path = utmods_root / "UniversalTraits" / "media" / "lua" / "shared" / "Translate" / "EN" / "UI.json"
    percent_keys = translator_mutated_percent_keys(ui_path)
    if percent_keys:
        findings.append(
            _finding(
                "RP-TRANSLATION-LITERAL-PERCENT",
                "high",
                "Translator preprocessing mutates literal percent signs in English descriptions",
                [f"{_relative(ui_path)} (keys: {', '.join(percent_keys)})"],
                ["description", "localization", "runtime"],
                f"Applying the current two-step Translator replacement changes {len(percent_keys)} no-argument descriptions.",
                "Encode literal percent signs using the Translator-safe representation verified for this game build.",
                "Load every flagged key through the current Translator path without format arguments and compare the rendered text byte-for-byte with intended copy.",
            )
        )

    parity_results = {}
    for mod_name in ("UT_CORE", "UniversalTraits"):
        source = utmods_root / mod_name / "media"
        release = utmods_root / mod_name / "release" / mod_name / "42.0" / "media"
        parity = tree_parity(source, release)
        parity_results[mod_name] = parity
        drift = sum(len(values) for values in parity.values())
        if drift:
            detail = "; ".join(f"{name}={values}" for name, values in parity.items() if values)
            findings.append(
                _finding(
                    f"RP-PACKAGE-PARITY-{mod_name}",
                    "high",
                    f"{mod_name} source and 42.0 release media trees differ",
                    [f"{_relative(source)}", f"{_relative(release)}"],
                    ["packaging", "release-parity"],
                    detail,
                    "Regenerate the release tree only through the authorized deployment workflow after product fixes and passing tests.",
                    "Hash every relative source/release media file and require empty missing, extra, and content-mismatch sets.",
                )
            )

    findings.sort(key=lambda item: item["id"])
    return {
        "schema_version": "1.0",
        "artifact_type": "recurring-pattern-audit",
        "engine_event_registry": {
            "source": _relative(pzcodebase_root / "Java" / "source" / "zombie" / "Lua" / "LuaEventManager.java"),
            "event_count": len(known_events),
        },
        "checks": {
            "engine_event_membership": True,
            "OnWeaponHitCharacter_argument_order": True,
            "getTimeOfDay_scale": True,
            "literal_percent_translation_risk": True,
            "source_release_media_parity": True,
        },
        "summary": {
            "findings": len(findings),
            "unknown_event_names": len(unknown_events),
            "literal_percent_keys": len(percent_keys),
            "source_release_drift_files": sum(
                len(values) for result in parity_results.values() for values in result.values()
            ),
        },
        "findings": findings,
        "parity": parity_results,
    }


def render_report(report: dict[str, Any]) -> str:
    return json.dumps(report, indent=2, ensure_ascii=False, sort_keys=False) + "\n"


def main() -> int:
    cli_result = no_arg_command(
        sys.argv,
        "Usage: py -3 check_recurring_patterns.py",
    )
    if cli_result is not None:
        return cli_result
    report = build_report()
    OUTPUT_PATH.write_text(render_report(report), encoding="utf-8", newline="\n")
    print(
        json.dumps(
            {
                **report["summary"],
                "output": str(OUTPUT_PATH),
                "sha256": _sha256(OUTPUT_PATH),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
