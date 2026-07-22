"""Regenerate only Martial Artist-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_albino as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_martial"
FINDINGS = ("UT6-MARTIAL-EVENT",)
OMISSIONS = ("IR0508-OM-011",)
DESCRIPTION = (
    "Your hands are lethal weapons. Each bare-hand hit spends 0.001 endurance and adds "
    "damage scaled by Short Blunt and pre-drain endurance. Normal bonus damage is 0.5 plus "
    "0.05 per level; critical bonus damage is 3.0 plus 0.3 per level. Critical chance is 5 "
    "percent plus 8 percentage points per level. The damage multiplier is pre-drain endurance "
    "plus 0.35. Each hit grants Short Blunt experience equal to twice the bonus damage. "
    "Mundane disables the bonus."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_martial.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_martial.lua"
)
INTEGRATION = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_batteringram.lua"
INTEGRATION_RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_batteringram.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_martial.md"
RESOLUTION = "change-impact/martial-event-and-formula-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_06.jsonl",
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
    raise KeyError(f"missing Martial Artist dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_06.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = base.base.shared.base._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimension = base.base.shared.base._dimension
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
            "Cost is 5; XP boosts are Fitness +1 and Small Blunt +1; there are no grants or exclusions; DisabledInMultiplayer is true.",
        ),
        "source_intent": dimension(
            "proven-correct",
            "Pre-campaign master and retune commit d92ca9c explicitly establish the accepted damage, critical-chance, endurance, XP, and feedback formulas.",
        ),
        "runtime_path": dimension(
            "proven-correct",
            "SVN 964 emits OnWeaponHitCharacter as wielder, target, weapon, damageSplit; commit 2f98749 corrected the listener to that order, then the bare-hand and trait gates reach the shared bonus helper before native hit processing continues.",
        ),
        "numbers": dimension(
            "proven-correct",
            "Normal bonus is (0.5 + 0.05L)*(E + 0.35), critical bonus is (3.0 + 0.3L)*(E + 0.35), chance is 5 + 8L percent, direct endurance cost is 0.001, and XP is twice bonus damage.",
        ),
        "cadence": dimension(
            "proven-correct", "Work occurs once for each qualifying bare-hand OnWeaponHitCharacter event."
        ),
        "cooldown": dimension("not-applicable", "The accepted per-hit implementation has no cooldown."),
        "reset_save_load": dimension(
            "runtime-unproven",
            "The trait owns no persistent state, item mutation, accumulator, or cached baseline.",
            "Repeated world entry and current-version save/load remain unobserved.",
        ),
        "java_lua": dimension(
            "proven-correct",
            "SVN 964 proves the four-argument event, nonnil wielder/weapon guard, BareHands HandWeapon/type contract, target health, Stats, perk, and XP surfaces used by the path.",
        ),
        "kahlua": dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua shapes and verified current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": dimension(
            "proven-correct",
            "The corrected listener matches the current engine emission and independently gates every effect on weapon type and current trait ownership; the normal shared-module load installs it once.",
        ),
        "stacking_interactions": dimension(
            "proven-correct",
            "Mundane suppresses the shared helper for direct hits and Battering Ram, while Battering Ram delegates the same formulas using its post-collision endurance.",
        ),
        "multiplayer": dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": dimension("proven-correct", "The exact English display name is Martial Artist."),
        "description": dimension(
            "proven-correct",
            "The English copy states the exact endurance cost, damage and chance formulas, endurance multiplier, XP formula, and Mundane boundary.",
        ),
        "localization": dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": dimension(
            "runtime-unproven",
            "Static behavior is cost 5 with the explicit d92ca9c retune formulas and two +1 XP boosts.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": dimension(
            "runtime-unproven",
            "The hit-event path is constant time, has no scans, and performs no per-frame work.",
            "No current-build profiler capture exists.",
        ),
        "tests": dimension(
            "proven-correct",
            "Focused tests cover engine argument order, exact normal and critical damage, endurance order, chance boundaries, gates, Mundane, Battering Ram delegation, exact copy, and parity.",
        ),
        "mocks": dimension(
            "proven-correct",
            "Mocks expose the four-argument event, controllable random rolls, perk levels, Stats, XP, target health, feedback, and real BareHands type used by the path.",
        ),
        "source_release_parity": dimension(
            "proven-correct",
            "Martial runtime, Battering Ram integration, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": dimension(
            "coverage-gap",
            "All Martial Artist-owned 42.0 runtime, integration, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != base.base.shared.base.CANONICAL_DIMENSIONS:
        raise RuntimeError("Martial Artist dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = base.base.shared.base._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Commit 2f98749 matches SVN 964 IsoGameCharacter.java:6768 exactly, and focused tests drive the four-argument order through production code with exact state changes."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua execution after full relaunch, repeated world entry, current-version save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Real sound and critical blood feedback, rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 IsoGameCharacter.java:6747-6790; IsoLivingCharacter.java:18,187-201; HandWeapon.java:2654-2655",
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
        INTEGRATION,
        INTEGRATION_RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        MOCKS,
        TESTS,
        ACTIVE_AUDIT,
    ):
        base.base.shared.base._update_fingerprints(
            artifact, source, base.base.shared.base._metadata(root, source)
        )
    plan[relative] = base.base.shared.base._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = base.base.shared.base._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
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
        raise ValueError(f"{relative}: Martial Artist review checklist drifted")
    omission = base.base.shared.base._exactly_one(row["omissions"], "id", OMISSIONS[0], relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence=(
            "Retune commit d92ca9c is pre-campaign authority for the exact formulas; corrected English and exact formula regressions now match it without changing runtime behavior."
        ),
        missing_proof="Rendered current-build English remains unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by exact Martial Artist numeric and English-copy regressions.",
    )
    row["verified_finding_ids"] = [*FINDINGS]
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Real sound and blood feedback, rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": base.base.shared.base._metadata(root, RUNTIME)["sha256"],
        "trait_release": base.base.shared.base._metadata(root, RELEASE)["sha256"],
        "integration_runtime": base.base.shared.base._metadata(root, INTEGRATION)["sha256"],
        "integration_release": base.base.shared.base._metadata(root, INTEGRATION_RELEASE)["sha256"],
        "definition_runtime": base.base.shared.base._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": base.base.shared.base._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": base.base.shared.base._metadata(root, SOURCE_UI)["sha256"],
        "english_release": base.base.shared.base._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = base.base.shared.base._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = base.base.shared.base._json_bytes(
        {
            "schema": "ut-martial-event-and-formula-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_retune": "d92ca9cacd70692479f101b4224a9c5bd4bba64d",
                "event_signature_correction": "2f98749c3ecaa323b5eb037c30a2ad98b43dc834",
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 5,
                "xp_boosts": {"Fitness": 1, "SmallBlunt": 1},
                "trigger": "each bare-hand OnWeaponHitCharacter event",
                "normal_bonus": "(0.5 + 0.05 * SmallBlunt level) * (pre-drain endurance + 0.35)",
                "critical_bonus": "(3.0 + 0.3 * SmallBlunt level) * (pre-drain endurance + 0.35)",
                "critical_chance_percent": "5 + 8 * SmallBlunt level",
                "direct_endurance_cost": 0.001,
                "xp_multiplier": 2,
                "mundane": "suppresses bonus damage, XP, and feedback",
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS, *OMISSIONS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6747-6790",
                "PZCodebase/Java/source/zombie/characters/IsoLivingCharacter.java:18,187-201",
                "PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java:2654-2655",
            ],
            "files": [
                base.base.shared.base._metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    INTEGRATION,
                    INTEGRATION_RELEASE,
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
                "exact four-argument engine event order",
                "level-5 critical damage and endurance snapshot order",
                "level-10 normal damage at half endurance",
                "level-0 and level-10 critical chance boundaries",
                "weapon and trait rejection",
                "Mundane suppression for direct and synergy callers",
                "Battering Ram shared-helper delegation",
                "exact English copy and source-release parity",
            ],
            "performance_model": (
                "One constant-time listener runs per weapon-hit event; rejected hits exit after simple guards, and qualifying hits perform no scans or per-frame work."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build bare-hand and Battering Ram observation, repeated world entry, current-version save/load, rendered English, balance, and profiler capture."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing accepted damage, chance, endurance, XP, cost, or XP-boost values",
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
        raise RuntimeError("Martial Artist output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Martial Artist output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-martial-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_martial.py")
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
