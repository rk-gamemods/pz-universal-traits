"""Regenerate only Bad Teeth-owned campaign evidence and ledgers."""

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
from regenerate_brittle import _checked_dimension, _dimension
from regenerate_immuneresponse import _exactly_one, _json_bytes, _metadata, _update_fingerprints


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_badteeth"
FINDINGS = ("B02-UT_badteeth-COVERAGE",)
OMISSIONS = (
    "IR0104-BADTEETH-CROSS-EXCLUSION",
    "IR0104-BADTEETH-HOTLOOP",
)
POLLING_FINDING = "XTF0104-EATING-EDGE-POLLING"
EXCLUSION_FINDING = "XTF0104-EXCLUSION-CONTRACT"
DESCRIPTION = (
    "Dental problems make eating painful. Eating causes increasing head pain "
    "(proportional to food healing). Food effectiveness is not reduced - it just hurts."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_badteeth.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_badteeth.lua"
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
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_badteeth.md"
RESOLUTION = "change-impact/badteeth-consumption-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_02.jsonl",
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
    raise KeyError(f"missing Bad Teeth dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_02.jsonl"
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
            "Cost remains -3, no XP or grants are added, and Bad Teeth/Albino exclusions are reciprocal in source and release.",
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Pre-campaign master, 1da8489, be6eed18, and MoreTraits 42.15 agree on proportional head pain, the threshold, cap, cost, and Albino exclusion.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "The shared consumption module records the food-healing timer before native complete/eat, runs native consumption once, then applies Bad Teeth from the exact positive timer delta.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "A resulting timer above 1000 adds exactly 0.01 head pain per timer point gained and caps total head pain at 100.",
        ),
        "cadence": _dimension(
            "proven-correct",
            "Work is bounded to completed or interrupted positive consumption calls; player updates do not execute Bad Teeth logic.",
        ),
        "cooldown": _dimension(
            "proven-correct", "No cooldown is part of the accepted per-consumption contract."
        ),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "The correction owns no persistent polling state and unregisters the obsolete player-update handler.",
            "Current-version in-game save/load and repeated world entry remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct",
            "SVN 964 exposes ISEatFoodAction.complete/eat, IsoGameCharacter.Eat, BodyDamage.JustAteFood/getHealthFromFoodTimer/getBodyPart, and BodyPart.get/setAdditionalPain on the traced path.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua and verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "Stable shared sentinels keep complete/eat wrappers single across repeated installation, and the obsolete OnPlayerUpdate registration is removed.",
        ),
        "stacking_interactions": _dimension(
            "proven-correct",
            "Bad Teeth composes once with Anorexy and Competitive Eater through the shared wrapper and is reciprocally exclusive with Albino.",
        ),
        "multiplayer": _dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": _dimension("proven-correct", "The exact English display name is Bad Teeth."),
        "description": _dimension(
            "proven-correct",
            "The accepted English copy accurately states eating-triggered head pain proportional to food healing without reducing food effectiveness.",
        ),
        "localization": _dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": _dimension(
            "runtime-unproven",
            "Static behavior is cost -3 with 1 head pain per 100 food-healing timer points above the threshold, capped at 100.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "The per-update poll was removed. Two guarded timer reads and one trait lookup occur only on actual food-consumption calls.",
            "No current-build profiler capture exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Focused tests cover completed and interrupted paths, exact deltas, threshold, guards, cap, composition, failure safety, no polling, exclusions, copy, and parity.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "Timed-action mocks mutate the food-healing timer inside native callbacks so assertions prove before/after ordering rather than a fabricated player-update event.",
        ),
        "source_release_parity": _dimension(
            "proven-correct", "Runtime, shared hook, definition, and English source/release pairs are byte-identical."
        ),
        "packaging": _dimension(
            "coverage-gap",
            "All Bad Teeth-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
        ),
    }
    if tuple(dimensions) != CANONICAL_DIMENSIONS:
        raise RuntimeError("Bad Teeth dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = _exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding["resolution_state"] = "runtime-unproven"
    finding["resolution_evidence"] = (
        "Static engine tracing and focused regression coverage now prove the intended path and exact numbers; the finding is retained only for the requested current-build in-game observation."
    )
    finding["remaining_runtime_proof"] = (
        "Current-build Kahlua execution after a full relaunch, current-version save/load, rendered English, balance, and profiler observation remain unrun."
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 ISEatFoodAction.lua:126-201; IsoGameCharacter.java:6376-6511; BodyDamage.java:552-703,2202-2204,2832-2841; IsoPlayer.java:2001,2241",
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
            evidence="Pre-campaign Git authority, upstream source, current source, SVN 964 engine evidence, and focused regression tests prove this static contract.",
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
        evidence="Bad Teeth-owned source/release content is exact.",
        missing_proof="UniversalTraits package verification remains blocked by the separately tracked missing source poster.",
    )

    omission_evidence = {
        OMISSIONS[0]: "MoreTraits 42.13/42.15 explicitly declares badteeth and albino mutually exclusive, pre-campaign be6eed18 carried both edges into UTMods, and focused parser assertions prove both selection directions.",
        OMISSIONS[1]: "Bad Teeth now runs only after completed or interrupted positive consumption and owns no OnPlayerUpdate registration or timer modData.",
    }
    for omission_id, evidence in omission_evidence.items():
        omission = _exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=evidence,
            missing_proof="Current-build in-game observation remains unrun.",
            recommended_correction="No further static correction is indicated.",
            smallest_regression_test="Covered by the focused Bad Teeth regression cases.",
        )

    polling = _cross_finding(artifact, POLLING_FINDING, relative)
    polling["anchors"] = [anchor for anchor in polling["anchors"] if "UT_badteeth.lua" not in anchor]
    polling["affected_surfaces"] = [surface for surface in polling["affected_surfaces"] if surface != TRAIT]
    polling["reproduction_evidence"] = (
        "Anorexy, Competitive Eater, and Bad Teeth are resolved through exact post-consumption hooks. Ascetic retains a food-timer polling path pending the explicit stress-unit decision."
    )
    polling["partial_resolutions"] = {
        **polling.get("partial_resolutions", {}),
        TRAIT: "implemented-and-statically-validated through exact before/after timer capture on completed and interrupted consumption",
    }

    exclusion = _cross_finding(artifact, EXCLUSION_FINDING, relative)
    exclusion["anchors"] = [
        anchor
        for anchor in exclusion["anchors"]
        if not anchor.endswith(":941-949") and not anchor.endswith(":1777-1785")
    ]
    exclusion["affected_surfaces"] = [
        surface
        for surface in exclusion["affected_surfaces"]
        if surface not in {TRAIT, "UniversalTraits:UT_albino"}
    ]
    exclusion["reproduction_evidence"] = (
        "Competitive Eater/Gourmand and Bad Teeth/Albino are now proven reciprocal and historically grounded. Other reviewed directional or undocumented exclusions remain open."
    )
    exclusion["partial_resolutions"] = {
        **exclusion.get("partial_resolutions", {}),
        "Bad Teeth <-> Albino": "proven from upstream source, pre-campaign history, and both current definition directions",
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
            "schema": "ut-badteeth-consumption-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "initial_runtime_implementation": "1da8489b524403589d5f8c411bf50a8504516a09",
                "accepted_reciprocal_exclusion": "be6eed180bc7f7ece046b84d2083c4bc6b7706e9",
                "upstream_reference": "MoreTraits 42.15 badteethtrait and creation methods",
            },
            "accepted_intent": {
                "cost": -3,
                "trigger": "completed or interrupted positive food consumption that increases the food-healing timer above 1000",
                "head_pain_per_timer_point": 0.01,
                "pain_cap": 100,
                "food_effectiveness_change": 0,
                "exclusions": ["UniversalTraits:UT_albino"],
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*OMISSIONS],
            "retained_runtime_finding": FINDINGS[0],
            "partially_resolved_cross_findings": [POLLING_FINDING, EXCLUSION_FINDING],
            "engine_evidence": [
                "PZCodebase/Lua/shared/TimedActions/ISEatFoodAction.lua:126-201",
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6376-6511",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:552-703,2202-2204,2832-2841",
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2001,2241",
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
                "exact completed before/after timer delta",
                "exact interrupted partial-consumption delta",
                "1000 threshold and rising-edge guards",
                "trait and positive-consumption guards",
                "later-meal delta isolation and 100 cap",
                "no player-update poll, modData, or retained periodic handler",
                "bridge-read failure cannot block native consumption",
                "shared Anorexy and Competitive Eater composition",
                "reciprocal Albino exclusion",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "No new loop or handler is added. Two guarded timer reads and one trait lookup occur per actual food-consumption call; body-part reads and one write occur only for an active Bad Teeth player with a qualifying increase."
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
        raise RuntimeError("Bad Teeth output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Bad Teeth output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-badteeth-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_badteeth.py")
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
