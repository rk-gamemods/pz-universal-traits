"""Regenerate only Heavy Bleeding Wounds campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_thickblood as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_heavilybleedingwounds"
FINDINGS = ("B05-HEAVYBLEED-001",)
DESCRIPTION = (
    "Even minor cuts refuse to close. Bleed rate is increased to 200 percent "
    "of normal - wounds bleed twice as fast."
)
RUNTIME = (
    "UniversalTraits/media/lua/shared/UniversalTraits/traits/"
    "UT_heavilybleedingwounds.lua"
)
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_heavilybleedingwounds.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
SOURCE_MET = "UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua"
RELEASE_MET = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/UT_MET.lua"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
CORE_HOOK = "UT_CORE/media/lua/shared/UTCore/UTCore_BleedDrainHook.lua"
CORE_HOOK_RELEASE = (
    "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_BleedDrainHook.lua"
)
CORE_STAT = "UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
CORE_STAT_RELEASE = (
    "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
)
CORE_TESTS = "UT_CORE/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_heavilybleedingwounds.md"
RESOLUTION = "change-impact/heavilybleedingwounds-met-resolution.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_05.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_05_08.json",
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
    relative = "trait_batches/batch_05.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": HELPER._dimension(
            "proven-correct",
            "The registry, complete definition, runtime key, and exact English keys agree.",
        ),
        "definition_parser": HELPER._dimension(
            "runtime-unproven",
            "The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": HELPER._dimension(
            "proven-correct",
            "All owned surfaces use UniversalTraits:UT_heavilybleedingwounds.",
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is -4, no XP or grants exist, Heavy Bleeding Wounds reciprocally excludes Thick Blood and Weakly Bleeding Wounds, and multiplayer is disabled.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master defines exactly twice the normal active-bleed general-health loss without changing bandaged wound healing.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "OnNewGame stores factor 2.0; the shared hook receives the native post-damage BLEEDING event and applies one additional identical BodyDamage distribution.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "The stored factor is exactly 2.0 and the hook adds damage times abs(1 - 2.0), producing two native-equivalent distributions before terminal clamping.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "Setup runs on new game and the effect runs only after native BLEEDING damage events, with no polling loop.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Heavy Bleeding Wounds has no random trigger or cooldown."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "The exact factor is stored in player modData and the event hook reads it for every bleed event.",
            "Current-build new-game, save-load, death, and repeated world entry remain unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves native bleed damage calls ReduceGeneralHealth before OnPlayerGetDamage and the shared factor-greater-than-one path invokes the same exposed BodyDamage method.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The trait and shared hook use Kahlua-compatible tables, arithmetic, guards, and directly verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "The normal module-load path registers setup once; the shared post-damage hook removes its prior closure before registering the current handler.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "All three bleed-rate traits are reciprocal script exclusions and now resolve through the same three-member UT_MET.BleedRate reference group.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables this trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Heavily Bleeding Wounds."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English states 200 percent of normal active-bleed loss and does not claim faster bandaged wound healing.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost -4 and exact 2.0 active-bleed factor.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "The factor-greater-than-one path performs one bounded BodyDamage call only after a native BLEEDING event.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests prove the exact 2.0 setup factor and make every member of the three-trait bleed group require every reciprocal definition edge.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "The trait mock preserves exact modData storage, while shared UT_CORE tests reproduce the post-native event and additional BodyDamage call.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Runtime, UT_MET, definition, and English pairs are byte-identical between source and the 42.0 release.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All trait-owned 42.0 runtime, metadata, definition, and English counterparts are present and identical.",
            "Read-only package verification still tracks the separate missing source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Heavy Bleeding Wounds dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "UT_MET.BleedRate now contains Thick Blood, Heavy Bleeding Wounds, and Weakly Bleeding Wounds. The focused consistency test proves every group member has both reciprocal script exclusions."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua, live bleeding, new game, save load, death, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua, new-game and save-load lifecycle, death, and repeated world entry remain unobserved.",
        "Live single-wound and simultaneous-wound terminal-clamp behavior remains unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": (
            "SVN 964 BodyPart.java:163-170; BodyDamage.java:1060-1072; "
            "LuaEventManager.java:823"
        ),
        "static_regression": ["UT_CORE standard-Lua suite", "UniversalTraits focused standard-Lua tests"],
        "runtime_checks_unrun": [
            "game launch",
            "new game and save load",
            "single and simultaneous bleeding wounds",
            "profiler capture",
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
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["supported_accepted_finding_ids"] = [*FINDINGS]
    row["verified_finding_ids"] = [*FINDINGS]
    row["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "resolved_finding_ids": [*FINDINGS],
        "open_finding_ids": [],
        "remaining_runtime_proof": (
            "Current-build Kahlua, live wounds, new game, save load, death, rendered English, balance, and profiler observation remain unrun."
        ),
    }
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "source_met_sha256": HELPER._metadata(root, SOURCE_MET)["sha256"],
        "release_met_sha256": HELPER._metadata(root, RELEASE_MET)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (
        RUNTIME,
        RELEASE,
        SOURCE_MET,
        RELEASE_MET,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        TESTS,
        CORE_HOOK,
        CORE_HOOK_RELEASE,
        CORE_STAT,
        CORE_STAT_RELEASE,
        CORE_TESTS,
        ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-heavilybleedingwounds-met-resolution-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost -4, exact 2.0 active-bleed general-health loss, no bandaged wound-healing change, and reciprocal exclusion from the other bleed-rate traits"
                ),
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": -4,
                "active_bleed_health_loss_factor": 2.0,
                "bandaged_wound_healing_change": False,
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:163-170",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1060-1072",
                "PZCodebase/Java/source/zombie/Lua/LuaEventManager.java:823",
                CORE_HOOK,
                CORE_STAT,
                RUNTIME,
            ],
            "files": [HELPER._metadata(root, source) for source in files],
            "regression_cases": [
                "exact 2.0 setup factor",
                "three-member UT_MET bleed group",
                "every bleed-group member has every reciprocal script exclusion",
                "shared factor-greater-than-one additional damage",
                "definition, English, and source-release parity",
            ],
            "performance_model": (
                "One bounded BodyDamage call after each native BLEEDING event while factor 2.0 is active; no polling or background scan."
            ),
            "runtime_proof": (
                "Unobserved; requires full desktop relaunch, current-build Kahlua, one and several simultaneous wounds, new game, save load, death, repeated world entry, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing cost, exclusions, magnitude, wound scope, or bandaged-wound behavior",
            ],
        }
    )


@contextmanager
def _configured_base() -> Iterator[None]:
    replacements: dict[str, Any] = {
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
        raise RuntimeError("Heavy Bleeding Wounds output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(
        sys.argv, "Usage: py -3 regenerate_heavilybleedingwounds.py"
    )
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
