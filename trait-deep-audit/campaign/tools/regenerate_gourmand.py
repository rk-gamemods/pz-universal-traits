"""Regenerate only Gourmand-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import regenerate_badteeth as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_gourmand"
FINDINGS = ("B04-gourmand-RESET", "B04-gourmand-RUNTIME")
RESET_FINDING = FINDINGS[0]
RUNTIME_FINDING = FINDINGS[1]
ITEM_MUTATION_FINDING = "XTF0104-FOOD-ITEM-MUTATION"
EXCLUSION_OMISSION = "IR0104-GOURMAND-RECIPROCAL-EXCLUSION"
DESCRIPTION = (
    "Food is one of life's great pleasures. Each meal grants +50 percent bonus hunger relief "
    "and reduces boredom and unhappiness by the same proportion."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_gourmand.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_gourmand.lua"
)
HOOK = "UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua"
HOOK_RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/"
    "UT_ItemConsumptionHooks.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_gourmand.md"
RESOLUTION = "change-impact/gourmand-consumption-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_04.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_01_04.json",
    "release_blocker_queue.json",
    RESOLUTION,
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "campaign_manifest.json",
)


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return base._dimension(state, evidence, missing) if missing else base._dimension(state, evidence)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_04.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = base._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _dimension(
            "proven-correct", "CharacterTrait.register uses the exact UniversalTraits:UT_gourmand id."
        ),
        "definition_parser": _dimension(
            "coverage-gap",
            "The complete source and release definitions parse in the accepted standard-Lua suite.",
            "Current-build ScriptManager parsing remains unobserved.",
        ),
        "namespace": _dimension(
            "proven-correct",
            "Registration, CharacterTrait, runtime id, and English keys use one exact namespace.",
        ),
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct",
            "Cost 4, no XP or grants, multiplayer disabled, and exact current exclusions are reciprocal.",
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Pinned pre-campaign and current evidence preserve exactly 50 percent extra beneficial hunger, boredom, and unhappiness relief proportional to actual native consumption.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "SVN 964 ISEatFoodAction complete and interrupted eat paths are wrapped once; native consumption runs first and Gourmand adds half of only the actual beneficial stat deltas.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "Each positive native relief delta receives an exact 0.5 multiplier bonus; harmful or zero changes receive no bonus.",
        ),
        "cadence": _dimension(
            "proven-correct",
            "Gourmand runs only on completed or interrupted positive consumption, with no inventory poll or tick handler.",
        ),
        "cooldown": _dimension("not-applicable", "No cooldown belongs to the accepted consumption contract."),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "The corrected path owns no food, player, or persistent baseline state; focused replacement and trait-removal cases prove no stale state is required.",
            "Full relaunch and current-version save-load remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct",
            "SVN 964 ISEatFoodAction complete/eat and Stats CharacterStat hunger, boredom, and unhappiness accessors are statically traced.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "Accepted source uses statically verified Kahlua-compatible wrapper and receiver shapes.",
            "Actual B42 Kahlua action execution remains unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "Stable shared sentinels keep complete/eat wrappers single across repeated module evaluation and world-start installation.",
        ),
        "stacking_interactions": _dimension(
            "proven-correct",
            "The hook composes around native consumption without mutating transferable food objects or modData and evaluates the current eater and trait state.",
        ),
        "multiplayer": _dimension(
            "not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."
        ),
        "display": _dimension("proven-correct", "The exact English display name is Gourmand."),
        "description": _dimension(
            "proven-correct",
            "English states the exact 50 percent proportional hunger, boredom, and unhappiness relief.",
        ),
        "localization": _dimension(
            "coverage-gap",
            "Exact English keys exist with source-release parity.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": _dimension(
            "runtime-unproven",
            "Cost 4 and the accepted 50 percent proportional beneficial relief remain unchanged.",
            "No gameplay balance session exists.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "The obsolete inventory poll is removed and work is bounded to actual consumption calls.",
            "No current-build profiler capture exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Eleven focused cases cover complete and partial consumption, exact deltas, guards, repeated bites, transfer/replacement, trait removal, duplicate load, failure safety, no persistent state, and source-release parity; full suite passes 576/576.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "Focused timed-action doubles execute native stat changes between before and after snapshots and cover current-player replacement without fabricated persistent state.",
        ),
        "source_release_parity": _dimension(
            "proven-correct",
            "Gourmand trait and shared-hook source/release runtime pairs are byte-identical.",
        ),
        "packaging": _dimension(
            "coverage-gap",
            "Gourmand-owned 42.0 runtime, English, definition, and registry counterparts are present.",
            "Package/live deployment remains unrun and the root poster.png is missing.",
        ),
    }
    if tuple(dimensions) != base.CANONICAL_DIMENSIONS:
        raise RuntimeError("Gourmand dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    reset = base._exactly_one(row["findings"], "id", RESET_FINDING, relative)
    reset.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "984ec687 replaced item mutation and persistent baselines with exact post-consumption stat deltas; focused 11/11, full 576/576, byte-identical runtime pairs, and independent ACCEPT prove the stale-baseline mechanism is gone."
        ),
        missing_proof="",
        remaining_runtime_proof="",
    )
    runtime = base._exactly_one(row["findings"], "id", RUNTIME_FINDING, relative)
    runtime.update(
        resolution_state="runtime-unproven",
        resolution_evidence=(
            "Static SVN 964 tracing and focused standard-Lua regression evidence prove the implemented complete and interrupted paths."
        ),
        missing_proof=(
            "Actual B42 Kahlua action execution, full relaunch, current-version save-load, balance, and profiler observation remain unrun."
        ),
        remaining_runtime_proof=(
            "Actual B42 Kahlua action execution, full relaunch, current-version save-load, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Actual B42 Kahlua action execution remains unobserved.",
        "Full desktop relaunch and current-version save-load remain unobserved.",
        "Gameplay balance and profiler behavior remain unobserved.",
        "No non-English UniversalTraits locale exists.",
        "Package/live deployment remains unrun and the root poster.png is missing.",
    ]
    row["validation"] = {
        "accepted_implementation_commit": "984ec687b4096d57296bfee1cbc2872e83e31215",
        "final_independent_review": "ACCEPT at 984ec687",
        "focused_lua_suite": "11/11",
        "full_lua_suite": "576/576",
        "runtime_pairs": "byte-identical",
        "runtime_checks_unrun": [
            "actual B42 Kahlua action execution",
            "full relaunch",
            "current-version save-load",
            "balance session",
            "profiler capture",
        ],
        "explicit_non_goals": ["multiplayer", "deployment", "rebalance"],
    }
    replacements = {
        index: json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        for index, parsed in enumerate(rows)
        if parsed.get("trait_id") == TRAIT
    }
    plan[relative] = (
        "\n".join(replacements.get(index, line) for index, line in enumerate(lines)) + "\n"
    ).encode("utf-8")


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (
        RUNTIME,
        RELEASE,
        HOOK,
        HOOK_RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        SOURCE_REGISTRY,
        RELEASE_REGISTRY,
        TESTS,
        ACTIVE_AUDIT,
    ):
        base._update_fingerprints(artifact, source, base._metadata(root, source))
    plan[relative] = base._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = base._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    proven = (
        "registration",
        "namespace",
        "cost_xp_grants_exclusions_and_bidirectional_exclusion_behavior",
        "source_mod_intent",
        "exact_runtime_path_through_ut_core_or_script_only_behavior",
        "numerical_behavior",
        "cadence",
        "cooldowns",
        "event_lifecycle",
        "stacking_and_cross_trait_interactions",
        "multiplayer_restriction",
        "display_name",
        "description_accuracy",
        "tests",
        "mocks",
        "source_release_parity",
    )
    for dimension_id in proven:
        base._checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence=(
                "Pinned intent, current source, SVN 964 static tracing, accepted focused tests, and independent review prove this exact static contract."
            ),
            missing_proof="",
        )
    base._checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="coverage-gap",
        evidence="The complete source/release definition parses in the accepted standard-Lua suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in (
        "reset_and_save_load",
        "java_lua_exposure",
        "kahlua_compatibility",
        "balance",
        "performance_risk",
    ):
        base._checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and focused regression evidence is complete for the implemented contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    base._checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source/release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    base._checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Gourmand-owned source/release content is exact.",
        missing_proof="Package/live deployment remains unrun and the root poster.png is missing.",
    )
    omission = base._exactly_one(row["omissions"], "id", EXCLUSION_OMISSION, relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=(
            "Current source and focused exact-membership assertions prove Competitive Eater and Gourmand exclusions in both directions."
        ),
        missing_proof="",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by the accepted exact reciprocal-exclusion assertion.",
    )
    mutation = base._exactly_one(
        artifact["cross_trait_findings"], "id", ITEM_MUTATION_FINDING, relative
    )
    expected_surfaces = [
        "UniversalTraits:UT_gordanite",
        TRAIT,
        "runtime",
        "item_state",
        "cross_player",
        "reset",
    ]
    corrected_surfaces = [
        "UniversalTraits:UT_gordanite",
        "runtime",
        "item_state",
        "cross_player",
        "reset",
    ]
    if mutation["affected_surfaces"] not in (expected_surfaces, corrected_surfaces):
        raise ValueError(f"{ITEM_MUTATION_FINDING} exact membership drifted")
    mutation["affected_surfaces"] = corrected_surfaces
    mutation["anchors"] = [
        anchor
        for anchor in mutation["anchors"]
        if anchor
        not in {
            "UniversalTraits/media/lua/shared/UniversalTraits/UT_gourmand.lua",
            "UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua:66-106",
        }
    ]
    mutation["reproduction_evidence"] = (
        "Gourmand no longer mutates shared food objects or modData. Gordanite remains affected and still requires its own exact correction."
    )
    mutation["partial_resolutions"] = {
        **mutation.get("partial_resolutions", {}),
        TRAIT: "implemented-and-statically-validated at 984ec687 with exact current-eater consumption deltas",
    }
    row.update(
        review_state="accepted",
        unresolved_proof=[
            "Actual B42 Kahlua action execution, full relaunch, and current-version save-load remain unobserved.",
            "Gameplay balance and profiler behavior remain unobserved.",
            "Only English UI localization exists.",
            "Package/live deployment remains unrun and the root poster.png is missing.",
        ],
        explicit_non_goals=["multiplayer", "deployment", "rebalance"],
        resolution_record=RESOLUTION,
    )
    row["release_parity"] = {
        "trait_runtime": base._metadata(root, RUNTIME)["sha256"],
        "trait_release": base._metadata(root, RELEASE)["sha256"],
        "hook_runtime": base._metadata(root, HOOK)["sha256"],
        "hook_release": base._metadata(root, HOOK_RELEASE)["sha256"],
        "definition_runtime": base._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": base._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": base._metadata(root, SOURCE_UI)["sha256"],
        "english_release": base._metadata(root, RELEASE_UI)["sha256"],
        "registry_runtime": base._metadata(root, SOURCE_REGISTRY)["sha256"],
        "registry_release": base._metadata(root, RELEASE_REGISTRY)["sha256"],
        "tests": base._metadata(root, TESTS)["sha256"],
        "state": "proven-correct",
    }
    plan[relative] = base._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (
        RUNTIME,
        RELEASE,
        HOOK,
        HOOK_RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        SOURCE_REGISTRY,
        RELEASE_REGISTRY,
        TESTS,
        ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = base._json_bytes(
        {
            "schema": "ut-gourmand-consumption-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_implementation_commit": "984ec687b4096d57296bfee1cbc2872e83e31215",
                "accepted_parent": "914efed64ed0d8af7e75d61ddb5df9331c96dbc1",
                "pz_snapshot": "SVN revision 964",
                "final_independent_review": {
                    "verdict": "ACCEPT",
                    "snapshot": "984ec687",
                    "focused_cases": 11,
                    "full_cases": 576,
                    "blocking_findings": 0,
                },
            },
            "accepted_intent": {
                "cost": 4,
                "bonus_fraction": 0.5,
                "applies_to": ["beneficial hunger relief", "beneficial boredom relief", "beneficial unhappiness relief"],
                "basis": "actual native consumption delta",
                "english": DESCRIPTION,
            },
            "runtime_contract": {
                "completed_path": "SVN 964 ISEatFoodAction.complete",
                "partial_path": "SVN 964 ISEatFoodAction.eat",
                "native_order": "snapshot before, native exactly once, compare after, then apply eligible bonus",
                "persistent_baseline": False,
                "food_mutation": False,
                "food_moddata": False,
                "duplicate_load_safe": True,
            },
            "resolved_findings": [RESET_FINDING, EXCLUSION_OMISSION],
            "retained_runtime_finding": RUNTIME_FINDING,
            "partially_resolved_cross_findings": [ITEM_MUTATION_FINDING],
            "regression_cases": [
                "exact completed meal deltas",
                "exact interrupted partial-consumption deltas",
                "repeated bites without compounding",
                "zero, harmful, non-food, and missing-trait guards",
                "current eater across transfer and replacement",
                "trait removal and replacement without persistent state",
                "duplicate module evaluation",
                "snapshot failure preserves native consumption",
                "no polling, item mutation, item modData, player modData, or retained baseline",
                "exact English contract",
                "source-release runtime parity",
            ],
            "files": [base._metadata(root, source) for source in files],
            "retained_runtime_proof": [
                "actual B42 Kahlua action execution",
                "full desktop relaunch",
                "current-version save-load",
                "gameplay balance session",
                "profiler/performance capture",
                "non-English localization if required",
                "package/live deployment",
                "missing root poster.png",
            ],
            "runtime_proof": (
                "Unobserved; static and standard-Lua evidence do not establish live current-build gameplay."
            ),
            "non_goals": ["multiplayer", "deployment", "rebalance"],
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
        "HOOK": HOOK,
        "HOOK_RELEASE": HOOK_RELEASE,
        "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI,
        "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION,
        "MOCKS": TESTS,
        "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT,
        "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS,
        "_plan_batch": _plan_batch,
        "_plan_inventory": _plan_inventory,
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
        raise RuntimeError("Gourmand output plan escaped its ownership set")
    plan["translation_audit.json"] = plan["translation_audit.json"].replace(
        "\N{EM DASH}".encode("utf-8"),
        b" - ",
    )
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace=base.os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Gourmand output set")
    original = base.OWNED_OUTPUTS
    try:
        base.OWNED_OUTPUTS = OWNED_OUTPUTS
        return base.commit_plan(plan, campaign, replace)
    finally:
        base.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_gourmand.py")
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
