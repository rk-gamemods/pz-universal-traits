"""Regenerate only Wildsman campaign evidence and derived ledgers."""

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
TRAIT = "UniversalTraits:UT_wildsman"
FINDINGS = ("B12-WILDSMAN-001",)
DESCRIPTION = (
    "+1 to Plant Scavenging and Fishing. 30 percent more forage yield. "
    "Fish you catch weigh 50 percent more and provide 50 percent more nutrition."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_wildsman.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_wildsman.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/test_wildsman_runtime.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_wildsman.md"
RESOLUTION = "change-impact/wildsman-forage-fishing-contract.json"
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


def _d(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_12.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _d("proven-correct", "The registry, definition, runtime ID, and English keys agree."),
        "definition_parser": _d("runtime-unproven", "The complete source and release definitions are byte-identical and pass the standard-Lua consistency parser.", "Current-build ScriptManager loading remains unobserved."),
        "namespace": _d("proven-correct", "All owned surfaces use UniversalTraits:UT_wildsman."),
        "cost_xp_grants_exclusions": _d("proven-correct", "Cost is 4, Plant Scavenging and Fishing are +1, no grants or exclusions exist, and multiplayer is disabled."),
        "source_intent": _d("proven-correct", "Pre-campaign master fixes the outcome at 30 percent more forage yield and caught fish that are 50 percent larger with corresponding hunger benefit."),
        "runtime_path": _d("proven-correct", "The live trait check decorates vanilla forage item-count generation and the exact Fishing.Fish:createFish result without dead flags or fabricated events."),
        "numbers": _d("proven-correct", "The forage expectation is exactly 1.3 through whole-count plus fractional percentage, and every caught-fish size, weight, hunger, and nutrition field is multiplied once by 1.5."),
        "cadence": _d("proven-correct", "Work runs only inside vanilla forage count generation and fish construction; one OnGameStart retry handles class load order."),
        "cooldown": _d("not-applicable", "Wildsman has no cooldown."),
        "reset_save_load": _d("runtime-unproven", "Behavior uses live trait checks and no persisted setup flags, so it does not depend on one-time save state.", "Current-build new game, save load, death, and repeated world entry remain unobserved."),
        "java_lua": _d("proven-correct", "SVN 964 proves ISBaseIcon.initItemCount, ISForageIcon call order, getItemList count consumption, Fish.createFish fields, InventoryItem.setWorldScale, and the absence of InventoryItem.getWorldScale."),
        "kahlua": _d("runtime-unproven", "The correction uses Kahlua-compatible tables, numeric arithmetic, method wrappers, and verified receiver methods.", "Current-build Kahlua execution remains unobserved."),
        "events": _d("proven-correct", "One sentinel-protected OnGameStart installer replaces the nonexistent OnFishCaught path; method ownership guards prevent duplicate wrapping."),
        "stacking_interactions": _d("runtime-unproven", "Wildsman changes the produced item count and caught fish instance without writing shared multiplier state.", "Live order with other forage and food traits remains unobserved."),
        "multiplayer": _d("not-applicable", "The definition disables Wildsman in multiplayer and multiplayer support is an explicit product non-goal."),
        "display": _d("proven-correct", "The exact English display name is Wildsman."),
        "description": _d("proven-correct", "English states both +1 skills, 30 percent more forage yield, and 50 percent more caught-fish weight and nutrition."),
        "localization": _d("coverage-gap", "The exact English keys exist with source-release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _d("runtime-unproven", "Cost 4 and the exact 1.3 and 1.5 effects remain unchanged from the accepted contract.", "No gameplay telemetry or comparative balance session exists."),
        "performance": _d("runtime-unproven", "Both wrappers add constant work only to existing forage-count or fish-construction calls, with no polling or scans.", "No current-build profiler capture exists."),
        "tests": _d("proven-correct", "Four focused cases prove red reproduction, reload safety, exact integer and fractional yield boundaries, control behavior, current fish API shape, every 1.5 result, identity, and deduplication."),
        "mocks": _d("proven-correct", "The focused fish deliberately omits getWorldScale and the forage fixture invokes the exact vanilla item-count boundary."),
        "source_release_parity": _d("proven-correct", "Runtime, definition, and English source-release pairs are byte-identical."),
        "packaging": _d("coverage-gap", "All Wildsman-owned 42.0 runtime, definition, and English counterparts are present and identical.", "Read-only package verification still tracks the separate missing source poster."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Wildsman dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [
        RUNTIME,
        "PZCodebase/Lua/client/Foraging/ISBaseIcon.lua:440-478",
        "PZCodebase/Lua/client/Foraging/ISForageIcon.lua:122-183",
        "PZCodebase/Lua/shared/Fishing/Fish.lua:138-229",
        "PZCodebase/Java/source/zombie/inventory/InventoryItem.java:4483-4485",
        MOCKS,
        ACTIVE_AUDIT,
    ]
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        implementation_status="implemented-and-statically-validated",
        resolution_evidence="Current vanilla forage count and fish construction are decorated directly; focused tests fail against the dead/no-getter paths and pass against the corrected outcomes.",
        missing_proof="Current-build Kahlua and live forage/fishing remain unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Run UniversalTraits/test/test_wildsman_runtime.lua.",
    )
    row["unknowns"] = [
        "Current-build Kahlua, live forage, live fishing pickup and consumption, new game, save load, death, and repeated world entry remain unobserved.",
        "Live stacking order with other forage and food traits remains unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 ISBaseIcon.lua:440-478; ISForageIcon.lua:122-183; Fish.lua:138-229; InventoryItem.java:4483-4485",
        "focused_regression": "UniversalTraits/test/test_wildsman_runtime.lua: 4 passed, 0 failed",
        "runtime_checks_unrun": ["game launch", "new game and save load", "live forage", "live fishing pickup and consumption", "stacked traits", "profiler capture"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = ("\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n").encode("utf-8")


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row.update(
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        omission_disposition="resolved",
        supported_accepted_finding_ids=[*FINDINGS],
        verified_finding_ids=[*FINDINGS],
        repair_resolution={
            "state": "implemented-and-statically-validated",
            "resolved_finding_ids": [*FINDINGS],
            "open_finding_ids": [],
            "remaining_runtime_proof": "Current-build Kahlua, live forage/fishing, lifecycle, stacked traits, rendered English, balance, and profiler observation remain unrun.",
        },
        release_parity={
            "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
            "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
            "source_english_sha256": HELPER._metadata(root, SOURCE_UI)["sha256"],
            "release_english_sha256": HELPER._metadata(root, RELEASE_UI)["sha256"],
            "state": "proven-correct",
        },
        resolution_record=RESOLUTION,
    )
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION, TESTS, MOCKS, ACTIVE_AUDIT)
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-wildsman-forage-fishing-resolution-v1",
        "trait_id": TRAIT,
        "authority": {"accepted_baseline": "pre-campaign UTMods master", "accepted_contract": "cost 4, Plant Scavenging and Fishing +1, 30 percent more forage yield, and caught fish 50 percent larger with corresponding weight, hunger, and nutrition", "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json"},
        "accepted_intent": {"cost": 4, "forage_expected_multiplier": 1.3, "caught_fish_multiplier": 1.5, "runtime_scope": "single-player"},
        "resolved_findings": [*FINDINGS],
        "engine_evidence": ["PZCodebase/Lua/client/Foraging/ISBaseIcon.lua:440-478", "PZCodebase/Lua/client/Foraging/ISForageIcon.lua:122-183", "PZCodebase/Lua/shared/Fishing/Fish.lua:138-229", "PZCodebase/Java/source/zombie/inventory/InventoryItem.java:4483-4485", RUNTIME],
        "files": [HELPER._metadata(root, source) for source in files],
        "regression_cases": ["reload-safe installer and wrappers", "base-one 30 percent boundary", "base-four 20 percent remainder", "base-ten exact 13 count", "no-trait controls", "fish without getWorldScale", "all 1.5 fish fields", "original item identity", "same-item deduplication", "source-release parity"],
        "performance_model": "Constant work inside existing forage-count and fish-construction calls only; no polling, scans, or background work.",
        "runtime_proof": "Unobserved; requires full desktop relaunch, current-build Kahlua, representative live forage counts, caught-fish pickup and consumption, lifecycle, stacked traits, rendered English, balance, and profiler observation.",
        "non_goals": ["multiplayer", "backward save migration", "deployment", "changing cost, XP boosts, multipliers, or trait purpose"],
    })


@contextmanager
def _configured_base() -> Iterator[None]:
    replacements: dict[str, Any] = {
        "TRAIT": TRAIT, "FINDINGS": FINDINGS, "DESCRIPTION": DESCRIPTION,
        "RUNTIME": RUNTIME, "RELEASE": RELEASE, "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI, "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION, "MOCKS": MOCKS, "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT, "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS, "_plan_batch": _plan_batch,
        "_plan_review": _plan_review, "_plan_resolution": _plan_resolution,
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
        raise RuntimeError("Wildsman output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace: Callable[[str | Path, str | Path], None] = os.replace) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_wildsman.py")
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
