"""Regenerate only Brittle-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256
from campaign_cli import no_arg_command
from regenerate_immuneresponse import (
    _exactly_one,
    _json_bytes,
    _metadata,
    _update_fingerprints,
)


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_brittle"
FINDINGS = ("B02-UT_brittle-01", "B02-UT_brittle-02")
INTEGRATION_FINDINGS = ("IC-VPF-001", "IC-VPF-002")
POLICY_QUESTION = "IR0104-BRITTLE-PREDAMAGE-ELIGIBILITY"
BLOCKER_IDENTITY = "shared-hook:UTCore_FractureHook"
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_brittle.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_brittle.lua"
)
HOOK = "UT_CORE/media/lua/shared/UTCore/UTCore_FractureHook.lua"
HOOK_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_FractureHook.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
TESTS = "UT_CORE/test/run_tests.lua"
TRAIT_TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_brittle.md"
RESOLUTION = "change-impact/brittle-fracture-contract-resolution.json"
DESCRIPTION = (
    "Your bones are fragile and snap under stress. Fracture chance is increased by +50%."
)
OWNED_OUTPUTS = (
    "trait_batches/batch_02.jsonl",
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


def _dimension(state: str, evidence: str, missing: str = "none") -> dict[str, str]:
    return {"state": state, "evidence": evidence, "missing_proof": missing}


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_02.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = row["dimensions"]
    runtime_proof = (
        "SVN 964 emits OnWeaponHitCharacter(wielder,target,weapon,damageSplit); the hook binds "
        "that order, reads the target's 1.5 multiplier, rolls floor(4*1.5)=6 percent, and sets "
        "fracture time 21 on one eligible unfractured part."
    )
    dimensions["source_mod_intent"] = _dimension(
        "proven",
        "Pre-campaign master is the accepted authority: cost -6, +50 percent fracture risk on the weapon-hit event, and a 10 in-game-second cooldown. Historical SomewhatTraits fall behavior was not restored.",
    )
    dimensions["exact_runtime_path_through_UT_CORE_or_script_only_behavior"] = _dimension(
        "proven", runtime_proof
    )
    dimensions["numerical_behavior"] = _dimension(
        "proven",
        "The multiplier produces a 6 percent roll; one of six eligible parts receives fracture time 21; already fractured parts are excluded.",
    )
    dimensions["cadence"] = _dimension(
        "proven", "One bounded six-part scan is possible per eligible weapon-hit callback."
    )
    dimensions["cooldowns"] = _dimension(
        "proven",
        "The cooldown is an absolute GameTime world-age expiry of 10/3600 hours, so it expires without intervening hits.",
    )
    dimensions["reset_and_save_load"] = _dimension(
        "runtime-unproven",
        "The multiplier and cooldown expiry persist in player mod data; same-process hook reload replaces its prior callback.",
        "Current-version in-game save/load and full relaunch remain unobserved; backward save migration is a non-goal.",
    )
    dimensions["Java_Lua_exposure"] = _dimension(
        "proven",
        "SVN 964 exposes the four event arguments, GameTime.getWorldAgeHours, BodyDamage.getBodyPart, BodyPart.getFractureTime, and BodyPart.setFractureTime used by the hook.",
    )
    dimensions["Kahlua_compatibility"] = _dimension(
        "runtime-unproven",
        "The path uses Kahlua-compatible Lua constructs and verified Java receiver methods.",
        "Current-build Kahlua execution is unobserved.",
    )
    dimensions["event_lifecycle"] = _dimension(
        "proven",
        "The handler binds the producer's exact argument order and removes its stored prior callback before re-registering; the regression suite proves one handler after reload.",
    )
    dimensions["stacking_and_cross_trait_interactions"] = _dimension(
        "proven",
        "Closed-world search finds one UT_fractureMult writer and one consumer; no other trait writes the multiplier or cooldown keys.",
    )
    dimensions["multiplayer_restriction"] = _dimension(
        "not-applicable",
        "The trait is disabled in multiplayer and multiplayer support is an explicit product non-goal.",
    )
    dimensions["display_name"] = _dimension("proven", "The exact English display name is Brittle.")
    dimensions["description_accuracy"] = _dimension(
        "proven", "The English +50 percent claim matches the accepted 1.5 fracture-risk multiplier."
    )
    dimensions["localization_coverage_including_absent_locales"] = _dimension(
        "coverage-gap",
        "The exact English keys exist in source and release.",
        "No non-English UniversalTraits locale exists.",
    )
    dimensions["balance"] = _dimension(
        "runtime-unproven",
        "Static behavior is cost -6 and a 6 percent fracture roll on an eligible hit.",
        "No gameplay telemetry or comparative balance session exists.",
    )
    dimensions["performance_risk"] = _dimension(
        "runtime-unproven",
        "The event path has a constant six-part upper bound and no background polling.",
        "No current-build profiler capture exists.",
    )
    dimensions["tests"] = _dimension(
        "proven",
        "Producer-order, successful roll, multiplier gate, elapsed-time cooldown, exhausted eligibility, trait marker, and reload-idempotence regressions are present.",
    )
    dimensions["mocks"] = _dimension(
        "proven",
        "The event mock forwards all four arguments in order; game time and fracture-time state are modeled independently.",
    )
    dimensions["source_release_parity"] = _dimension(
        "proven", "Trait runtime, shared hook, and English source/release pairs are byte-identical."
    )
    dimensions["packaging_integrity"] = _dimension(
        "coverage-gap",
        "All Brittle-owned 42.0 runtime and English counterparts are present and identical.",
        "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
    )
    row["overall_state"] = "runtime-unproven"
    for finding_id in FINDINGS:
        finding = _exactly_one(row["findings"], "id", finding_id, relative)
        finding["resolution_state"] = "proven-correct"
        finding["resolution_evidence"] = (
            "Commit 2f98749 corrected the event argument order and replaced the hit-count cooldown "
            "with an absolute world-age expiry; current producer-faithful tests cover both corrections."
        )
        finding["remaining_runtime_proof"] = (
            "Current-build Kahlua execution after a full relaunch and current-version save/load remain unobserved."
        )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Whether cancelled, avoided, or zero-final-damage contacts should be excluded requires user approval because pre-campaign master deliberately used the pre-resolution event.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 IsoGameCharacter.java:6768",
        "static_regression": "UT_CORE and UniversalTraits standard-Lua suites",
        "runtime_checks_unrun": ["game launch", "current-version save-load"],
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
        TESTS,
        TRAIT_TESTS,
        ACTIVE_AUDIT,
    ):
        _update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = _json_bytes(artifact)


def _checked_dimension(row: dict[str, Any], dimension_id: str) -> dict[str, Any]:
    return _exactly_one(row["checked_dimensions"], "id", dimension_id, row["trait_id"])


def _plan_trait_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    for dimension_id in (
        "exact_runtime_path_through_ut_core_or_script_only_behavior",
        "numerical_behavior",
        "event_lifecycle",
        "tests",
        "mocks",
        "source_release_parity",
    ):
        checked = _checked_dimension(row, dimension_id)
        checked.update(
            state="proven-correct",
            evidence="Current source, SVN 964 producer evidence, and producer-faithful regression tests prove the corrected Brittle path.",
            missing_proof="",
        )
    omission = _exactly_one(row["omissions"], "id", POLICY_QUESTION, relative)
    omission.update(
        state="runtime-unproven",
        resolution_state="requires-user-decision",
        resolution_evidence=(
            "SVN 964 proves the event precedes later cancellation and damage resolution, but pre-campaign "
            "master deliberately used this producer. Static evidence cannot decide whether those contacts "
            "should be excluded without changing accepted behavior."
        ),
        missing_proof="User-approved contact policy for cancelled, avoided, or zero-final-damage weapon contacts.",
        recommended_correction="Do not change the mechanic until the user selects the contact policy.",
        smallest_regression_test="After a policy decision, encode the selected cancelled/avoided/zero-damage behavior in a producer-order test.",
    )
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full relaunch, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "The pre-resolution contact policy requires a user decision before any behavior change.",
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
        overall_state="runtime-unproven",
    )
    proven_dimensions = (
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
    )
    for name in proven_dimensions:
        entry["dimensions"][name].update(
            classification="proven-correct",
            evidence="Current hook, SVN 964 producer/API evidence, and focused regression tests prove this static contract.",
        )
    entry["dimensions"]["performance"].update(
        classification="runtime-unproven",
        evidence="Static work is bounded to six body-part checks per eligible hit; no profiler capture exists.",
    )
    for finding_id in INTEGRATION_FINDINGS:
        finding = _exactly_one(artifact["verified_prior_findings"], "id", finding_id, relative)
        finding.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=(
                "Commit 2f98749 corrected the producer argument order and elapsed-time cooldown. "
                "Current tests fire the exact producer order and advance world time without synthetic hits."
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
    if matches and matches[0].get("priority_reason_code") != "invalid-shared-event-contract":
        raise ValueError(f"{relative}: unexpected {BLOCKER_IDENTITY} ownership")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY
    ]
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-brittle-fracture-contract-resolution-v1",
            "trait_id": TRAIT,
            "authority": "pre-campaign UTMods master",
            "accepted_intent": {
                "cost": -6,
                "trigger": "OnWeaponHitCharacter",
                "base_chance_percent": 4,
                "multiplier": 1.5,
                "effective_roll_percent": 6,
                "fracture_time": 21,
                "cooldown_in_game_seconds": 10,
                "scope": "single-player",
            },
            "historical_source_boundary": (
                "SomewhatTraits fall/collision behavior is evidence only and was not restored because "
                "pre-campaign UTMods master is the accepted behavior authority."
            ),
            "resolved_findings": [*FINDINGS, *INTEGRATION_FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6768",
                "PZCodebase/Java/source/zombie/GameTime.java:1175",
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:1153-1159",
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
                "exact four-argument producer order",
                "successful 6 percent path with deterministic roll",
                "multiplier at or below one",
                "elapsed cooldown without intervening hits",
                "all eligible parts already fractured",
                "same-process hook reload",
                "trait present and absent at new game",
            ],
            "preserved_surfaces": [
                "trait cost",
                "weapon-hit trigger",
                "base chance and multiplier",
                "fracture duration",
                "10-second cooldown intent",
                "registration and English copy",
            ],
            "open_policy_question": {
                "id": POLICY_QUESTION,
                "status": "requires-user-decision",
                "question": "Should cancelled, avoided, or zero-final-damage contacts be excluded even though pre-campaign master selected the pre-resolution event?",
            },
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop and current-build in-game hit, cooldown, and current-version save/load checks."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment"],
        }
    )


def _materialize(campaign: Path, plan: dict[str, bytes], overlay: Path) -> None:
    shutil.copytree(campaign, overlay, dirs_exist_ok=True)
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix="regenerate-brittle-plan-") as directory:
        overlay = Path(directory) / "campaign"
        _materialize(campaign, plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay)
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
        raise RuntimeError("Brittle output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Brittle output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-brittle-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_brittle.py")
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
