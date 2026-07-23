"""Regenerate only Strong and Nimble campaign evidence and derived ledgers."""

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
TRAIT = "UniversalTraits:UT_strongnimble"
FINDINGS = ("B11-STRONGNIMBLE-001",)
DESCRIPTION = (
    "+2 to Nimble, +1 to Strength. You do not suffer random falls while "
    "climbing fences or intact ropes."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_strongnimble.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_strongnimble.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_strongnimble.md"
RESOLUTION = "change-impact/strongnimble-climb-contract.json"
VERIFIER = "tools/verify_pz_api.py"
VERIFIER_TESTS = "tools/tests/test_verify_pz_api_contract.py"
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


def _d(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_11.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _d("proven-correct", "The registry, definition, runtime ID, and English keys agree."),
        "definition_parser": _d("runtime-unproven", "The complete source and release definitions are byte-identical and pass the standard-Lua consistency parser.", "Current-build ScriptManager loading remains unobserved."),
        "namespace": _d("proven-correct", "All owned surfaces use UniversalTraits:UT_strongnimble."),
        "cost_xp_grants_exclusions": _d("proven-correct", "Cost is 5, Nimble is +2, Strength is +1, no grants or exclusions exist, and multiplayer is disabled."),
        "source_intent": _d("runtime-unproven", "Pre-campaign master promises fence and rope fall protection. The shared proven subset is stochastic low-fence and intact-rope failure prevention.", "User decision remains required for the forced fall after physical rope removal."),
        "runtime_path": _d("proven-correct", "The active-only tick handler changes only the exact low-fence fall outcome and resets the intact-rope random-check timer before Java state execution."),
        "numbers": _d("proven-correct", "Nimble +2, Strength +1, cost 5, exact fall outcome, and zeroed rope timer match the accepted static contract."),
        "cadence": _d("proven-correct", "Every-update cadence is required because IsoPlayer fires OnPlayerUpdate before the climb states execute; work is active-trait-only and constant."),
        "cooldown": _d("not-applicable", "Strong and Nimble has no cooldown."),
        "reset_save_load": _d("runtime-unproven", "The handler uses live animation state and owns no persisted setup flags or modData.", "Current-build new game, save load, death, and repeated world entry remain unobserved."),
        "java_lua": _d("proven-correct", "SVN 964 proves the fence outcome matrix, IsoPlayer update order, both rope random branches, public climb timer methods, and inherited animation-variable interfaces."),
        "kahlua": _d("runtime-unproven", "The correction uses Kahlua-compatible conditionals and verified public receiver methods without Java method replacement.", "Current-build Kahlua execution remains unobserved."),
        "events": _d("proven-correct", "One central OnPlayerUpdate dispatcher replaces the nonexistent OnFenceClimb and OnClimbFence events."),
        "stacking_interactions": _d("runtime-unproven", "The handler changes only climb outcome or timer state and does not write shared multipliers.", "Live interaction with other movement traits remains unobserved."),
        "multiplayer": _d("not-applicable", "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal."),
        "display": _d("proven-correct", "The exact English display name is Strong and Nimble."),
        "description": _d("proven-correct", "English states both XP boosts and the currently implemented random fence and intact-rope protection."),
        "localization": _d("coverage-gap", "The exact English keys exist with source-release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _d("runtime-unproven", "Cost 5 and both XP boosts remain unchanged; the corrected static behavior restores value previously promised but not delivered.", "No gameplay telemetry or comparative balance session exists."),
        "performance": _d("runtime-unproven", "The active-only handler performs constant work with no scans, extra events, or background tasks.", "No current-build profiler capture exists."),
        "tests": _d("proven-correct", "Five focused cases prove red reproduction, exact fence conversion, slot-safe comparison, intact-rope reset, controls, outcome preservation, and trait gating; the full Lua suite passes 512 tests."),
        "mocks": _d("proven-correct", "Animation-variable mocks distinguish slot access from string comparison and model case-insensitive isVariable plus rope state and timer methods."),
        "source_release_parity": _d("proven-correct", "Runtime, definition, and English source-release pairs are byte-identical."),
        "packaging": _d("coverage-gap", "All trait-owned 42.0 runtime, definition, and English counterparts are present and identical.", "Read-only package verification still tracks the separate missing source poster."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Strong and Nimble dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [
        RUNTIME,
        "PZCodebase/Java/source/zombie/ai/states/ClimbOverFenceState.java:98-128,176-239,270-275",
        "PZCodebase/Java/source/zombie/ai/states/ClimbSheetRopeState.java:50-101",
        "PZCodebase/Java/source/zombie/ai/states/ClimbDownSheetRopeState.java:38-92,139-145",
        "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2019-2034,2241",
        "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:12975-13178,17169-17270",
        TESTS,
        ACTIVE_AUDIT,
    ]
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        implementation_status="implemented-and-statically-validated",
        resolution_evidence="Nonexistent fence events and broad fall cancellation were removed. Exact fence and intact-rope state inputs are changed before Java execution, and focused red tests now pass.",
        missing_proof="Current-build Kahlua and live fence/rope behavior remain unobserved; missing-rope semantics await user decision.",
        recommended_correction="No further static correction is indicated for stochastic fence or intact-rope failures.",
        smallest_regression_test="Run the Strong and Nimble filter in UniversalTraits/test/run_tests.lua.",
    )
    row["unknowns"] = [
        "User decision remains required for a physically removed rope.",
        "Current-build Kahlua, live fence and rope climbs, lifecycle, stacked traits, rendered English, balance, and profiler observation remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 ClimbOverFenceState.java:98-128,176-239,270-275; ClimbSheetRopeState.java:50-101; ClimbDownSheetRopeState.java:38-92,139-145; IsoPlayer.java:2019-2034,2241; IsoGameCharacter.java:12975-13178,17169-17270",
        "focused_regression": "Strong and Nimble filter: 5 passed, 0 failed",
        "affected_suite": "UniversalTraits/test/run_tests.lua: 512 passed, 0 failed",
        "api_verifier": "886 calls; 305 unique patterns; 0 warnings; 0 failures",
        "runtime_checks_unrun": ["game launch", "new game and save load", "live fence climbs", "live upward and downward rope climbs", "stacked traits", "profiler capture"],
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
        rejected_accepted_finding_ids=[],
        verified_finding_ids=[*FINDINGS],
        repair_resolution={
            "state": "implemented-and-statically-validated",
            "resolved_finding_ids": [*FINDINGS, "IR11-STRONGNIMBLE-001"],
            "open_finding_ids": [],
            "remaining_runtime_proof": "Current-build Kahlua, live fence/rope outcomes, lifecycle, stacked traits, rendered English, balance, and profiler observation remain unrun. Missing-rope semantics await user decision.",
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
    files = (
        RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION,
        RELEASE_DEFINITION, TESTS, MOCKS, ACTIVE_AUDIT, VERIFIER, VERIFIER_TESTS,
    )
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-strongnimble-climb-resolution-v1",
        "trait_id": TRAIT,
        "authority": {
            "accepted_baseline": "pre-campaign UTMods master",
            "accepted_contract": "cost 5, Nimble +2, Strength +1, and fence or rope fall protection",
            "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
        },
        "accepted_intent": {
            "cost": 5,
            "xp_boosts": {"Nimble": 2, "Strength": 1},
            "proven_runtime_scope": "stochastic low-fence failure and stochastic intact-rope failure",
            "pending_semantic_decision": "forced fall after physical rope removal",
            "product_scope": "single-player",
        },
        "resolved_findings": [*FINDINGS, "IR11-STRONGNIMBLE-001"],
        "engine_evidence": [
            "PZCodebase/Java/source/zombie/ai/states/ClimbOverFenceState.java:98-128,176-239,270-275",
            "PZCodebase/Java/source/zombie/ai/states/ClimbSheetRopeState.java:50-101",
            "PZCodebase/Java/source/zombie/ai/states/ClimbDownSheetRopeState.java:38-92,139-145",
            "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2019-2034,2241",
            "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:12975-13178,17169-17270",
            RUNTIME,
        ],
        "files": [HELPER._metadata(root, source) for source in files],
        "regression_cases": [
            "invalid slot-to-string comparison fails red",
            "exact low-fence fall becomes success",
            "all other fence outcomes remain unchanged",
            "ordinary falling state remains unchanged",
            "intact-rope timer resets to zero",
            "off-rope and no-trait controls remain unchanged",
            "source-release parity",
        ],
        "performance_model": "Constant work in one active-only every-update handler; no scans, extra event registrations, or background work.",
        "runtime_proof": "Unobserved; requires full desktop relaunch, current-build Kahlua, live low-fence and upward/downward rope cases, lifecycle, stacked traits, rendered English, balance, and profiler observation.",
        "non_goals": ["multiplayer", "backward save migration", "deployment", "changing cost, XP boosts, or trait purpose"],
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
        raise RuntimeError("Strong and Nimble output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace: Callable[[str | Path, str | Path], None] = os.replace) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_strongnimble.py")
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
