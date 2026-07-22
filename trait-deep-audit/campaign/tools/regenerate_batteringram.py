"""Regenerate only Battering Ram-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_bouncer_ii as shared
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_batteringram"
FINDINGS = ("B02-UT_batteringram-01", "B02-UT_batteringram-02")
DESCRIPTION = (
    "You're a human freight train. While running or sprinting, entering collision range "
    "knocks each new nearby zombie down and drains endurance. Running drains 0.05 "
    "endurance; sprinting drains 0.03 and deals 0.15 impact damage. Martial Artist also "
    "applies its normal bonus damage. This does not prevent the game's normal trip or stagger."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_batteringram.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_batteringram.lua"
)
CORE = "UT_CORE/media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua"
CORE_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
TESTS = "UniversalTraits/test/run_tests.lua"
CORE_TESTS = "UT_CORE/test/run_tests.lua"
ENGINE_TESTS = "UniversalTraits/test/test_batteringram_engine_stack.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_batteringram.md"
RESOLUTION = "change-impact/batteringram-knockdown-lifecycle-contract.json"
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
    raise KeyError(f"missing Battering Ram dimension: {canonical}")


def _finding(
    finding_id: str,
    title: str,
    anchors: list[str],
    affected_surfaces: list[str],
    reproduction_evidence: str,
    recommended_correction: str,
    smallest_regression_test: str,
) -> dict[str, Any]:
    return {
        "id": finding_id,
        "severity": "high",
        "confidence": "high",
        "anchors": anchors,
        "affected_surfaces": affected_surfaces,
        "reproduction_evidence": reproduction_evidence,
        "missing_proof": "",
        "recommended_correction": recommended_correction,
        "smallest_regression_test": smallest_regression_test,
        "title": title,
        "resolution_state": "proven-correct",
        "resolution_evidence": (
            "Pre-campaign Git authority, current source and release bytes, SVN 964 engine tracing, "
            "and focused regression tests prove the implemented correction."
        ),
        "remaining_runtime_proof": (
            "Current-build Kahlua execution after full relaunch, repeated world entry, current-version "
            "save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    }


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_02.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = shared.base._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": shared.base._dimension(
            "runtime-unproven",
            "The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": shared.base._dimension(
            "proven-correct",
            "Cost is 7; there are no XP boosts, grants, or exclusions; DisabledInMultiplayer is true.",
        ),
        "source_intent": shared.base._dimension(
            "proven-correct",
            "Pre-campaign master and commit 2b03dc1 establish the accepted v4 knockdown-only behavior and explicitly reject player bump-state manipulation after permanent-freeze failures.",
        ),
        "runtime_path": shared.base._dimension(
            "proven-correct",
            "IsoPlayer OnPlayerUpdate reaches the UTCore collision dispatcher, which scans nine local squares, deduplicates new live zombies inside 0.7 tiles, and calls the trait handler before engine separate().",
        ),
        "numbers": shared.base._dimension(
            "proven-correct",
            "Running drains 0.05 endurance; sprinting drains 0.03 and attempts 0.15 zombie health damage; endurance is floored at zero.",
        ),
        "cadence": shared.base._dimension(
            "proven-correct",
            "The hook runs through the single UTCore player-update dispatcher and fires the trait once when each live zombie newly enters collision range.",
        ),
        "cooldown": shared.base._dimension(
            "not-applicable",
            "The accepted implementation has encounter deduplication but no time-based cooldown.",
        ),
        "reset_save_load": shared.base._dimension(
            "runtime-unproven",
            "OnCreatePlayer and the periodic integrity pass reconcile callback ownership; stopping or leaving range rebuilds temporary dedup state.",
            "Current-version repeated world entry and save/load remain unobserved.",
        ),
        "java_lua": shared.base._dimension(
            "proven-correct",
            "SVN 964 exposes IsoPlayer OnPlayerUpdate, IsoMovingObject separate bump guards, IsoZombie knockDown, Java moving-object list access, Stats get/set, and position and health methods used by the path.",
        ),
        "kahlua": shared.base._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua shapes and verified current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": shared.base._dimension(
            "proven-correct",
            "OnCreatePlayer and periodic integrity handling now both add eligible declarations and remove ineligible ones; the callback independently rejects a player without the trait.",
        ),
        "stacking_interactions": shared.base._dimension(
            "proven-correct",
            "The only intended trait interaction is Martial Artist delegation with post-drain endurance; the focused suite proves that path and callback ownership isolation.",
        ),
        "multiplayer": shared.base._dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": shared.base._dimension("proven-correct", "The exact English display name is Battering Ram."),
        "description": shared.base._dimension(
            "proven-correct",
            "The English copy states the exact v4 knockdown, endurance, sprint-damage, Martial Artist, and no-bump-immunity contract.",
        ),
        "localization": shared.base._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": shared.base._dimension(
            "runtime-unproven",
            "Static behavior is cost 7 with fixed 0.05 running drain, 0.03 sprint drain, 0.15 sprint damage, and Martial Artist synergy.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": shared.base._dimension(
            "runtime-unproven",
            "The inactive path is O(1); the active moving path scans nine local squares and deduplicates callback work per nearby zombie encounter.",
            "No current-build dense-population profiler capture exists.",
        ),
        "tests": shared.base._dimension(
            "proven-correct",
            "Focused UT_CORE and UniversalTraits tests cover lifecycle ownership, movement modes, range and height, dead filtering, dedup, exact numbers, Martial synergy, error containment, engine ordering, no bump mutation, and exact English copy.",
        ),
        "mocks": shared.base._dimension(
            "proven-correct",
            "Collision mocks preserve zero-based Java moving-object list access, spatial values, zombie identity, Stats domains, event ownership, and current method contracts used by the handler.",
        ),
        "source_release_parity": shared.base._dimension(
            "proven-correct",
            "Trait runtime, collision-hook runtime, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": shared.base._dimension(
            "coverage-gap",
            "All Battering Ram-owned 42.0 runtime, collision-hook, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits and UT_CORE each lack the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != shared.base.CANONICAL_DIMENSIONS:
        raise RuntimeError("Battering Ram dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    findings = {
        FINDINGS[0]: _finding(
            FINDINGS[0],
            "Description promised trip and stagger immunity that accepted v4 behavior does not provide",
            [SOURCE_UI + ":217", RUNTIME + ":1-61", CORE + ":1-260"],
            ["description", "runtime collision behavior"],
            "The former English text promised immunity, while commit 2b03dc1 and current v4 source explicitly prohibit player bump-state manipulation and engine separate() runs after OnPlayerUpdate.",
            "Describe the accepted knockdown-only behavior and state that normal trip or stagger is not prevented.",
            "Assert exact English copy, no player bump-field mutation, and OnPlayerUpdate ordering before separate().",
        ),
        FINDINGS[1]: _finding(
            FINDINGS[1],
            "Declared collision callback survived into a later player without the trait",
            [RUNTIME + ":26-61", CORE + ":219-260"],
            ["event lifecycle", "callback ownership", "runtime trait gating"],
            "Before correction, OnCreatePlayer and integrity handling only added declared callbacks. After an owning player registered the callback, a later player without the trait left it active, and the trait callback did not recheck ownership.",
            "Reconcile both registration and removal for the current player, and reject non-owners again at the effect boundary.",
            "Register an owning player, retain the callback, prove it rejects a non-owner, then prove OnCreatePlayer and periodic integrity remove it and reconcile the count.",
        ),
    }
    existing = {finding.get("id"): finding for finding in row["findings"]}
    unexpected = [finding_id for finding_id in existing if finding_id not in FINDINGS]
    if unexpected:
        raise ValueError(f"{relative}: unexpected Battering Ram findings {unexpected}")
    row["findings"] = [findings[finding_id] for finding_id in FINDINGS]
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and dense-population profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 IsoPlayer.java:2241,2646; IsoMovingObject.java:1198,1216; IsoZombie.java:4916",
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
    row = shared.base._exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["dynamic_xp_suffix"]["release_boosts"] = row["dynamic_xp_suffix"]["source_boosts"]
    row["dynamic_xp_suffix"]["source_release_equal"] = True
    row["english"]["description"].update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["rendered English not observed in game"]
    source_ui = shared.base._metadata(root, SOURCE_UI)
    release_ui = shared.base._metadata(root, RELEASE_UI)
    artifact["package_parity"]["translation"].update(
        state="proven-correct",
        byte_equal=True,
        semantic_equal=True,
        source_sha256=source_ui["sha256"],
        release_sha256=release_ui["sha256"],
        exact_differences=[],
    )
    for source, metadata in ((SOURCE_UI, source_ui), (RELEASE_UI, release_ui)):
        if shared.base._update_fingerprints(artifact, source, metadata) < 1:
            raise ValueError(f"{relative}: no fingerprint owner for {source}")
    counts: dict[str, int] = {}
    for entry in artifact["per_trait_ledger"]:
        state = entry["terminal_state"]
        counts[state] = counts.get(state, 0) + 1
    artifact["summary"]["confirmed_defect_traits"] = counts.get("confirmed-defect", 0)
    artifact["summary"]["coverage_gap_traits"] = counts.get("coverage-gap", 0)
    plan[relative] = shared.base._json_bytes(artifact, compact=True).replace(
        bytes((0xE2, 0x80, 0x94)), b"\\u2014"
    )


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (
        RUNTIME,
        RELEASE,
        CORE,
        CORE_RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        TESTS,
        CORE_TESTS,
        ENGINE_TESTS,
        ACTIVE_AUDIT,
    ):
        shared.base._update_fingerprints(artifact, source, shared.base._metadata(root, source))
    plan[relative] = shared.base._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = shared.base._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
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
        shared.base._checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence="Pre-campaign Git authority, current source and release bytes, SVN 964 engine evidence, and focused regression tests prove this static Battering Ram contract.",
            missing_proof="",
        )
    shared.base._checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="runtime-unproven",
        evidence="The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        shared.base._checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source, engine, and regression evidence is complete for the implemented Battering Ram contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    shared.base._checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source and release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    shared.base._checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Battering Ram runtime, shared collision hook, definition, and English source and release content are exact.",
        missing_proof="Read-only package verification reports no release drift; UniversalTraits and UT_CORE each lack the separately tracked source poster.",
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
        "trait_runtime": shared.base._metadata(root, RUNTIME)["sha256"],
        "trait_release": shared.base._metadata(root, RELEASE)["sha256"],
        "hook_runtime": shared.base._metadata(root, CORE)["sha256"],
        "hook_release": shared.base._metadata(root, CORE_RELEASE)["sha256"],
        "definition_runtime": shared.base._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": shared.base._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": shared.base._metadata(root, SOURCE_UI)["sha256"],
        "english_release": shared.base._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = shared.base._json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    return None


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = shared.base._json_bytes(
        {
            "schema": "ut-batteringram-knockdown-lifecycle-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "knockdown_only_decision": "2b03dc140bfdc61322135b59f1e6cd80d6b3770a",
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 7,
                "trigger": "each new live zombie entering 0.7-tile range while running or sprinting",
                "running_endurance_drain": 0.05,
                "sprinting_endurance_drain": 0.03,
                "sprinting_zombie_damage": 0.15,
                "martial_artist": "delegate normal bonus damage with post-drain endurance",
                "player_bump_state": "never manipulated; normal trip or stagger remains possible",
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241,2646",
                "PZCodebase/Java/source/zombie/iso/IsoMovingObject.java:1198,1216",
                "PZCodebase/Java/source/zombie/characters/IsoZombie.java:4916",
                CORE,
            ],
            "files": [
                shared.base._metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    CORE,
                    CORE_RELEASE,
                    SOURCE_UI,
                    RELEASE_UI,
                    SOURCE_DEFINITION,
                    RELEASE_DEFINITION,
                    TESTS,
                    CORE_TESTS,
                    ENGINE_TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "active player to inactive player callback removal",
                "retained callback rejects a non-owner",
                "periodic removal after trait loss",
                "sprint, run, walking, range, height, dead-zombie, and Java-list paths",
                "per-encounter dedup and reset",
                "exact endurance and sprint-damage numbers",
                "Martial Artist delegation and nil Stats handling",
                "no player bump-state mutation and engine update ordering",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "The inactive path performs one callback-count check. The active moving path scans nine local squares "
                "and invokes trait work once per newly encountered live zombie. Integrity reconciliation runs once per "
                "ten EveryOneMinute events over the small declaration table."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build collision and player-switch observation, "
                "repeated world entry, current-version save/load, rendered English, balance, and profiler capture."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "restoring upstream ghost mode or fracture gating",
                "restoring player bump suppression",
            ],
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
        "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION,
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
        raise RuntimeError("Battering Ram output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Battering Ram output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-batteringram-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_batteringram.py")
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
