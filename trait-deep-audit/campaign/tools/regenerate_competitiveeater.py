"""Regenerate only Competitive Eater-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_anorexy as shared
from build_final_trait_ledger import CANONICAL_DIMENSIONS
from campaign_cli import no_arg_command
from regenerate_brittle import _checked_dimension, _dimension, _materialize
from regenerate_immuneresponse import _exactly_one, _json_bytes, _metadata, _update_fingerprints


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_competitiveeater"
FINDINGS = ("B03-UT_competitiveeater-01", "B03-UT_competitiveeater-02")
OMISSIONS = (
    "IR0104-COMPETITIVEEATER-MEAL-DETECTION",
    "IR0104-COMPETITIVEEATER-RECIPROCAL-EXCLUSION",
    "IR0104-COMPETITIVEEATER-UNTHROTTLED-POLL",
)
POLLING_FINDING = "XTF0104-EATING-EDGE-POLLING"
EXCLUSION_FINDING = "XTF0104-EXCLUSION-CONTRACT"
MOCK_FINDING = "XTF0104-MOCK-ENGINE-DOMAINS"
DESCRIPTION = (
    "You eat with purpose and efficiency. Each time you eat, boredom decreases by 10 points "
    "and hunger decreases by 0.05 (5 percent of the hunger meter)."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_competitiveeater.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_competitiveeater.lua"
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
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_competitiveeater.md"
RESOLUTION = "change-impact/competitiveeater-consumption-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_03.jsonl",
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


def _old_dimension(dimensions: dict[str, Any], canonical: str, legacy: str | None = None) -> dict[str, Any]:
    for key in (canonical, legacy):
        if key is not None and key in dimensions:
            return dimensions[key]
    raise KeyError(f"missing Competitive Eater dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_03.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": _dimension(
            "coverage-gap",
            "The complete definition is parsed by the standard-Lua consistency suite and source/release blocks match.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct",
            "Cost remains 3, no XP or grants are added, and Anorexy/Gourmand exclusions are reciprocal in source and release.",
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Pre-campaign master plus e87e49d, 16e1f1e, and be6eed18 establish the accepted per-eating-event effect and symmetric Gourmand exclusion without importing unrelated behavior.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "The shared item-consumption module runs native complete/eat first, then applies Competitive Eater once for positive completed or interrupted consumption. The trait file owns no poll.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "Each positive consumption event removes exactly 10 boredom points and 0.05 hunger after native food effects, with both values bounded at zero.",
        ),
        "cadence": _dimension(
            "proven-correct",
            "Work is bounded to actual completed or interrupted consumption calls; player updates do not execute Competitive Eater logic.",
        ),
        "cooldown": _dimension(
            "proven-correct", "No cooldown is part of the accepted one-effect-per-consumption contract."
        ),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "The correction owns no persistent trait state and unregisters the obsolete polling handler.",
            "Current-version in-game save/load and repeated world entry remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct",
            "SVN 964 exposes ISEatFoodAction.complete/eat, IsoGameCharacter.Eat, Stats.get/set, and the verified boredom and hunger domains used by the implementation.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua and verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "Stable sentinels keep complete/eat wrappers single across repeated installation, and the obsolete tick registration is removed.",
        ),
        "stacking_interactions": _dimension(
            "proven-correct",
            "Competitive Eater composes independently with other post-consumption effects, mutates no item, and is reciprocally exclusive with Anorexy and Gourmand.",
        ),
        "multiplayer": _dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": _dimension("proven-correct", "The exact English display name is Competitive Eater."),
        "description": _dimension(
            "proven-correct",
            "The English copy states the eating trigger, 10-point boredom relief, 0.05 hunger relief, and 5 percent hunger-meter interpretation.",
        ),
        "localization": _dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": _dimension(
            "runtime-unproven",
            "Static behavior is cost 3, 10 boredom relief, and 0.05 hunger relief per positive food-consumption event.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "The per-update poll was removed. The shared hook adds one trait lookup per actual food-consumption call and two reads/writes only for an active Competitive Eater player.",
            "No current-build profiler capture exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Focused tests cover exact completed and interrupted behavior, ordering, bounds, zero/no-trait no-ops, no polling, shared-wrapper composition, exclusions, English copy, and parity.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "Timed-action mocks separate complete and eat, allow native effects before assertions, and tests prove explicit boredom/hunger bounds without relying on mock clamping.",
        ),
        "source_release_parity": _dimension(
            "proven-correct", "Runtime, shared hook, definition, and English source/release pairs are byte-identical."
        ),
        "packaging": _dimension(
            "coverage-gap",
            "All Competitive Eater-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
        ),
    }
    if tuple(dimensions) != CANONICAL_DIMENSIONS:
        raise RuntimeError("Competitive Eater dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    for finding_id in FINDINGS:
        finding = _exactly_one(row["findings"], "id", finding_id, relative)
        finding["resolution_state"] = "proven-correct"
        finding["resolution_evidence"] = (
            "The accepted effect now runs once after actual positive food consumption, uses the verified 0.05 hunger scale, preserves 10-point boredom relief, and has exact English coverage."
        )
        finding["remaining_runtime_proof"] = (
            "Current-build Kahlua execution after a full relaunch, current-version save/load, rendered English, and profiler observation remain unrun."
        )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 ISEatFoodAction.lua:126-176,193-201; IsoGameCharacter.java:6380-6507; CharacterStat.java:11-33; Stats.java:74-87",
        "static_regression": "UniversalTraits standard-Lua suite",
        "runtime_checks_unrun": ["game launch", "current-version save-load", "profiler capture"],
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
        TESTS,
        ACTIVE_AUDIT,
    ):
        _update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = _json_bytes(artifact)


def _cross_finding(artifact: dict[str, Any], finding_id: str, relative: str) -> dict[str, Any]:
    return _exactly_one(artifact["cross_trait_findings"], "id", finding_id, relative)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    for dimension_id in (
        "registration",
        "namespace",
        "cost_xp_grants_exclusions_and_bidirectional_exclusion_behavior",
        "source_mod_intent",
        "exact_runtime_path_through_ut_core_or_script_only_behavior",
        "numerical_behavior",
        "cadence",
        "cooldowns",
        "java_lua_exposure",
        "event_lifecycle",
        "stacking_and_cross_trait_interactions",
        "multiplayer_restriction",
        "display_name",
        "description_accuracy",
        "tests",
        "mocks",
        "source_release_parity",
    ):
        _checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence="Pre-campaign Git authority, current source, SVN 964 consumption/stat evidence, and focused regression tests prove this static contract.",
            missing_proof="",
        )
    _checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="runtime-unproven",
        evidence="The complete source/release definition is parsed by the standard-Lua consistency suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        _checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and regression evidence is complete for the implemented contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    _checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source/release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    _checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Competitive Eater-owned source/release content is exact.",
        missing_proof="UniversalTraits package verification remains blocked by the separately tracked missing source poster.",
    )

    omission_evidence = {
        OMISSIONS[0]: "Completed actions use ISEatFoodAction.complete after character:Eat; interrupted partial actions use ISEatFoodAction.eat after its effective-fraction Eat call.",
        OMISSIONS[1]: "Competitive Eater and Gourmand now list each other in source and release, and focused parser assertions prove both directions.",
        OMISSIONS[2]: "Competitive Eater owns no tick handler and focused tests prove player updates neither change stats nor write stale timer state.",
    }
    for omission_id, evidence in omission_evidence.items():
        omission = _exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=evidence,
            missing_proof="Current-build in-game observation remains unrun.",
            recommended_correction="No further static correction is indicated.",
            smallest_regression_test="Covered by the focused Competitive Eater regression cases.",
        )

    polling = _cross_finding(artifact, POLLING_FINDING, relative)
    polling["anchors"] = [anchor for anchor in polling["anchors"] if "UT_competitiveeater.lua" not in anchor]
    polling["affected_surfaces"] = [surface for surface in polling["affected_surfaces"] if surface != TRAIT]
    polling["reproduction_evidence"] = (
        "Anorexy and Competitive Eater are resolved through exact post-consumption hooks. Ascetic and Bad Teeth retain healthFromFoodTimer paths that miss ordinary partial meals or depend on special healing conditions."
    )
    polling["partial_resolutions"] = {
        **polling.get("partial_resolutions", {}),
        TRAIT: "implemented-and-statically-validated through completed and interrupted post-consumption wrappers",
    }

    exclusion = _cross_finding(artifact, EXCLUSION_FINDING, relative)
    exclusion["anchors"] = [
        anchor
        for anchor in exclusion["anchors"]
        if not anchor.endswith(":1602") and not anchor.endswith(":2019")
    ]
    exclusion["affected_surfaces"] = [
        surface
        for surface in exclusion["affected_surfaces"]
        if surface not in {TRAIT, "UniversalTraits:UT_gourmand"}
    ]
    exclusion["reproduction_evidence"] = (
        "Competitive Eater and Gourmand are now reciprocal. Other reviewed custom/vanilla edges and the undocumented Albino/Bad Teeth and Couch Dweller questions remain open."
    )
    exclusion["partial_resolutions"] = {
        **exclusion.get("partial_resolutions", {}),
        "Competitive Eater <-> Gourmand": "implemented-and-statically-validated in both selection directions",
    }

    mock_finding = _cross_finding(artifact, MOCK_FINDING, relative)
    mock_finding["affected_surfaces"] = [
        surface for surface in mock_finding["affected_surfaces"] if surface != TRAIT
    ]
    mock_finding["partial_resolutions"] = {
        **mock_finding.get("partial_resolutions", {}),
        TRAIT: "Competitive Eater explicitly clamps the 0 to 1 hunger domain and 0 to 100 boredom domain; focused boundary tests do not rely on mock add/set clamping.",
    }

    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": _metadata(root, RUNTIME)["sha256"],
        "trait_release": _metadata(root, RELEASE)["sha256"],
        "hook_runtime": _metadata(root, HOOK)["sha256"],
        "hook_release": _metadata(root, HOOK_RELEASE)["sha256"],
        "definition_runtime": _metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": _metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": _metadata(root, SOURCE_UI)["sha256"],
        "english_release": _metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = _json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-competitiveeater-consumption-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "original_event_implementation": "e87e49d",
                "build_42_migration_with_defects": "16e1f1e",
                "symmetric_exclusion_declaration": "be6eed18",
            },
            "accepted_intent": {
                "cost": 3,
                "trigger": "each completed or interrupted positive food-consumption event",
                "boredom_relief": 10,
                "hunger_relief": 0.05,
                "lower_bound": 0,
                "exclusions": ["UniversalTraits:UT_anorexy", "UniversalTraits:UT_gourmand"],
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS, *OMISSIONS],
            "partially_resolved_cross_findings": [
                POLLING_FINDING,
                EXCLUSION_FINDING,
                MOCK_FINDING,
            ],
            "engine_evidence": [
                "PZCodebase/Lua/shared/TimedActions/ISEatFoodAction.lua:126-176,193-201",
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6380-6507",
                "PZCodebase/Java/source/zombie/characters/CharacterStat.java:11-33",
                "PZCodebase/Java/source/zombie/characters/Stats.java:74-87",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:617-635",
            ],
            "files": [
                _metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    HOOK,
                    HOOK_RELEASE,
                    SOURCE_UI,
                    RELEASE_UI,
                    SOURCE_DEFINITION,
                    RELEASE_DEFINITION,
                    TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "exact completed post-native boredom and hunger relief",
                "exact interrupted partial-consumption relief",
                "zero bounds",
                "zero consumption and no-trait no-op",
                "no player-update polling, stale mod data, or tick handler",
                "perform alone is not consumption",
                "shared Anorexy wrapper composition without double application",
                "reciprocal Gourmand exclusion",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "No new loop or handler is added. One trait lookup occurs per actual food-consumption call, followed by two stat reads and writes only for an active Competitive Eater player."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build completed and interrupted food observation, repeated world entry, current-version save/load, rendered English, and profiler capture."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment"],
        }
    )


@contextmanager
def _configured_shared() -> Iterator[None]:
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
        "MOCKS": MOCKS,
        "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT,
        "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS,
        "_plan_batch": _plan_batch,
        "_plan_inventory": _plan_inventory,
        "_plan_review": _plan_review,
        "_plan_blocker": _plan_blocker,
        "_plan_resolution": _plan_resolution,
    }
    originals = {name: getattr(shared, name) for name in replacements}
    try:
        for name, value in replacements.items():
            setattr(shared, name, value)
        yield
    finally:
        for name, value in originals.items():
            setattr(shared, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with _configured_shared():
        plan = shared.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Competitive Eater output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Competitive Eater output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-competitiveeater-", dir=campaign))
    staged = transaction / "staged"
    backups = transaction / "backups"
    promoted: list[str] = []
    existed: set[str] = set()
    try:
        for relative in changed:
            stage = staged / relative
            stage.parent.mkdir(parents=True, exist_ok=True)
            stage.write_bytes(plan[relative])
            destination = campaign / relative
            if destination.is_file():
                existed.add(relative)
                backup = backups / relative
                backup.parent.mkdir(parents=True, exist_ok=True)
                backup.write_bytes(destination.read_bytes())
        for relative in changed:
            destination = campaign / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            replace(staged / relative, destination)
            promoted.append(relative)
        return changed
    except BaseException:
        for relative in reversed(promoted):
            destination = campaign / relative
            if relative in existed:
                replace(backups / relative, destination)
            elif destination.exists():
                destination.unlink()
        raise
    finally:
        shutil.rmtree(transaction, ignore_errors=True)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_competitiveeater.py")
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
