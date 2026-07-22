"""Regenerate only Albino-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_batteringram as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_albino"
FINDINGS = ("B01-ALB-TIME",)
OMISSIONS = (
    "IR0104-ALBINO-CROSS-EXCLUSION",
    "IR0104-ALBINO-PHYSICAL-HARM",
)
DESCRIPTION = (
    "Sunlight wears you down. Every minute spent outdoors from 06:00 through 17:59 "
    "adds 0.03 stress and 0.02 fatigue, up to each meter's maximum."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_albino.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_albino.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_albino.md"
RESOLUTION = "change-impact/albino-daylight-contract.json"
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


def _old_dimension(dimensions: dict[str, Any], canonical: str, legacy: str | None = None) -> dict[str, Any]:
    for key in (canonical, legacy):
        if key is not None and key in dimensions:
            return dimensions[key]
    raise KeyError(f"missing Albino dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_01.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = base.shared.base._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimension = base.shared.base._dimension
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": dimension(
            "runtime-unproven",
            "The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": dimension(
            "proven-correct",
            "Cost is -4; there are no XP boosts or grants; Bad Teeth is reciprocally excluded; DisabledInMultiplayer is true.",
        ),
        "source_intent": dimension(
            "proven-correct",
            "Pre-campaign master and initial implementation e87e49d establish the accepted fixed outdoor daylight stress and fatigue effect. Commit 2f98749 corrected only the current engine time domain.",
        ),
        "runtime_path": dimension(
            "proven-correct",
            "EveryOneMinute resolves the player, gates on trait ownership and outdoor state, then applies the accepted effect from 06:00 inclusive through 18:00 exclusive.",
        ),
        "numbers": dimension(
            "proven-correct",
            "Each qualifying event adds exactly 0.03 stress and 0.02 fatigue, with both values capped at 1.0.",
        ),
        "cadence": dimension(
            "proven-correct",
            "The handler runs once per EveryOneMinute event and performs no per-frame polling.",
        ),
        "cooldown": dimension(
            "not-applicable", "The accepted implementation has no cooldown beyond its minute event cadence."
        ),
        "reset_save_load": dimension(
            "runtime-unproven",
            "Indoor and non-daylight events clear UT_albinoDamage; the next qualifying event sets it true.",
            "Repeated world entry and current-version save/load remain unobserved.",
        ),
        "java_lua": dimension(
            "proven-correct",
            "SVN 964 exposes EveryOneMinute, GameTime.getTimeOfDay on a 0-to-24 hour domain, player outdoor and trait queries, Stats accessors, and modData used by this path.",
        ),
        "kahlua": dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua shapes and current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": dimension(
            "proven-correct",
            "The shared module installs one EveryOneMinute handler under normal require caching, and the handler independently gates every effect on current trait ownership.",
        ),
        "stacking_interactions": dimension(
            "proven-correct",
            "Albino is reciprocally exclusive with Bad Teeth and otherwise composes through bounded Stats writes without shared item or global-object mutation.",
        ),
        "multiplayer": dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": dimension("proven-correct", "The exact English display name is Albino."),
        "description": dimension(
            "proven-correct",
            "The English copy states the exact daylight window, cadence, stress and fatigue increments, and caps without promising physical damage.",
        ),
        "localization": dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": dimension(
            "runtime-unproven",
            "Static behavior is cost -4 with fixed +0.03 stress and +0.02 fatigue per outdoor daylight minute.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": dimension(
            "runtime-unproven",
            "The low-frequency handler performs constant-time guards and at most two bounded Stats writes.",
            "No current-build profiler capture exists.",
        ),
        "tests": dimension(
            "proven-correct",
            "Focused tests cover exact deltas, caps, indoor and nighttime no-op behavior, flag transitions, 06:00 and 18:00 boundaries, exact copy, exclusions, and parity.",
        ),
        "mocks": dimension(
            "proven-correct",
            "The GameTime mock exposes a controllable 0-to-24 hour value, while player, Stats, trait, outdoor, event, and modData surfaces match the path under test.",
        ),
        "source_release_parity": dimension(
            "proven-correct",
            "Trait runtime, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": dimension(
            "coverage-gap",
            "All Albino-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != base.shared.base.CANONICAL_DIMENSIONS:
        raise RuntimeError("Albino dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = base.shared.base._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Commit 2f98749 expresses the accepted 06:00 through 17:59 window in the current engine's 0-to-24 hour domain; engine tracing and focused boundary tests prove the correction."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua execution after full relaunch, repeated world entry, current-version save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 GameTime.java:738,1050 and current hour-domain consumers",
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
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        MOCKS,
        TESTS,
        ACTIVE_AUDIT,
    ):
        base.shared.base._update_fingerprints(artifact, source, base.shared.base._metadata(root, source))
    plan[relative] = base.shared.base._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = base.shared.base._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
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
        base.shared.base._checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence="Pre-campaign Git authority, current source and release bytes, SVN 964 engine evidence, and focused regression tests prove this static Albino contract.",
            missing_proof="",
        )
    base.shared.base._checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="runtime-unproven",
        evidence="The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        base.shared.base._checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source, engine, and regression evidence is complete for the implemented Albino contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    base.shared.base._checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source and release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    base.shared.base._checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Albino runtime, definition, and English source and release content are exact.",
        missing_proof="Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
    )
    omission_evidence = {
        OMISSIONS[0]: (
            "Pre-campaign master contains both Albino/Bad Teeth exclusion directions, and upstream More Traits declares the same reciprocal pair."
        ),
        OMISSIONS[1]: (
            "The complete runtime path writes only stress, fatigue, and UT_albinoDamage; corrected English no longer promises physical harm, and an exact-copy regression prevents drift."
        ),
    }
    for omission_id, evidence in omission_evidence.items():
        omission = base.shared.base._exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state=(
                "proven-correct" if omission_id == OMISSIONS[0] else "implemented-and-statically-validated"
            ),
            resolution_evidence=evidence,
            missing_proof="Current-build in-game observation remains unrun.",
            recommended_correction="No further static correction is indicated.",
            smallest_regression_test="Covered by the focused Albino regression cases.",
        )
    row["verified_finding_ids"] = [*FINDINGS]
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": base.shared.base._metadata(root, RUNTIME)["sha256"],
        "trait_release": base.shared.base._metadata(root, RELEASE)["sha256"],
        "definition_runtime": base.shared.base._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": base.shared.base._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": base.shared.base._metadata(root, SOURCE_UI)["sha256"],
        "english_release": base.shared.base._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = base.shared.base._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = base.shared.base._json_bytes(
        {
            "schema": "ut-albino-daylight-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "initial_runtime_implementation": "e87e49d",
                "time_domain_correction": "2f98749c3ecaa323b5eb037c30a2ad98b43dc834",
                "upstream_reference": "More Traits reciprocal Albino/Bad Teeth exclusions",
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": -4,
                "trigger": "outdoors from 06:00 inclusive through 18:00 exclusive",
                "cadence": "EveryOneMinute",
                "stress_delta": 0.03,
                "fatigue_delta": 0.02,
                "meter_cap": 1.0,
                "activity_flag": "UT_albinoDamage",
                "exclusions": ["UniversalTraits:UT_badteeth"],
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS, *OMISSIONS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/GameTime.java:738,1050",
                RUNTIME,
            ],
            "files": [
                base.shared.base._metadata(root, source)
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
                "exact noon stress and fatigue deltas",
                "stress and fatigue caps at 1.0",
                "qualifying event sets the activity flag",
                "indoor and nighttime paths clear the activity flag without changing stats",
                "05:59, 06:00, 17:59, and 18:00 boundary opposition",
                "reciprocal Bad Teeth exclusion",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "One low-frequency handler runs per in-game minute, performs constant-time guards, and executes at most two bounded Stats writes plus one boolean modData write."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build daylight and boundary observation, repeated world entry, current-version save/load, rendered English, balance, and profiler capture."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "restoring upstream pain accumulation, umbrella mitigation, multiplayer commands, or its different daylight window",
            ],
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
        "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI,
        "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION,
        "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT,
        "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS,
        "_plan_batch": _plan_batch,
        "_plan_translation": base._plan_translation,
        "_plan_inventory": _plan_inventory,
        "_plan_review": _plan_review,
        "_plan_blocker": base._plan_blocker,
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
        raise RuntimeError("Albino output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Albino output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-albino-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_albino.py")
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
