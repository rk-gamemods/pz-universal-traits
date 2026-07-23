"""Regenerate only Thick Blood-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_sharpshooter as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_thickblood"
FINDINGS = (
    "B11-THICKBLOOD-BLEED-STACK-001",
    "IR11-THICKBLOOD-001",
)
DESCRIPTION = (
    "Your blood clots unusually fast. BleedingTime decays 1.5x faster "
    "(wounds clot faster) and active bleed death rate is reduced to 50 percent of normal."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_thickblood.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_thickblood.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_thickblood.md"
RESOLUTION = "change-impact/thickblood-weighted-bleed-damage.json"
CORE_HOOK = "UT_CORE/media/lua/shared/UTCore/UTCore_BleedDrainHook.lua"
CORE_HOOK_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_BleedDrainHook.lua"
CORE_DECAY = "UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua"
CORE_DECAY_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua"
CORE_STAT = "UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
CORE_STAT_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
CORE_MOCKS = "UT_CORE/test/UTCoreMocks.lua"
CORE_TESTS = "UT_CORE/test/run_tests.lua"
CORE_API_TESTS = "UT_CORE/test/test_pz_api_surface.lua"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl",
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
    relative = "trait_batches/batch_11.jsonl"
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
            "The complete source and release definitions are byte-identical and parse in the standard-Lua suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": HELPER._dimension(
            "proven-correct", "All owned surfaces use UniversalTraits:UT_thickblood."
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is 4, no XP or grants exist, Heavy Bleeding Wounds, Weak Bleeding Wounds, and Anemic are reciprocal exclusions, and multiplayer is disabled.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master defines 1.5x all-wound bleed-time decay and 0.5x active-bleed general-health loss.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "OnNewGame stores exact factors; the decay hook composes named factors; the drain hook consumes the native post-damage event and inverts each unclamped BodyDamage share or extends the native distribution.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "Factors are exactly 1.5 and 0.5. Native ReduceGeneralHealth divides by part count and damage modifier; the correction uses that inverse for positive-health parts and skips ambiguous zero-health clamps.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "Decay applies at the existing bounded ten-update cadence; drain correction runs only after a native BLEEDING damage event.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Thick Blood has no random trigger or cooldown."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "New-game setup writes persistent modData and named Staunch ownership no longer overwrites the Thick Blood factor.",
            "Current-build new-game, save-load, death, and repeated world entry remain unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves native bleed ordering, event damage, 0-based body-part access, damage modifiers, bounded body-part health methods, and explicit BodyPartType Kahlua exposure.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible numeric loops, tables, pcall boundaries, and verified Java receiver and static methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "The native event fires after exact ReduceGeneralHealth application, and reload replaces the prior Lua handler before adding one current handler.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "Thick Blood remains 1.5x on all wounds and multiplies Staunch's independent 3.0 bandaged factor to 4.5x while bandaged.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables Thick Blood in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Thick Blooded."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English separately states 1.5x BleedingTime decay and 50 percent active-bleed death rate.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost 4, 1.5 decay factor, and 0.5 active-bleed health-loss factor.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "Each native bleed event performs one validated bounded pass over the fixed body-part list only when the multiplier differs from 1.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact setup factors, weighted inverse math, zero-health non-healing, extra damage, invalid plans, finite domains, Staunch composition, teardown, and parity.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "Mocks expose the 0-based body-part list, unequal damage modifiers, per-part health and AddHealth, and the exact post-native event payload.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Thick Blood runtime and changed UT_CORE runtime pairs are byte-identical between source and 42.0 release.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All Thick Blood-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification still tracks the separate missing source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Thick Blood dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Thick Blood and Staunch now own independent multiplicative decay factors. Focused tests prove 4.5x bandaged, 1.5x unbandaged, and Staunch removal without Thick Blood loss."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua, live wounds, new game, save load, death, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua, new-game and save-load lifecycle, death, and repeated world entry remain unobserved.",
        "Live single-wound and simultaneous-wound weighted health behavior remains unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": (
            "SVN 964 BodyPart.java:163-170,509-519; BodyDamage.java:1040-1072,2465-2479; "
            "BodyPartType.java:1-276; LuaManager.java:1755,2677-2685"
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


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    omission = HELPER._exactly_one(row["omissions"], "id", FINDINGS[1], relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=(
            "The correction now stays in BodyDamage and inverts each unclamped native ReduceGeneralHealth share using the engine's damage modifiers. Zero-health parts are not healed. Weighted regression assertions fail against both the old actor-health path and uniform AddGeneralHealth."
        ),
        missing_proof="Current-build Kahlua and live bleeding remain unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by the exact unequal-weight restoration case.",
    )
    row["supported_accepted_finding_ids"] = [FINDINGS[0]]
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
        "source_core_hook_sha256": HELPER._metadata(root, CORE_HOOK)["sha256"],
        "release_core_hook_sha256": HELPER._metadata(root, CORE_HOOK_RELEASE)["sha256"],
        "source_core_stat_sha256": HELPER._metadata(root, CORE_STAT)["sha256"],
        "release_core_stat_sha256": HELPER._metadata(root, CORE_STAT_RELEASE)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (
        RUNTIME,
        RELEASE,
        CORE_HOOK,
        CORE_HOOK_RELEASE,
        CORE_DECAY,
        CORE_DECAY_RELEASE,
        CORE_STAT,
        CORE_STAT_RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        MOCKS,
        TESTS,
        CORE_MOCKS,
        CORE_TESTS,
        CORE_API_TESTS,
        ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-thickblood-weighted-bleed-damage-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost 4, 1.5x all-wound BleedingTime decay, 0.5x active-bleed general-health loss, and 4.5x bandaged composition with Staunch"
                ),
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 4,
                "bleed_decay_factor": 1.5,
                "active_bleed_health_loss_factor": 0.5,
                "staunch_combined_bandaged_factor": 4.5,
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:163-170,509-519",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1040-1072,2465-2479",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPartType.java:1-276",
                "PZCodebase/Java/source/zombie/Lua/LuaManager.java:1755,2677-2685",
                CORE_HOOK,
                CORE_DECAY,
                CORE_STAT,
                RUNTIME,
            ],
            "files": [HELPER._metadata(root, source) for source in files],
            "regression_cases": [
                "exact 1.5 and 0.5 setup factors",
                "exact unequal-weight BodyDamage restoration",
                "zero-health body parts are never healed",
                "exact additional damage above factor 1",
                "full inverse-plan validation before mutation",
                "invalid and non-finite input rejection",
                "exact 4.5 bandaged and 1.5 unbandaged Staunch composition",
                "Staunch teardown preserving Thick Blood",
                "required Java-Lua bridge surface",
                "source-release parity",
            ],
            "performance_model": (
                "One bounded pass over the fixed body-part list per native BLEEDING event while the multiplier differs from 1; no background scan or new event source."
            ),
            "runtime_proof": (
                "Unobserved; requires full desktop relaunch, current-build Kahlua, one and several simultaneous unbandaged wounds, new game, save load, death, repeated world entry, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing Thick Blood cost, exclusions, magnitude, wound scope, or intended Staunch interaction",
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
        raise RuntimeError("Thick Blood output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_thickblood.py")
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
