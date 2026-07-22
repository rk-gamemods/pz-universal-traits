"""Regenerate only Glass Body-owned campaign evidence and ledgers."""

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
TRAIT = "UniversalTraits:UT_glassbody"
FINDING = "B04-glassbody-EVENT-ORDER"
OMISSION = "IR0104-GLASSBODY-PREDAMAGE-TIMING"
CROSS_FINDING = "XTF0104-PREDAMAGE-WEAPON-EVENT"
INTEGRATION_FINDINGS = ("IC-RPF-001", "IC-OM-001")
BLOCKER_IDENTITY = "trait:UT_glassbody-hit-handler"
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_glassbody.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_glassbody.lua"
)
HOOK = "UT_CORE/media/lua/shared/UTCore/UTCore_DamageMultHook.lua"
HOOK_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_DamageMultHook.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
TESTS = "UT_CORE/test/run_tests.lua"
TRAIT_TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_glassbody.md"
RESOLUTION = "change-impact/glassbody-resolved-damage-contract.json"
DESCRIPTION = (
    "Your body feels like it was built to break. All incoming damage is multiplied by "
    "×1.5 (+50 percent damage taken)."
)
OWNED_OUTPUTS = (
    "trait_batches/batch_04.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_01_04.json",
    "independent_reviews/ut_core_integration.json",
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
    relative = "trait_batches/batch_04.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = row["dimensions"]

    def dimension_value(canonical: str, legacy: str | None = None) -> dict[str, Any]:
        for key in (legacy, canonical):
            if key is not None and key in dimensions:
                return dimensions[key]
        raise KeyError(f"missing Glass Body dimension: {canonical}")

    dimensions["source_mod_intent"] = _dimension(
        "proven",
        "Pre-campaign master is the accepted authority: cost -10 and all incoming resolved body-health loss multiplied by 1.5. More Traits confirms all-source lineage; its extra scratches and fractures were not restored.",
    )
    dimensions["exact_runtime_path_through_UT_CORE_or_script_only_behavior"] = _dimension(
        "proven",
        "OnNewGame writes UT_damageMult=1.5. The existing central update dispatch compares resolved overall body health, applies only the extra 50 percent through ReduceGeneralHealth, and stores the expected aggregate so its own reduction is not multiplied again.",
    )
    dimensions["numerical_behavior"] = _dimension(
        "proven",
        "A resolved loss L applies min(L*0.5, remaining health), producing 1.5*L total loss when the player survives and never reducing below zero.",
    )
    dimensions["cadence"] = _dimension(
        "proven",
        "The hook reuses UT_CORE's single central player-update dispatch and performs one aggregate-health read per update only while a valid multiplier is active.",
    )
    dimensions["cooldowns"] = _dimension(
        "proven", "No cooldown is part of the accepted always-on damage contract."
    )
    dimensions["reset_and_save_load"] = _dimension(
        "runtime-unproven",
        "Tracking is transient, resets for a replacement player or invalid marker, and is explicitly reset on same-process hook reload; the persistent multiplier remains in player mod data.",
        "Current-version in-game save/load and full relaunch remain unobserved; backward save migration is a non-goal.",
    )
    dimensions["Java_Lua_exposure"] = _dimension(
        "proven",
        "SVN 964 exposes BodyDamage.getOverallBodyHealth and ReduceGeneralHealth. IsoPlayer emits OnPlayerUpdate before the following IsoGameCharacter update recalculates overall body health.",
    )
    dimensions["Kahlua_compatibility"] = _dimension(
        "runtime-unproven",
        "The implementation uses Kahlua-compatible Lua and verified Java receiver methods.",
        "Current-build Kahlua execution is unobserved.",
    )
    dimensions["event_lifecycle"] = _dimension(
        "proven",
        "One stable core dispatcher delegates to the current callback across reloads, and any obsolete weapon listener is removed. Focused tests prove the handler count remains stable.",
    )
    dimensions["stacking_and_cross_trait_interactions"] = _dimension(
        "proven",
        "Closed-world search finds one UT_damageMult writer and one consumer; the trait is reciprocally exclusive with UT_analgesia.",
    )
    dimensions["multiplayer_restriction"] = _dimension(
        "not-applicable",
        "The trait is disabled in multiplayer and multiplayer support is an explicit product non-goal.",
    )
    dimensions["display_name"] = _dimension("proven", "The exact English display name is Glass Body.")
    dimensions["description_accuracy"] = _dimension(
        "proven",
        "The English all-incoming-damage and +50 percent claims match the accepted resolved body-health multiplier.",
    )
    dimensions["localization_coverage_including_absent_locales"] = _dimension(
        "coverage-gap",
        "The exact English keys exist in source and release.",
        "No non-English UniversalTraits locale exists.",
    )
    dimensions["balance"] = _dimension(
        "runtime-unproven",
        "Static behavior is cost -10 and 1.5 times resolved incoming body-health loss.",
        "No gameplay telemetry or comparative balance session exists.",
    )
    dimensions["performance_risk"] = _dimension(
        "runtime-unproven",
        "No new loop was added. The existing central dispatch adds one Lua marker check for inactive players and one aggregate-health getter for an active Glass Body player.",
        "No current-build profiler capture exists.",
    )
    dimensions["tests"] = _dimension(
        "proven",
        "Resolved all-source loss, exact multiplier, recursion prevention, healing, lethal cap, player replacement, and same-process reload are regression-protected.",
    )
    dimensions["mocks"] = _dimension(
        "proven",
        "The focused body-damage mock separates immediate body-part reduction from the later aggregate-health recalculation, matching SVN 964 ordering.",
    )
    dimensions["source_release_parity"] = _dimension(
        "proven", "Trait runtime, shared hook, and English source/release pairs are byte-identical."
    )
    dimensions["packaging_integrity"] = _dimension(
        "coverage-gap",
        "All Glass Body-owned 42.0 runtime and English counterparts are present and identical.",
        "UniversalTraits and UT_CORE package verification remain blocked only by separately tracked missing source posters.",
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
        "source_intent": dimension_value("source_intent", "source_mod_intent"),
        "runtime_path": dimension_value(
            "runtime_path", "exact_runtime_path_through_UT_CORE_or_script_only_behavior"
        ),
        "numbers": dimension_value("numbers", "numerical_behavior"),
        "cadence": dimension_value("cadence"),
        "cooldown": dimension_value("cooldown", "cooldowns"),
        "reset_save_load": dimension_value("reset_save_load", "reset_and_save_load"),
        "java_lua": dimension_value("java_lua", "Java_Lua_exposure"),
        "kahlua": dimension_value("kahlua", "Kahlua_compatibility"),
        "events": dimension_value("events", "event_lifecycle"),
        "stacking_interactions": dimension_value(
            "stacking_interactions", "stacking_and_cross_trait_interactions"
        ),
        "multiplayer": dimension_value("multiplayer", "multiplayer_restriction"),
        "display": dimension_value("display", "display_name"),
        "description": dimension_value("description", "description_accuracy"),
        "localization": dimension_value(
            "localization", "localization_coverage_including_absent_locales"
        ),
        "balance": dimension_value("balance"),
        "performance": dimension_value("performance", "performance_risk"),
        "tests": dimension_value("tests"),
        "mocks": dimension_value("mocks"),
        "source_release_parity": dimension_value("source_release_parity"),
        "packaging": dimension_value("packaging", "packaging_integrity"),
    }
    if tuple(row["dimensions"]) != CANONICAL_DIMENSIONS:
        raise RuntimeError("Glass Body dimension canonicalization drifted")
    row["overall_state"] = "runtime-unproven"
    finding = _exactly_one(row["findings"], "id", FINDING, relative)
    finding["resolution_state"] = "proven-correct"
    finding["resolution_evidence"] = (
        "The intermediate signature correction was superseded by a resolved body-health delta path that does not consume OnWeaponHitCharacter and covers all damage sources promised by pre-campaign master."
    )
    finding["remaining_runtime_proof"] = (
        "Current-build Kahlua execution after a full relaunch and current-version save/load remain unobserved."
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Damage and healing within one engine update are observed as their net aggregate health change.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 IsoPlayer.java:2241; IsoGameCharacter.java:9737; BodyDamage.java:2419,2465-2478",
        "static_regression": "UT_CORE and UniversalTraits standard-Lua suites",
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
    description = row["english"]["description"]
    description.update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        translator_percent_mutates=False,
        dev_rejected_confusables=[],
        static_display_state="proven-correct",
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["rendered English and in-game damage behavior not observed"]
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
        TESTS,
        TRAIT_TESTS,
        ACTIVE_AUDIT,
    ):
        _update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = _json_bytes(artifact)


def _plan_trait_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
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
        "tests",
        "mocks",
        "source_release_parity",
    ):
        _checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence="Pre-campaign master, More Traits lineage, current source, SVN 964 API/order evidence, and focused regression tests prove this static contract.",
            missing_proof="",
        )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        _checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and regression evidence is complete for the implemented contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    omission = _exactly_one(row["omissions"], "id", OMISSION, relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=(
            "The hook no longer consumes the pre-resolution weapon event. It observes resolved aggregate body-health loss in the existing central update dispatch and applies the configured extra once."
        ),
        missing_proof="Current-build in-game Kahlua observation remains unrun.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by resolved-loss, recursion, healing, lethal-cap, player-replacement, and reload tests.",
    )
    cross = _exactly_one(artifact["cross_trait_findings"], "id", CROSS_FINDING, relative)
    cross.update(
        state="proven-correct",
        title="Glass Body leaves the pre-damage event; Brittle eligibility remains separately governed",
        reproduction_evidence=(
            "Glass Body now observes resolved all-source body-health deltas and has no weapon-event listener. Brittle retains its accepted pre-resolution trigger, with cancelled-contact policy isolated under IR0104-BRITTLE-PREDAMAGE-ELIGIBILITY."
        ),
        missing_proof="Current-build Glass Body observation and the separate Brittle policy decision remain open.",
        recommended_correction="No shared correction remains. Preserve the separate Brittle policy question.",
        smallest_regression_test="Glass Body resolved-loss tests and Brittle producer-order tests cover the separated paths.",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence="The shared cross-trait defect was decomposed into a corrected Glass Body path and an explicit Brittle policy question.",
    )
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full relaunch, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": _metadata(root, RUNTIME)["sha256"],
        "trait_release": _metadata(root, RELEASE)["sha256"],
        "hook_runtime": _metadata(root, HOOK)["sha256"],
        "hook_release": _metadata(root, HOOK_RELEASE)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = _json_bytes(artifact)


