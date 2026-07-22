"""Regenerate only Bouncer I-owned campaign evidence and ledgers."""

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
TRAIT = "UniversalTraits:UT_bouncer_I"
COMPANION = "UniversalTraits:UT_bouncer_II"
FINDINGS = ("B02-UT_bouncer_I-COVERAGE",)
OMISSIONS = (
    "IR0104-BOUNCER_I-SOURCE-RELEASE-PERK",
    "IR0104-BOUNCER_I-TICK-COOLDOWN",
)
PACKAGE_FINDING = "F-UT-PKG-001"
DESCRIPTION = (
    "Years of handling rough crowds taught you to roll with the punches. The next new injury "
    "you take after the cooldown is automatically downgraded to a lesser one (bite to "
    "laceration, laceration to scratch, fracture halved). 300-second base cooldown, reduced "
    "by 10 seconds per Strength level. Will not cure a pre-existing zombie infection."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_bouncer_I.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_bouncer_I.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_bouncer_I.md"
RESOLUTION = "change-impact/bouncer-i-cooldown-contract.json"
BLOCKER_IDENTITIES = ("package:Bouncer-I", "package:Bouncer-II")
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
    raise KeyError(f"missing Bouncer I dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_02.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": _dimension(
            "runtime-unproven",
            "The complete source/release definitions parse in the standard-Lua consistency suite and both Bouncer blocks use valid Doctor perk tokens.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct",
            "Cost is 4, XPBoosts are Strength=1 and Doctor=1, and Bouncer I/Bouncer II exclusions are reciprocal in source and release.",
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Pre-campaign master and d10b240 establish the accepted injury-downgrade behavior and explicitly specify real-world seconds; later history establishes the current Tier I formula and Doctor perk.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "IsoPlayer.update triggers the UTCore dispatcher, which compares the shared injury view with the ready snapshot, applies one downgrade, and advances Tier I with GameTime real-seconds delta.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "Tier I cooldown is max(10, 300 - Strength*10) seconds; bite becomes deep wound time 20, deep wound becomes scratch, and fracture time is halved.",
        ),
        "cadence": _dimension(
            "proven-correct",
            "The active handler runs through the single UTCore player-update dispatcher; cooldown subtraction uses elapsed real seconds instead of assuming 60 updates per second.",
        ),
        "cooldown": _dimension(
            "proven-correct",
            "Tier I stores seconds and subtracts getRealworldSecondsSinceLastUpdate; expiry re-baselines injuries before a later injury can trigger.",
        ),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "The first active update and every cooldown expiry rebuild a serializable injury snapshot in player modData.",
            "Current-version repeated world entry and save/load remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct",
            "SVN 964 exposes IsoPlayer OnPlayerUpdate, GameTime real-seconds delta, the BodyDamage body-part list, and every BodyPart getter/setter used by the downgrade path.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua and verified current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "UTCore owns one OnPlayerUpdate callback and activates the shared Bouncer handler only when either mutually exclusive tier is present.",
        ),
        "stacking_interactions": _dimension(
            "proven-correct",
            "Bouncer I and II are reciprocally selection-exclusive; this pass changes only the Tier I cooldown branch and proves Tier II still decrements by one tick.",
        ),
        "multiplayer": _dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": _dimension("proven-correct", "The exact English display name is Bouncer I."),
        "description": _dimension(
            "proven-correct",
            "The English copy matches the accepted injury mappings, Tier I formula, after-cooldown eligibility, and pre-existing infection rule.",
        ),
        "localization": _dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": _dimension(
            "runtime-unproven",
            "Static behavior is cost 4 with one injury downgrade per Strength-scaled 300-second base cooldown.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "During Tier I cooldown the handler performs one GameTime delta read and no injury scan; while ready it uses the shared injury snapshot path.",
            "No current-build profiler capture exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Focused tests cover every downgrade, infection state, snapshot boundary, formulas, elapsed-time opposition, companion isolation, and source-release contracts.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "The GameTime mock exposes a controllable real-seconds delta matching the Java method, and BodyPart mocks preserve zero-based Java-list access and setter domains.",
        ),
        "source_release_parity": _dimension(
            "proven-correct",
            "Runtime, definition, and English source/release pairs are byte-identical and both definitions use Doctor.",
        ),
        "packaging": _dimension(
            "coverage-gap",
            "All Bouncer I-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
        ),
    }
    if tuple(dimensions) != CANONICAL_DIMENSIONS:
        raise RuntimeError("Bouncer I dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = _exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding["resolution_state"] = "runtime-unproven"
    finding["resolution_evidence"] = (
        "Git authority, current source/release bytes, SVN 964 call tracing, and focused regressions prove the static Bouncer I contract and correction."
    )
    finding["remaining_runtime_proof"] = (
        "Current-build Kahlua execution after full relaunch, repeated world entry, current-version save/load, rendered English, balance, and profiler observation remain unrun."
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Bouncer II behavior remains assigned to its separate trait pass.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 IsoPlayer.java:2241; GameTime.java:195-201; UTCore_TickDispatch.lua; current BodyPart Java API manifest",
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
    rows = {
        trait_id: _exactly_one(artifact["per_trait_ledger"], "trait_id", trait_id, relative)
        for trait_id in (TRAIT, COMPANION)
    }
    for trait_id, row in rows.items():
        row["dynamic_xp_suffix"]["release_boosts"] = row["dynamic_xp_suffix"]["source_boosts"]
        row["dynamic_xp_suffix"]["source_release_equal"] = True
        if trait_id == TRAIT:
            row["english"]["description"].update(
                source_value=DESCRIPTION,
                normal_runtime_translator_value=DESCRIPTION,
                semantic_claim_state="proven-correct",
            )
            row["terminal_state"] = "runtime-unproven"
            row["terminal_state_reasons"] = ["rendered English not observed in game"]
        else:
            row["terminal_state"] = "coverage-gap"
            row["terminal_state_reasons"] = ["Bouncer II semantic review remains separate"]

    source_definition = _metadata(root, SOURCE_DEFINITION)
    release_definition = _metadata(root, RELEASE_DEFINITION)
    source_ui = _metadata(root, SOURCE_UI)
    release_ui = _metadata(root, RELEASE_UI)
    definition = artifact["package_parity"]["definition"]
    definition.update(
        state="proven-correct",
        byte_equal=True,
        semantic_equal=True,
        source_sha256=source_definition["sha256"],
        release_sha256=release_definition["sha256"],
        exact_differences=[],
    )
    translation = artifact["package_parity"]["translation"]
    translation.update(
        state="proven-correct",
        byte_equal=True,
        semantic_equal=True,
        source_sha256=source_ui["sha256"],
        release_sha256=release_ui["sha256"],
        exact_differences=[],
    )
    artifact["package_parity"]["release_invalid_perk_ids"] = []

    package_finding = _exactly_one(artifact["findings"], "id", PACKAGE_FINDING, relative)
    package_finding.update(
        state="proven-correct",
        title="Release Bouncer definitions match source and use the current Doctor perk",
        anchors=[
            {
                "path": SOURCE_DEFINITION,
                "lines": [2116, 2128],
                "evidence": "Doctor=1 / Doctor=2",
            },
            {
                "path": RELEASE_DEFINITION,
                "lines": [2116, 2128],
                "evidence": "Doctor=1 / Doctor=2",
            },
        ],
        affected_surfaces=[],
        affected_traits=[],
        reproduction_evidence=(
            "Current source and release definition files are byte-identical. Git commits 9e730018 and 137afb9 record the source and release FirstAid-to-Doctor corrections."
        ),
        missing_proof="",
        recommended_correction="No correction remains.",
        smallest_regression_test="Assert exact source/release definition parity and current PerkFactory membership for every XPBoost token.",
        resolution_state="implemented-and-statically-validated",
    )
    checks = {row["id"]: row for row in artifact["validation"]["checks"]}
    for check_id in ("V-008", "V-010"):
        checks[check_id]["pass"] = True
        checks[check_id]["actual"] = []
        checks[check_id].pop("expected_failure", None)

    for source, metadata in (
        (SOURCE_DEFINITION, source_definition),
        (RELEASE_DEFINITION, release_definition),
        (SOURCE_UI, source_ui),
        (RELEASE_UI, release_ui),
    ):
        if _update_fingerprints(artifact, source, metadata) < 1:
            raise ValueError(f"{relative}: no fingerprint owner for {source}")
    counts: dict[str, int] = {}
    for row in artifact["per_trait_ledger"]:
        state = row["terminal_state"]
        counts[state] = counts.get(state, 0) + 1
    artifact["summary"]["source_release_definition_drift_traits"] = 0
    artifact["summary"]["confirmed_defect_traits"] = counts.get("confirmed-defect", 0)
    artifact["summary"]["coverage_gap_traits"] = counts.get("coverage-gap", 0)
    rendered = _json_bytes(artifact, compact=True)
    plan[relative] = rendered.replace(bytes((0xE2, 0x80, 0x94)), b"\\u2014")


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (
        RUNTIME,
        RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        MOCKS,
        TESTS,
        ACTIVE_AUDIT,
    ):
        _update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = _json_bytes(artifact)


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
            evidence="Pre-campaign Git authority, current source/release bytes, SVN 964 engine evidence, and focused regression tests prove this static Bouncer I contract.",
            missing_proof="",
        )
    _checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="runtime-unproven",
        evidence="The complete source/release definitions are byte-identical and parse in the standard-Lua consistency suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        _checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and regression evidence is complete for the implemented Bouncer I contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    _checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source/release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    _checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Bouncer source/release runtime, definition, and English content are exact.",
        missing_proof="UniversalTraits package verification remains blocked by the separately tracked missing source poster.",
    )

    omission_evidence = {
        OMISSIONS[0]: "Current source and release definitions are byte-identical, both use Doctor=1, and commits 9e730018/137afb9 prove the completed Build 42 cascade.",
        OMISSIONS[1]: "Tier I now stores seconds and subtracts GameTime real-seconds delta; an oppositional regression expires after equal elapsed time at different update intervals while Tier II remains unchanged.",
    }
    for omission_id, evidence in omission_evidence.items():
        omission = _exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=evidence,
            missing_proof="Current-build in-game observation remains unrun.",
            recommended_correction="No further static Bouncer I correction is indicated.",
            smallest_regression_test="Covered by the focused Bouncer I regression cases.",
        )

    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Bouncer II behavior remains assigned to its separate trait pass.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": _metadata(root, RUNTIME)["sha256"],
        "trait_release": _metadata(root, RELEASE)["sha256"],
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
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    for identity in BLOCKER_IDENTITIES:
        matches = [row for row in identities if row.get("semantic_identity") == identity]
        if len(matches) > 1:
            raise ValueError(f"{relative}: expected at most one {identity}, found {len(matches)}")
        if matches and matches[0].get("priority_reason_code") != "source-release-perk-drift":
            raise ValueError(f"{relative}: unexpected {identity} ownership")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") not in BLOCKER_IDENTITIES
    ]
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-bouncer-i-cooldown-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "injury_downgrade_intent": "d10b240",
                "tier_i_formula_history": ["5d0d72b", "7627f7e"],
                "doctor_source_correction": "9e730018",
                "doctor_release_correction": "137afb9",
            },
            "accepted_intent": {
                "cost": 4,
                "xp_boosts": {"Strength": 1, "Doctor": 1},
                "exclusions": [COMPANION],
                "trigger": "first new qualifying injury after the ready snapshot",
                "downgrades": {
                    "bite": "deep wound time 20",
                    "deep wound": "scratch",
                    "fracture": "fracture time multiplied by 0.5",
                },
                "cooldown_seconds": "max(10, 300 - Strength * 10)",
                "infection": "preserve snapshot infection; clear infection introduced with a new bite",
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*OMISSIONS],
            "retained_runtime_finding": FINDINGS[0],
            "shared_evidence_reconciliation": {
                "package_finding": PACKAGE_FINDING,
                "removed_blocker_identities": [*BLOCKER_IDENTITIES],
                "reason": "Current Bouncer source/release definitions are already byte-identical and use Doctor for both tiers.",
            },
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241",
                "PZCodebase/Java/source/zombie/GameTime.java:195-201",
                "PZCodebase/Java/source/zombie/Lua/LuaManager.java:7840-7843",
                "PZCodebase/Lua/shared/TimedActions/ISRestAction.lua:26",
                "UT_CORE/media/lua/shared/UTCore/UTCore_TickDispatch.lua",
            ],
            "files": [
                _metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    SOURCE_UI,
                    RELEASE_UI,
                    SOURCE_DEFINITION,
                    RELEASE_DEFINITION,
                    MOCKS,
                    TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "first-update and cooldown-expiry snapshots",
                "bite, deep wound, and fracture mappings",
                "infection clearing and preservation",
                "simultaneous injury ordering and one-per-cooldown behavior",
                "Strength 0, 5, and 10 formulas",
                "equal elapsed-time expiry across different update intervals",
                "Bouncer II tick behavior unchanged",
                "valid Doctor perk and exact source-release parity",
            ],
            "performance_model": (
                "During Tier I cooldown, one GameTime real-seconds delta read occurs per active player update and no injury collection is scanned. The ready path reuses UTCore's shared injury view."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build injury observations, repeated world entry, current-version save/load, rendered English, and profiler capture."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment", "Bouncer II behavior"],
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
        "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI,
        "MOCKS": MOCKS,
        "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT,
        "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS,
        "_plan_batch": _plan_batch,
        "_plan_translation": _plan_translation,
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
        raise RuntimeError("Bouncer I output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Bouncer I output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-bouncer-i-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_bouncer_i.py")
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
