"""Regenerate only Weakly Bleeding Wounds campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_heavilybleedingwounds as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_weaklybleedingwounds"
FINDINGS = (
    "IR12-WEAKBLEED-DESC-001",
    "IR12-WEAKBLEED-POOL-002",
    "IR11-BLEED-POOL-001",
)
DESCRIPTION = (
    "Active bleeding drains your health at 60 percent of the normal rate. "
    "Wound clotting speed is unchanged."
)
RUNTIME = (
    "UniversalTraits/media/lua/shared/UniversalTraits/traits/"
    "UT_weaklybleedingwounds.lua"
)
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_weaklybleedingwounds.lua"
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
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_weaklybleedingwounds.md"
RESOLUTION = "change-impact/weaklybleedingwounds-bodydamage-resolution.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_12.jsonl",
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
    relative = "trait_batches/batch_12.jsonl"
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
            "All owned surfaces use UniversalTraits:UT_weaklybleedingwounds.",
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is 3, no XP or grants exist, the trait reciprocally excludes Heavy Bleeding Wounds and Thick Blood, and multiplayer is disabled.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master defines exactly 0.6x active-bleed general-health loss without changing clotting or bandaged healing.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "OnNewGame stores factor 0.6; after each native BLEEDING event, the shared hook exactly inverts 40 percent of every unclamped native BodyDamage share.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "The stored factor is exactly 0.6. The inverse is damage times 0.4 divided by native part count and the same per-part damage modifier.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "Setup runs on new game and correction runs once after each native BLEEDING damage event, with no tick approximation or polling loop.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Weakly Bleeding Wounds has no random trigger or cooldown."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "The exact factor is stored in player modData and the event hook reads it for every bleed event.",
            "Current-build new-game, save-load, death, and repeated world entry remain unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves native bleed ordering, the BodyDamage distribution, 0-based body-part access, exact damage modifiers, bounded AddHealth, and BodyPartType Lua exposure.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible numeric loops, tables, pcall guards, and directly verified Java receiver and static methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "The normal module-load path registers setup once; the shared post-damage hook removes its prior closure before registering the current handler.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "All three bleed-rate traits are reciprocal script exclusions and resolve through the same three-member UT_MET.BleedRate group.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables this trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Weakly Bleeding Wounds."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English states 60 percent of normal active-bleed general-health loss and explicitly says clotting speed is unchanged.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost 3 and exact 0.6 active-bleed factor.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "Each native bleed event performs one validated bounded pass over the fixed body-part list only while factor 0.6 is active.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact setup, English, parity, weighted inverse math, zero-health non-healing, invalid plans, finite domains, and reload-safe registration.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "Mocks expose the 0-based body-part list, unequal damage modifiers, per-part health and AddHealth, and the exact post-native event payload.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Runtime, UT_MET, definition, English, and changed shared-hook pairs are byte-identical between source and the 42.0 release.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All trait-owned 42.0 runtime, metadata, definition, and English counterparts are present and identical.",
            "Read-only package verification still tracks the separate missing source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Weakly Bleeding Wounds dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
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
            "SVN 964 BodyPart.java:163-170,509-519; BodyDamage.java:1060-1072; "
            "BodyPartType.java:1-276; LuaManager.java:1755"
        ),
        "static_regression": ["UT_CORE standard-Lua suite", "UniversalTraits standard-Lua suite"],
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


def _resolve_finding(finding: dict[str, Any], evidence: str) -> None:
    finding.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=evidence,
        missing_proof="Current-build Kahlua and live bleeding remain unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by the focused weighted BodyDamage and English contract tests.",
    )


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    shared = HELPER._exactly_one(
        artifact["cross_trait_findings"], "id", FINDINGS[2], relative
    )
    _resolve_finding(
        shared,
        "The shared hook now corrects BodyDamage directly, exactly inverts each unclamped native share, and never uses actor health. Unequal-modifier tests fail against the old pool path.",
    )

    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["omission_disposition"] = "resolved"
    description = HELPER._exactly_one(row["omissions"], "id", FINDINGS[0], relative)
    _resolve_finding(
        description,
        "English now states 60 percent active-bleed general-health loss and explicitly says clotting speed is unchanged.",
    )
    pool = HELPER._exactly_one(row["omissions"], "id", FINDINGS[1], relative)
    _resolve_finding(
        pool,
        "The factor-below-one path now restores exact BodyDamage shares with native modifiers and skips ambiguous zero-health clamps.",
    )
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
        "source_english_sha256": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "release_english_sha256": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "source_core_hook_sha256": HELPER._metadata(root, CORE_HOOK)["sha256"],
        "release_core_hook_sha256": HELPER._metadata(root, CORE_HOOK_RELEASE)["sha256"],
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
            "schema": "ut-weaklybleedingwounds-bodydamage-resolution-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost 3, exact 0.6 active-bleed general-health loss, unchanged clotting and bandaged healing, and reciprocal exclusion from the other bleed-rate traits"
                ),
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 3,
                "active_bleed_health_loss_factor": 0.6,
                "clotting_change": False,
                "bandaged_wound_healing_change": False,
                "isolated_bleed_survival_time_factor": "1 / 0.6 = 1.6667",
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:163-170,509-519",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1060-1072",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPartType.java:1-276",
                "PZCodebase/Java/source/zombie/Lua/LuaManager.java:1755",
                CORE_HOOK,
                CORE_STAT,
                RUNTIME,
            ],
            "files": [HELPER._metadata(root, source) for source in files],
            "regression_cases": [
                "exact 0.6 setup factor",
                "exact English active-bleed and unchanged-clotting contract",
                "three-member reciprocal bleed group",
                "exact unequal-weight BodyDamage restoration",
                "zero-health body parts are never healed",
                "complete inverse-plan validation before mutation",
                "invalid and non-finite input rejection",
                "reload-safe shared event registration",
                "source-release parity",
            ],
            "performance_model": (
                "One bounded pass over the fixed body-part list per native BLEEDING event while factor 0.6 is active; no background scan or tick approximation."
            ),
            "runtime_proof": (
                "Unobserved; requires full desktop relaunch, current-build Kahlua, one and several simultaneous wounds, new game, save load, death, repeated world entry, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing cost, exclusions, magnitude, wound scope, or clotting behavior",
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
        raise RuntimeError("Weakly Bleeding Wounds output plan escaped its ownership set")
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
        sys.argv, "Usage: py -3 regenerate_weaklybleedingwounds.py"
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
