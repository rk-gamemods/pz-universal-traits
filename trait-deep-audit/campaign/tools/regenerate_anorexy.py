"""Regenerate only Anorexy-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import (
    CANONICAL_DIMENSIONS,
    build_ledger,
    render_ledger,
    render_trait_rows,
)
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256
from campaign_cli import no_arg_command
from regenerate_brittle import _checked_dimension, _dimension, _materialize
from regenerate_immuneresponse import (
    _exactly_one,
    _json_bytes,
    _metadata,
    _update_fingerprints,
)


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_anorexy"
FINDINGS = ("B01-ANO-SCALE", "B01-ANO-PERF")
OMISSION = "IR0104-ANOREXY-MEAL-DETECTION"
POLLING_FINDING = "XTF0104-EATING-EDGE-POLLING"
WRAPPER_FINDING = "XTF0104-ITEM-CONSUMPTION-WRAPPERS"
MOCK_FINDING = "XTF0104-MOCK-ENGINE-DOMAINS"
BLOCKER_IDENTITY = "trait:UT_anorexy"
WRAPPER_BLOCKER_IDENTITY = "shared-hook:item-consumption-wrapper-lifecycle"
WRAPPER_QUEUE_ID = f"finding:{WRAPPER_FINDING}"
DESCRIPTION = (
    "Your relationship with food is deeply complicated. Each time you eat, stress "
    "increases by 0.10 (10 percent of the stress meter)."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_anorexy.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_anorexy.lua"
)
HOOK = "UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua"
HOOK_RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/UT_ItemConsumptionHooks.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_anorexy.md"
RESOLUTION = "change-impact/anorexy-consumption-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_01.jsonl",
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


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_01.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = row["dimensions"]

    def dimension_value(canonical: str, legacy: str | None = None) -> dict[str, Any]:
        for key in (legacy, canonical):
            if key is not None and key in dimensions:
                return dimensions[key]
        raise KeyError(f"missing Anorexy dimension: {canonical}")

    dimensions["source-mod intent"] = _dimension(
        "proven",
        "Pre-campaign master and Git history establish one +0.10 stress effect per eating event. DTEM is lineage evidence only; its broader dynamic and passive mechanics were deliberately not ported.",
    )
    dimensions["exact runtime path through UT_CORE or script-only behavior"] = _dimension(
        "proven",
        "The existing shared item-consumption module wraps completed and interrupted positive food consumption after character:Eat, then applies one bounded Anorexy stress increment. No Anorexy tick handler remains.",
    )
    dimensions["numerical behavior"] = _dimension(
        "proven",
        "Each positive consumption event sets STRESS to min(1.0, current stress + 0.10), after native food stress effects.",
    )
    dimensions["cadence"] = _dimension(
        "proven",
        "Work is bounded to completed or interrupted positive food-consumption calls; player updates do not run Anorexy logic.",
    )
    dimensions["cooldowns"] = _dimension(
        "proven", "No cooldown is part of the accepted one-effect-per-consumption contract."
    )
    dimensions["reset and save/load"] = _dimension(
        "runtime-unproven",
        "The correction has no persistent trait state and removes obsolete same-process tick registration.",
        "Current-version in-game save/load and full relaunch remain unobserved; backward save migration is a non-goal.",
    )
    dimensions["Java-Lua exposure"] = _dimension(
        "proven",
        "SVN 964 exposes ISEatFoodAction.complete/eat, IsoGameCharacter.Eat, Stats.get/set, and CharacterStat.STRESS with the traced argument and ordering contract.",
    )
    dimensions["Kahlua compatibility"] = _dimension(
        "runtime-unproven",
        "The implementation uses Kahlua-compatible Lua and verified Java receiver methods.",
        "Current-build Kahlua execution is unobserved.",
    )
    dimensions["event lifecycle"] = _dimension(
        "proven",
        "Stable sentinel fields keep perform, complete, eat, and drink wrappers single across reload and repeated startup events; the obsolete tick registration is removed.",
    )
    dimensions["stacking and cross-trait interactions"] = _dimension(
        "proven",
        "Anorexy applies after native food effects, performs no transferable item mutation, and retains reciprocal exclusions with Gourmand, Competitive Eater, and Mundane.",
    )
    dimensions["multiplayer restriction"] = _dimension(
        "not-applicable",
        "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
    )
    dimensions["display name"] = _dimension("proven", "The exact English display name is Anorexia.")
    dimensions["description accuracy"] = _dimension(
        "proven",
        "The English copy states the exact eating trigger, +0.10 magnitude, and 10 percent meter interpretation.",
    )
    dimensions["localization coverage including absent locales"] = _dimension(
        "coverage-gap",
        "The exact English keys exist in source and release.",
        "No non-English UniversalTraits locale exists.",
    )
    dimensions["balance"] = _dimension(
        "runtime-unproven",
        "Static behavior is cost -6 and one +0.10 stress increment per positive food-consumption event.",
        "No gameplay telemetry or comparative balance session exists.",
    )
    dimensions["performance risk"] = _dimension(
        "runtime-unproven",
        "The per-update poll was removed. The shared hook adds one trait lookup per food-consumption event and one stress read/write only for Anorexy.",
        "No current-build profiler capture exists.",
    )
    dimensions["tests"] = _dimension(
        "proven",
        "Focused tests cover exact post-native +0.10 behavior, cap, interrupted partial food, zero/no-trait no-ops, no polling, perform ordering, copy, parity, and reload idempotence.",
    )
    dimensions["mocks"] = _dimension(
        "proven",
        "The timed-action mocks expose perform, complete, and eat separately and allow native food effects before the trait assertion. Anorexy explicitly caps stress and does not rely on a mock clamp.",
    )
    dimensions["source/release parity"] = _dimension(
        "proven", "Trait runtime, shared hook, and English source/release pairs are byte-identical."
    )
    dimensions["packaging integrity"] = _dimension(
        "coverage-gap",
        "All Anorexy-owned 42.0 runtime and English counterparts are present and identical.",
        "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
    )
    row["dimensions"] = {
        "registration": dimension_value("registration"),
        "definition_parser": dimension_value(
            "definition_parser", "complete script definition and parser validity"
        ),
        "namespace": dimension_value("namespace"),
        "cost_xp_grants_exclusions": dimension_value(
            "cost_xp_grants_exclusions",
            "cost/XP/grants/exclusions and bidirectional exclusion behavior",
        ),
        "source_intent": dimension_value("source_intent", "source-mod intent"),
        "runtime_path": dimension_value(
            "runtime_path", "exact runtime path through UT_CORE or script-only behavior"
        ),
        "numbers": dimension_value("numbers", "numerical behavior"),
        "cadence": dimension_value("cadence"),
        "cooldown": dimension_value("cooldown", "cooldowns"),
        "reset_save_load": dimension_value("reset_save_load", "reset and save/load"),
        "java_lua": dimension_value("java_lua", "Java-Lua exposure"),
        "kahlua": dimension_value("kahlua", "Kahlua compatibility"),
        "events": dimension_value("events", "event lifecycle"),
        "stacking_interactions": dimension_value(
            "stacking_interactions", "stacking and cross-trait interactions"
        ),
        "multiplayer": dimension_value("multiplayer", "multiplayer restriction"),
        "display": dimension_value("display", "display name"),
        "description": dimension_value("description", "description accuracy"),
        "localization": dimension_value(
            "localization", "localization coverage including absent locales"
        ),
        "balance": dimension_value("balance"),
        "performance": dimension_value("performance", "performance risk"),
        "tests": dimension_value("tests"),
        "mocks": dimension_value("mocks"),
        "source_release_parity": dimension_value("source_release_parity", "source/release parity"),
        "packaging": dimension_value("packaging", "packaging integrity"),
    }
    if tuple(row["dimensions"]) != CANONICAL_DIMENSIONS:
        raise RuntimeError("Anorexy dimension canonicalization drifted")
    row["overall_state"] = "runtime-unproven"
    for finding_id in FINDINGS:
        finding = _exactly_one(row["findings"], "id", finding_id, relative)
        finding["resolution_state"] = "proven-correct"
        finding["resolution_evidence"] = (
            "The pre-campaign +0.10 effect now runs once after actual completed or interrupted positive food consumption, caps at 1.0, and performs no per-update polling."
        )
        finding["remaining_runtime_proof"] = (
            "Current-build Kahlua execution after a full relaunch, current-version save/load, and profiler observation remain unrun."
        )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 ISEatFoodAction.lua:126-176,193-201; IsoGameCharacter.java:6380-6507,9690-9710; CharacterStat.java:11-33; Stats.java:74-87",
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


def _plan_translation(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "translation_audit.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = _exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["english"]["description"].update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        translator_percent_mutates=False,
        dev_rejected_confusables=[],
        static_display_state="proven-correct",
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["rendered English not observed in game"]
    for source in (SOURCE_UI, RELEASE_UI):
        if _update_fingerprints(artifact, source, _metadata(root, source)) < 1:
            raise ValueError(f"{relative}: no fingerprint owner for {source}")
    plan[relative] = _json_bytes(artifact, compact=True)


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
        MOCKS,
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
        "source_mod_intent",
        "exact_runtime_path_through_ut_core_or_script_only_behavior",
        "numerical_behavior",
        "cadence",
        "cooldowns",
        "java_lua_exposure",
        "event_lifecycle",
        "stacking_and_cross_trait_interactions",
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
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        _checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and regression evidence is complete for the implemented contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    _checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Anorexy-owned source/release content is exact.",
        missing_proof="UniversalTraits package verification remains blocked by the separately tracked missing source poster.",
    )
    omission = _exactly_one(row["omissions"], "id", OMISSION, relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=(
            "Completed actions use ISEatFoodAction.complete after character:Eat; interrupted partial actions use ISEatFoodAction.eat after its effective-fraction Eat call. Neither path relies on healthFromFoodTimer."
        ),
        missing_proof="Current-build in-game Kahlua observation remains unrun.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by completed, partial, zero, no-trait, ordering, no-polling, and reload tests.",
    )

    polling = _cross_finding(artifact, POLLING_FINDING, relative)
    polling["anchors"] = [anchor for anchor in polling["anchors"] if "UT_anorexy.lua" not in anchor]
    polling["affected_surfaces"] = [surface for surface in polling["affected_surfaces"] if surface != TRAIT]
    polling["reproduction_evidence"] = (
        "Anorexy is resolved through exact post-consumption hooks. Ascetic, Competitive Eater, and Bad Teeth still use healthFromFoodTimer paths that miss ordinary partial meals or depend on special healing conditions."
    )
    polling["partial_resolutions"] = {
        TRAIT: "implemented-and-statically-validated through completed and interrupted post-consumption wrappers"
    }

    wrapper = _cross_finding(artifact, WRAPPER_FINDING, relative)
    wrapper.update(
        state="proven-correct",
        title="Shared timed-action wrappers remain single across repeated installation",
        reproduction_evidence=(
            "Stable sentinel fields retain one perform and drink wrapper across repeated startup calls. Anorexy adds separately marked complete and eat wrappers. Focused reload tests call the installer repeatedly and prove all four function identities remain unchanged."
        ),
        missing_proof="Current-build repeated-world-entry observation remains unrun.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by repeated script load, repeated startup events, stable wrapper identities, and preserved later-owner behavior.",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence="Current source already uses one stable sentinel per wrapper, and the focused reload regression proves the former wrapper chain cannot recur.",
    )

    mock_finding = _cross_finding(artifact, MOCK_FINDING, relative)
    mock_finding["affected_surfaces"] = [
        surface for surface in mock_finding["affected_surfaces"] if surface != TRAIT
    ]
    mock_finding["partial_resolutions"] = {
        **mock_finding.get("partial_resolutions", {}),
        TRAIT: "Anorexy explicitly caps the 0.0 to 1.0 stress domain and regression tests assert the exact boundary without relying on mock add/set clamping.",
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
        "english_runtime": _metadata(root, SOURCE_UI)["sha256"],
        "english_release": _metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = _json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    matches = [row for row in identities if row.get("semantic_identity") == BLOCKER_IDENTITY]
    if len(matches) > 1:
        raise ValueError(f"{relative}: expected at most one {BLOCKER_IDENTITY}, found {len(matches)}")
    if matches and matches[0].get("priority_reason_code") != "unbounded-hot-path-handler":
        raise ValueError(f"{relative}: unexpected {BLOCKER_IDENTITY} ownership")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY
    ]
    wrapper_blocker = _exactly_one(
        artifact["identities"], "semantic_identity", WRAPPER_BLOCKER_IDENTITY, relative
    )
    if wrapper_blocker.get("priority_reason_code") != "stacking-wrapper-lifecycle":
        raise ValueError(f"{relative}: unexpected {WRAPPER_BLOCKER_IDENTITY} ownership")
    wrapper_blocker["queue_ids"] = [
        queue_id
        for queue_id in wrapper_blocker.get("queue_ids", [])
        if queue_id != WRAPPER_QUEUE_ID
    ]
    wrapper_blocker["evidence_scope"] = (
        "The shared wrapper sentinel is statically corrected. Caller-specific review records remain queued until their assigned trait closures reconcile them."
    )
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-anorexy-consumption-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "original_event_implementation": "e87e49d",
                "build_42_migration_with_defects": "16e1f1e",
            },
            "accepted_intent": {
                "cost": -6,
                "trigger": "each completed or interrupted positive food-consumption event",
                "effect": "+0.10 CharacterStat.STRESS after native food effects",
                "cap": 1.0,
                "runtime_scope": "single-player",
            },
            "historical_source_boundary": (
                "DTEM confirms eating-related lineage but its dynamic acquisition, passive symptoms, and varying multi-stat penalties were deliberately not restored because pre-campaign UTMods selected one fixed stress effect."
            ),
            "resolved_findings": [*FINDINGS, OMISSION, WRAPPER_FINDING],
            "partially_resolved_cross_findings": [POLLING_FINDING, MOCK_FINDING],
            "engine_evidence": [
                "PZCodebase/Lua/shared/TimedActions/ISEatFoodAction.lua:126-176,193-201",
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6380-6507,9690-9710",
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
                    MOCKS,
                    TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "exact +0.10 after native food effects",
                "stress cap at 1.0",
                "interrupted partial consumption",
                "zero consumption and no-trait no-op",
                "no player-update polling or stale mod data",
                "perform alone is not consumption",
                "single wrappers after reload and repeated startup",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "No new loop or handler is added. One trait lookup occurs per actual food-consumption call, followed by one stress read and one stress write only for an active Anorexy player."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build completed and interrupted food observation, repeated world entry, current-version save/load, rendered English, and profiler capture."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment"],
        }
    )


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix="regenerate-anorexy-plan-") as directory:
        overlay = Path(directory) / "campaign"
        _materialize(campaign, plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay, ledger)
        plan.update(
            {
                "final_trait_ledger.json": render_ledger(ledger).encode("utf-8"),
                "final_trait_ledger_rows.jsonl": render_trait_rows(ledger).encode("utf-8"),
                "dimension_ledger_rows.jsonl": dimensions.encode("utf-8"),
                "remediation_queue.jsonl": queue.encode("utf-8"),
                "remediation_summary.json": summary.encode("utf-8"),
            }
        )
        _materialize(campaign, plan, overlay)
        update_release_blocker_queue_sha256(
            overlay / "remediation_queue.jsonl", overlay / "release_blocker_queue.json"
        )
        plan["release_blocker_queue.json"] = (
            overlay / "release_blocker_queue.json"
        ).read_bytes()
        _materialize(campaign, plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode("utf-8")


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    plan: dict[str, bytes] = {}
    _plan_batch(campaign, plan)
    _plan_translation(root, campaign, plan)
    _plan_inventory(root, campaign, plan)
    _plan_review(root, campaign, plan)
    _plan_blocker(campaign, plan)
    _plan_resolution(root, plan)
    _plan_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Anorexy output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Anorexy output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-anorexy-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_anorexy.py")
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
