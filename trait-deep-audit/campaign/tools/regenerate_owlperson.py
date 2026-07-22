"""Regenerate only Night Owl-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_martial as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.base.base.shared.base
TRAIT = "UniversalTraits:UT_owlperson"
FINDINGS = (
    "B07-UT_owlperson-timeofday-domain",
    "B07-UT_owlperson-runtime-proof",
)
DESCRIPTION = (
    "You come alive after dark. Every minute from 18:00 through 05:59 reduces stress by "
    "0.02, down to 0. Every minute from 06:00 through 17:59 increases stress by 0.02, up "
    "to 1. The two 12-hour windows use equal and opposite rates. The effect does not depend "
    "on sleep or location."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_owlperson.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_owlperson.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_owlperson.md"
RESOLUTION = "change-impact/owlperson-circadian-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_07.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_05_08.json",
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
    raise KeyError(f"missing Night Owl dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_07.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": HELPER._dimension(
            "runtime-unproven",
            "The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is -1; there are no XP boosts or grants; Early Bird is reciprocally excluded; DisabledInMultiplayer is true.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master and balance commit df41a15 explicitly establish equal absolute +0.02 daytime and -0.02 nighttime stress rates across two 12-hour windows.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "EveryOneMinute resolves the current player, gates trait ownership, reads the 0-to-24 engine hour, and performs one bounded stress write in the correct branch.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "Night subtracts exactly 0.02 with a zero floor; day adds exactly 0.02 with a one cap.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct", "The handler runs once per EveryOneMinute event and performs no per-frame polling."
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "The accepted implementation has no cooldown beyond its minute event cadence."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "The trait owns no persistent state, item mutation, accumulator, or cached baseline.",
            "Repeated world entry and current-version save/load remain unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 exposes EveryOneMinute, GameTime.getTimeOfDay on a 0-to-24 hour domain, player trait lookup, Stats get/set, and CharacterStat.STRESS used by the path.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua shapes and verified current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "The normal shared-module load installs one low-frequency handler, which independently gates every effect on current trait ownership.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "Night Owl is reciprocally exclusive with Early Bird and otherwise composes through the bounded shared stress value without shared item or global-object mutation.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension("proven-correct", "The exact English display name is Night Owl."),
        "description": HELPER._dimension(
            "proven-correct",
            "The English copy states the exact windows, deltas, clamps, equal nominal rates, and unconditional sleep/location scope without guaranteeing a net endpoint.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior is cost -1 with equal absolute 0.02 stress rates in two 12-hour windows.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "The low-frequency handler performs constant-time guards and one bounded Stats write for an owner.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact deltas, both clamps, missing-trait rejection, all hour boundaries, reciprocal exclusion, exact copy, and parity.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "The GameTime mock exposes a controllable 0-to-24 hour value, while player, Stats, trait, event, and translation fixtures match the path under test.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct", "Night Owl runtime, definition, and English source and 42.0 release pairs are byte-identical."
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All Night Owl-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Night Owl dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    time_finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    time_finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Commit 2f98749 expresses the accepted 18:00 through 05:59 window in the engine's 0-to-24 hour domain; engine tracing and focused boundary tests prove the correction. English also no longer overpromises a guaranteed net-zero endpoint."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua execution after full relaunch, repeated world entry, current-version save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    runtime_finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[1], relative)
    runtime_finding.update(
        resolution_state="runtime-unproven",
        resolution_evidence=(
            "Static source, engine, regression, copy, exclusion, parity, and packaging evidence is complete for the modeled contract."
        ),
        missing_proof=(
            "Fresh current-build full-relaunch gameplay must observe selection, both time boundaries, clamps, sleep/location scope, repeated world entry, and current-version save/load."
        ),
        remaining_runtime_proof=(
            "Current-build Kahlua, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, sleep/location behavior, balance telemetry, and profiler capture remain unobserved.",
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
        HELPER._update_fingerprints(artifact, source, HELPER._metadata(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    expected_checked = {
        "membership_registration_definition_ui",
        "runtime_and_exact_shared_dependencies",
        "engine_signatures_java_lua_kahlua",
        "time_scale_cadence_cooldowns",
        "save_load_reset_and_trait_removal",
        "persistent_global_item_player_state",
        "hook_registration_reentry_and_stacking",
        "script_only_and_shared_path_behavior",
        "mutual_exclusions_and_cross_trait_interactions",
        "description_numbers_and_en_locale",
        "tests_mocks_and_engine_fidelity",
        "source_release_and_42_0_package_parity",
    }
    if set(row["checked_dimensions"]) != expected_checked:
        raise ValueError(f"{relative}: Night Owl review checklist drifted")
    row["verified_finding_ids"] = [*FINDINGS]
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, sleep/location behavior, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": HELPER._metadata(root, RUNTIME)["sha256"],
        "trait_release": HELPER._metadata(root, RELEASE)["sha256"],
        "definition_runtime": HELPER._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": HELPER._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "english_release": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-owlperson-circadian-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "balanced_rates_decision": "df41a151c99cb2901577aff3c0a8a16013adf004",
                "time_domain_correction": "2f98749c3ecaa323b5eb037c30a2ad98b43dc834",
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": -1,
                "night_window": "18:00 inclusive through 06:00 exclusive",
                "night_stress_delta": -0.02,
                "day_window": "06:00 inclusive through 18:00 exclusive",
                "day_stress_delta": 0.02,
                "stress_domain": [0, 1],
                "sleep_or_location_gate": False,
                "exclusions": ["UniversalTraits:UT_larkperson"],
                "runtime_scope": "single-player",
            },
            "resolved_findings": [FINDINGS[0]],
            "retained_runtime_findings": [FINDINGS[1]],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/GameTime.java:738,1050",
                RUNTIME,
            ],
            "files": [
                HELPER._metadata(root, source)
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
                "exact nighttime -0.02 stress delta",
                "exact daytime +0.02 stress delta",
                "zero floor and one cap",
                "missing-trait rejection",
                "00:00, 05:59, 06:00, 17:59, 18:00, and 23:59 boundaries",
                "reciprocal Early Bird exclusion",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "One low-frequency handler runs per in-game minute, performs constant-time guards, and executes one bounded Stats write for an owner."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build time-boundary, clamp, sleep/location, repeated-world-entry, current-version save/load, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "restoring upstream fatigue or panic mechanics, windows, or cadences",
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
        "MOCKS": MOCKS,
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
        raise RuntimeError("Night Owl output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Night Owl output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-owlperson-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_owlperson.py")
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
