"""Regenerate only Scaredy Cat-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_cleaver as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_scardycat"
FINDINGS = (
    "B09-SCARDYCAT-001",
    "B09-SCARDYCAT-002",
    "B09-SCARDYCAT-003",
)
RESOLVED_FINDINGS = FINDINGS[:2]
OPEN_FINDING = FINDINGS[2]
DESCRIPTION = (
    "You startle easily and panic often. When panic rises by at least 5 points "
    "between one-minute checks, 15 additional panic points are added. When at "
    "least 9 living zombies are spotted, each eligible player update has a 3 "
    "percent chance to make you scream and attract attention. After a scream, "
    "this chance pauses for 120 player updates."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_scardycat.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_scardycat.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_scardycat.md"
RESOLUTION = "change-impact/scardycat-panic-lifecycle.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_09.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_09_12.json",
    "release_blocker_queue.json",
    RESOLUTION,
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "campaign_manifest.json",
)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_09.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": HELPER._dimension(
            "proven-correct", "Registry, definition, runtime, and English keys agree."
        ),
        "definition_parser": HELPER._dimension(
            "runtime-unproven",
            "Source and release definitions are byte-identical and standard-Lua tests prove cost and exclusions.",
            "Current-build ScriptManager parsing remains unobserved.",
        ),
        "namespace": HELPER._dimension(
            "proven-correct", "All owned surfaces use UniversalTraits:UT_scardycat."
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is -3, there are no XP boosts or grants, and exclusions retain UT_flailer plus base:desensitized.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master defines the accepted minute-window panic cascade and living-spotted-zombie scream mechanics.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "One UTCore periodic handler owns panic sampling and one UTCore tick handler owns living-enemy scream checks.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "Fresh panic rises of at least 5 add exactly 15 and cap at 100; scream requires 9 living enemies and ZombRand(100) below 3.",
        ),
        "cadence": HELPER._dimension(
            "confirmed-defect",
            "Panic samples once per in-game minute, but scream rolls remain tied to player-update frequency.",
            "A user-approved frame-rate-independent scream frequency is required.",
        ),
        "cooldown": HELPER._dimension(
            "confirmed-defect",
            "The accepted 120-player-update cooldown remains update-rate dependent.",
            "A user-approved wall-clock or game-time calibration is required.",
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "Trait loss, player-object change, and duplicate load reset or preserve the correct transient panic baseline in deterministic tests.",
            "Current-build full relaunch and save/load remain unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "The current panic domain, Java spotted-list traversal, dead filtering, and six-argument addSound contract are statically verified.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The corrected code uses Kahlua-compatible scalar table state and verified receiver methods.",
            "Current-build Kahlua execution remains unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "The keyed periodic registry replaces reload closures and explicit tick unregistration leaves one handler.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "The post-bonus baseline prevents self-cascade while allowing a later external panic rise to trigger once.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables multiplayer and multiplayer is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Scaredy Cat."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English states the actual minute threshold, point domain, living-enemy threshold, update-based chance, and cooldown unit.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "confirmed-defect",
            "Cost and effect magnitudes are unchanged, but real-time scream frequency varies with update rate.",
            "User-approved calibration and live balance observation remain required.",
        ),
        "performance": HELPER._dimension(
            "confirmed-defect",
            "Living enemies use the shared tick cache, but eligibility and RNG still execute on every active player update.",
            "A user-approved fixed cadence and profiler capture remain required.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover one-shot cascade, fresh rises, cap, trait loss, duplicate load, living/dead thresholds, definition, English, and parity.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "Mocks preserve the 0-through-100 panic domain, 0-based Java list access, dead filtering, and deterministic RNG boundary.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Runtime, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All trait-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Scaredy Cat dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "confirmed-defect"

    for finding_id in RESOLVED_FINDINGS:
        finding = HELPER._exactly_one(row["findings"], "id", finding_id, relative)
        finding.update(
            resolution_state="proven-correct",
            resolution_evidence=(
                "The post-bonus baseline, exact minute-window English, reload-safe periodic registration, and focused regression cases statically prove this correction."
            ),
            missing_proof="",
            remaining_runtime_proof=(
                "Current-build full relaunch, in-game panic observation, save/load, and rendered English remain unobserved."
            ),
        )
    open_finding = HELPER._exactly_one(row["findings"], "id", OPEN_FINDING, relative)
    open_finding.update(
        resolution_state="confirmed-defect",
        resolution_evidence=(
            "The implementation and English now honestly expose update-based timing, but no user-approved replacement frequency exists."
        ),
        missing_proof="A user-approved frame-rate-independent scream cadence and cooldown calibration.",
        remaining_runtime_proof="Measure current player-update frequency and scream timing under representative load.",
    )
    row["unknowns"] = [
        "User decision: approved frame-rate-independent scream roll interval, probability, and cooldown duration.",
        "Current-build full relaunch, Kahlua execution, save/load, world sound, rendered English, and profiler observation remain unrun.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "static_regression": "UniversalTraits standard-Lua suite",
        "runtime_checks_unrun": [
            "game launch",
            "current-version save-load",
            "audible world sound",
            "update-frequency profiler capture",
        ],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment"],
    }
    replacements = {
        index: json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        for index, parsed in enumerate(rows)
        if parsed.get("trait_id") == TRAIT
    }
    plan[relative] = (
        "\n".join(replacements.get(index, line) for index, line in enumerate(lines)) + "\n"
    ).encode("utf-8")


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "confirmed-defect"
    row["independent_state"] = "confirmed-defect"
    row["supported_accepted_finding_ids"] = [*FINDINGS]
    row["repair_resolution"] = {
        "state": "partially-implemented-and-statically-validated",
        "resolved_finding_ids": [*RESOLVED_FINDINGS],
        "open_finding_ids": [OPEN_FINDING],
        "remaining_decision": (
            "User approval is required before replacing the accepted update-based scream cadence."
        ),
    }
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "source_english_sha256": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "release_english_sha256": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-scardycat-panic-lifecycle-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost -3; minute-window +15 panic cascade; 9-living-enemy update-based scream"
                ),
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": -3,
                "panic_threshold_points": 5,
                "panic_bonus_points": 15,
                "panic_cap": 100,
                "panic_interval": "EveryOneMinute",
                "living_enemy_threshold": 9,
                "scream_roll": "ZombRand(100) < 3 on each eligible player update",
                "scream_cooldown": "120 player updates",
                "world_sound": {"radius": 15, "volume": 15},
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*RESOLVED_FINDINGS],
            "open_findings": [OPEN_FINDING],
            "files": [
                HELPER._metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    SOURCE_UI,
                    RELEASE_UI,
                    SOURCE_DEFINITION,
                    RELEASE_DEFINITION,
                    TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "one bonus after one fresh panic rise",
                "no self-retrigger",
                "later external rise triggers once",
                "100-point cap",
                "trait-loss baseline reset",
                "duplicate load keeps one periodic and one tick handler",
                "living and dead enemy thresholds",
                "cost, exclusions, exact English, and source-release parity",
            ],
            "remaining_decision": (
                "Select a frame-rate-independent scream interval, probability, and cooldown before changing the accepted update-based timing."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build Kahlua, panic changes, trait loss, save/load, audible world sound, rendered English, update-frequency profiling, and balance observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing cost, exclusions, panic threshold, panic bonus, enemy threshold, or sound magnitude",
            ],
        }
    )


@contextmanager
def _configured_base() -> Iterator[None]:
    replacements = {
        "TRAIT": TRAIT,
        "FINDINGS": FINDINGS,
        "DESCRIPTION": DESCRIPTION,
        "RUNTIME": RUNTIME,
        "RELEASE": RELEASE,
        "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI,
        "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION,
        "MOCKS": MOCKS,
        "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT,
        "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS,
        "_plan_batch": _plan_batch,
        "_plan_review": _plan_review,
        "_plan_resolution": _plan_resolution,
    }
    originals = {name: getattr(base, name) for name in replacements}
    try:
        for name, value in replacements.items():
            setattr(base, name, value)
        yield
    finally:
        for name, value in originals.items():
            setattr(base, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with _configured_base():
        plan = base.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Scaredy Cat output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_scardycat.py")
    if cli_result is not None:
        return cli_result
    try:
        changed = commit_plan(build_plan())
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "trait_id": TRAIT, "changed": changed}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