def _find_integration_finding(artifact: dict[str, Any], finding_id: str, relative: str) -> dict[str, Any]:
    matches = [
        row
        for key in ("verified_prior_findings", "rejected_prior_findings", "omissions")
        for row in artifact.get(key, [])
        if row.get("id") == finding_id
    ]
    if len(matches) != 1:
        raise ValueError(f"{relative}: expected one integration finding {finding_id}, found {len(matches)}")
    return matches[0]


def _plan_integration_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/ut_core_integration.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    inventory_entry = _exactly_one(artifact["inventory"], "path", HOOK, relative)
    entry = _exactly_one(artifact["per_file_review"], "path", HOOK, relative)
    source = _metadata(root, HOOK)
    release = _metadata(root, HOOK_RELEASE)
    inventory_entry.update(
        sha256=source["sha256"].lower(),
        bytes=source["bytes"],
        release_sha256=release["sha256"].lower(),
        release_parity="exact",
    )
    entry.update(
        sha256=source["sha256"].lower(),
        bytes=source["bytes"],
        release_sha256=release["sha256"].lower(),
        release_parity="exact",
        source_role="resolved all-source body-health damage multiplier",
        overall_state="runtime-unproven",
    )
    for name in (
        "public_helpers_and_handlers",
        "event_producer_consumer_contracts",
        "shared_state_and_moddata",
        "registration_removal_idempotence",
        "cadence_throttle_reset_save_load",
        "numerical_behavior",
        "java_lua_kahlua_receiver_methods",
        "single_player_restriction_assumptions",
        "stacking_and_composition",
        "tests_and_mocks",
        "source_release_parity",
    ):
        entry["dimensions"][name].update(
            classification="proven-correct",
            evidence="Current hook, SVN 964 update/body-health evidence, and focused regression tests prove this static contract.",
        )
    entry["dimensions"]["performance"].update(
        classification="runtime-unproven",
        evidence="The hook reuses the existing central dispatch and adds one aggregate-health getter only for an active multiplier; no profiler capture exists.",
    )
    for finding_id in INTEGRATION_FINDINGS:
        finding = _find_integration_finding(artifact, finding_id, relative)
        finding.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=(
                "The hook no longer consumes OnWeaponHitCharacter. Resolved overall body-health deltas drive one bounded extra reduction, with delayed aggregate recalculation modeled in regression tests."
            ),
            missing_proof="Current-build in-game Kahlua observation remains unrun.",
        )
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
    if matches and matches[0].get("priority_reason_code") != "invalid-hit-handler-contract":
        raise ValueError(f"{relative}: unexpected {BLOCKER_IDENTITY} ownership")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY
    ]
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-glassbody-resolved-damage-contract-v1",
            "trait_id": TRAIT,
            "authority": "pre-campaign UTMods master",
            "accepted_intent": {
                "cost": -10,
                "scope": "all resolved incoming body-health loss",
                "multiplier": 1.5,
                "exclusion": "UniversalTraits:UT_analgesia",
                "runtime_scope": "single-player",
            },
            "historical_source_boundary": (
                "More Traits confirms all-source lineage. Its extra scratch and fracture effects are evidence only and were not restored because pre-campaign UTMods master selected a flat +50 percent total-health penalty."
            ),
            "resolved_findings": [FINDING, OMISSION, CROSS_FINDING, *INTEGRATION_FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241",
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6768-6791,9737",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1060-1073,2419,2465-2478",
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
                    TESTS,
                    TRAIT_TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "exact 1.5 trait marker",
                "resolved all-source health loss",
                "no recursive multiplication",
                "multiplier at one",
                "healing baseline reset",
                "lethal extra-damage cap",
                "replacement player baseline",
                "same-process hook reload",
            ],
            "preserved_surfaces": [
                "trait cost",
                "all-source scope",
                "+50 percent multiplier",
                "reciprocal Analgesia exclusion",
                "registration and English copy",
            ],
            "performance_model": (
                "No new loop or handler is added. The existing central dispatch performs one marker lookup for inactive players and one aggregate-health getter per active Glass Body update."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build multi-source damage observation, current-version save/load, rendered English, and profiler capture."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment"],
        }
    )


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix="regenerate-glassbody-plan-") as directory:
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
    _plan_trait_review(root, campaign, plan)
    _plan_integration_review(root, campaign, plan)
    _plan_blocker(campaign, plan)
    _plan_resolution(root, plan)
    _plan_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Glass Body output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Glass Body output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-glassbody-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_glassbody.py")
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
