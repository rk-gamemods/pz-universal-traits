"""Regenerate only Bouncer II-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_bouncer_i as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_bouncer_II"
COMPANION = "UniversalTraits:UT_bouncer_I"
FINDINGS = ("B02-UT_bouncer_II-COVERAGE",)
OMISSIONS = (
    "IR0104-BOUNCER_II-SOURCE-RELEASE-PERK",
    "IR0104-BOUNCER_II-TICK-COOLDOWN",
)
DESCRIPTION = (
    "You have been hit so many times nothing fazes you. The next new injury you take after "
    "the cooldown is automatically downgraded to a lesser one (bite to laceration, "
    "laceration to scratch, fracture halved). 220-second base cooldown, reduced by 20 "
    "seconds per Strength level. Will not cure a pre-existing zombie infection."
)
RUNTIME = base.RUNTIME
RELEASE = base.RELEASE
SOURCE_UI = base.SOURCE_UI
RELEASE_UI = base.RELEASE_UI
SOURCE_DEFINITION = base.SOURCE_DEFINITION
RELEASE_DEFINITION = base.RELEASE_DEFINITION
MOCKS = base.MOCKS
TESTS = base.TESTS
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_bouncer_II.md"
RESOLUTION = "change-impact/bouncer-ii-cooldown-contract.json"
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
    raise KeyError(f"missing Bouncer II dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_02.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = base._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": _old_dimension(old, "registration"),
        "definition_parser": base._dimension(
            "runtime-unproven",
            "The complete source/release definitions parse in the standard-Lua consistency suite and both Bouncer blocks use valid Doctor perk tokens.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": _old_dimension(old, "namespace"),
        "cost_xp_grants_exclusions": base._dimension(
            "proven-correct",
            "Cost is 6, XPBoosts are Strength=2 and Doctor=2, and Bouncer I/Bouncer II exclusions are reciprocal in source and release.",
        ),
        "source_intent": base._dimension(
            "proven-correct",
            "Pre-campaign master and d10b240 establish the accepted injury-downgrade behavior and real-world-second timer; 7627f7e establishes the Tier II formula and infection rule.",
        ),
        "runtime_path": base._dimension(
            "proven-correct",
            "IsoPlayer.update triggers the UTCore dispatcher, which compares the shared injury view with the ready snapshot, applies one downgrade, and advances Tier II with GameTime real-seconds delta.",
        ),
        "numbers": base._dimension(
            "proven-correct",
            "Tier II cooldown is max(10, 220 - Strength*20) seconds; bite becomes deep wound time 20, deep wound becomes scratch, and fracture time is halved.",
        ),
        "cadence": base._dimension(
            "proven-correct",
            "The active handler runs through the single UTCore player-update dispatcher; cooldown subtraction uses elapsed real seconds instead of assuming 60 updates per second.",
        ),
        "cooldown": base._dimension(
            "proven-correct",
            "Tier II stores seconds and subtracts getRealworldSecondsSinceLastUpdate; expiry re-baselines injuries before a later injury can trigger.",
        ),
        "reset_save_load": base._dimension(
            "runtime-unproven",
            "The first active update and every cooldown expiry rebuild a serializable injury snapshot in player modData.",
            "Current-version repeated world entry and save/load remain unobserved.",
        ),
        "java_lua": base._dimension(
            "proven-correct",
            "SVN 964 exposes IsoPlayer OnPlayerUpdate, GameTime real-seconds delta, the BodyDamage body-part list, and every BodyPart getter/setter used by the downgrade path.",
        ),
        "kahlua": base._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible Lua and verified current Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": base._dimension(
            "proven-correct",
            "UTCore owns one OnPlayerUpdate callback and activates the shared Bouncer handler only when either mutually exclusive tier is present.",
        ),
        "stacking_interactions": base._dimension(
            "proven-correct",
            "Bouncer I and II are reciprocally selection-exclusive; both tiers now use the same elapsed-seconds storage and countdown contract.",
        ),
        "multiplayer": base._dimension(
            "not-applicable",
            "The definition disables the trait in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": base._dimension("proven-correct", "The exact English display name is Bouncer II."),
        "description": base._dimension(
            "proven-correct",
            "The English copy matches the accepted injury mappings, Tier II formula, after-cooldown eligibility, and pre-existing infection rule.",
        ),
        "localization": base._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": base._dimension(
            "runtime-unproven",
            "Static behavior is cost 6 with one injury downgrade per Strength-scaled 220-second base cooldown.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": base._dimension(
            "runtime-unproven",
            "During Tier II cooldown the handler performs one GameTime delta read and no injury scan; while ready it uses the shared injury snapshot path.",
            "No current-build profiler capture exists.",
        ),
        "tests": base._dimension(
            "proven-correct",
            "Focused tests cover every downgrade, infection state, snapshot boundary, Tier II formulas, elapsed-time opposition, Tier I retention, and source-release contracts.",
        ),
        "mocks": base._dimension(
            "proven-correct",
            "The GameTime mock exposes a controllable real-seconds delta matching the Java method, and BodyPart mocks preserve zero-based Java-list access and setter domains.",
        ),
        "source_release_parity": base._dimension(
            "proven-correct",
            "Runtime, definition, and English source/release pairs are byte-identical and both definitions use Doctor.",
        ),
        "packaging": base._dimension(
            "coverage-gap",
            "All Bouncer II-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "UniversalTraits package verification remains blocked only by the separately tracked missing source poster.",
        ),
    }
    if tuple(dimensions) != base.CANONICAL_DIMENSIONS:
        raise RuntimeError("Bouncer II dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = base._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding["resolution_state"] = "runtime-unproven"
    finding["resolution_evidence"] = (
        "Git authority, current source/release bytes, SVN 964 call tracing, and focused regressions prove the static Bouncer II contract and correction."
    )
    finding["remaining_runtime_proof"] = (
        "Current-build Kahlua execution after full relaunch, repeated world entry, current-version save/load, rendered English, balance, and profiler observation remain unrun."
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
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
    row = base._exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["dynamic_xp_suffix"]["release_boosts"] = row["dynamic_xp_suffix"]["source_boosts"]
    row["dynamic_xp_suffix"]["source_release_equal"] = True
    row["english"]["description"].update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["rendered English not observed in game"]
    counts: dict[str, int] = {}
    for entry in artifact["per_trait_ledger"]:
        state = entry["terminal_state"]
        counts[state] = counts.get(state, 0) + 1
    artifact["summary"]["confirmed_defect_traits"] = counts.get("confirmed-defect", 0)
    artifact["summary"]["coverage_gap_traits"] = counts.get("coverage-gap", 0)
    plan[relative] = base._json_bytes(artifact, compact=True).replace(
        bytes((0xE2, 0x80, 0x94)), b"\\u2014"
    )


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
        base._update_fingerprints(artifact, source, base._metadata(root, source))
    plan[relative] = base._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = base._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
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
        base._checked_dimension(row, dimension_id).update(
            state="proven-correct",
            evidence="Pre-campaign Git authority, current source/release bytes, SVN 964 engine evidence, and focused regression tests prove this static Bouncer II contract.",
            missing_proof="",
        )
    base._checked_dimension(row, "complete_script_definition_and_parser_validity").update(
        state="runtime-unproven",
        evidence="The complete source/release definitions are byte-identical and parse in the standard-Lua consistency suite.",
        missing_proof="Current-build ScriptManager parsing remains unobserved.",
    )
    for dimension_id in ("reset_and_save_load", "kahlua_compatibility", "balance", "performance_risk"):
        base._checked_dimension(row, dimension_id).update(
            state="runtime-unproven",
            evidence="Static source and regression evidence is complete for the implemented Bouncer II contract.",
            missing_proof="Current-build in-game observation remains required.",
        )
    base._checked_dimension(row, "localization_coverage_including_absent_locales").update(
        state="coverage-gap",
        evidence="Exact English source/release copy is proven.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    base._checked_dimension(row, "packaging_integrity").update(
        state="coverage-gap",
        evidence="Bouncer source/release runtime, definition, and English content are exact.",
        missing_proof="UniversalTraits package verification remains blocked by the separately tracked missing source poster.",
    )
    omission_evidence = {
        OMISSIONS[0]: "Current source and release definitions are byte-identical, both use Doctor=2, and commits 9e730018/137afb9 prove the completed Build 42 cascade.",
        OMISSIONS[1]: "Tier II now stores seconds and subtracts GameTime real-seconds delta; an oppositional regression expires after equal elapsed time at different update intervals.",
    }
    for omission_id, evidence in omission_evidence.items():
        omission = base._exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence=evidence,
            missing_proof="Current-build in-game observation remains unrun.",
            recommended_correction="No further static Bouncer II correction is indicated.",
            smallest_regression_test="Covered by the focused Bouncer II regression cases.",
        )
    row["review_state"] = "accepted"
    row["unresolved_proof"] = [
        "Current-build Kahlua execution, full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
    ]
    row["explicit_non_goals"] = ["multiplayer", "backward save migration", "deployment"]
    row["release_parity"] = {
        "trait_runtime": base._metadata(root, RUNTIME)["sha256"],
        "trait_release": base._metadata(root, RELEASE)["sha256"],
        "definition_runtime": base._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": base._metadata(root, RELEASE_DEFINITION)["sha256"],
        "english_runtime": base._metadata(root, SOURCE_UI)["sha256"],
        "english_release": base._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = base._json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    return None


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = base._json_bytes(
        {
            "schema": "ut-bouncer-ii-cooldown-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "injury_downgrade_intent": "d10b240",
                "tier_ii_formula_and_infection_history": "7627f7e",
                "doctor_source_correction": "9e730018",
                "doctor_release_correction": "137afb9",
            },
            "accepted_intent": {
                "cost": 6,
                "xp_boosts": {"Strength": 2, "Doctor": 2},
                "exclusions": [COMPANION],
                "trigger": "first new qualifying injury after the ready snapshot",
                "downgrades": {
                    "bite": "deep wound time 20",
                    "deep wound": "scratch",
                    "fracture": "fracture time multiplied by 0.5",
                },
                "cooldown_seconds": "max(10, 220 - Strength * 20)",
                "infection": "preserve snapshot infection; clear infection introduced with a new bite",
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*OMISSIONS],
            "retained_runtime_finding": FINDINGS[0],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241",
                "PZCodebase/Java/source/zombie/GameTime.java:195-201",
                "PZCodebase/Java/source/zombie/Lua/LuaManager.java:7840-7843",
                "PZCodebase/Lua/shared/TimedActions/ISRestAction.lua:26",
                "UT_CORE/media/lua/shared/UTCore/UTCore_TickDispatch.lua",
            ],
            "files": [
                base._metadata(root, source)
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
                "Strength 5, 9, and 10 Tier II formulas",
                "equal elapsed-time expiry across different update intervals",
                "retained Tier I elapsed-time behavior",
                "valid Doctor perk and exact source-release parity",
            ],
            "performance_model": (
                "During Tier II cooldown, one GameTime real-seconds delta read occurs per active player update and no injury collection is scanned. The ready path reuses UTCore's shared injury view."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build injury observations, repeated world entry, current-version save/load, rendered English, and profiler capture."
            ),
            "non_goals": ["multiplayer", "backward save migration", "deployment", "Bouncer I behavior"],
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
    originals = {name: getattr(base.shared, name) for name in replacements}
    try:
        for name, value in replacements.items():
            setattr(base.shared, name, value)
        yield
    finally:
        for name, value in originals.items():
            setattr(base.shared, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with _configured_shared():
        plan = base.shared.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Bouncer II output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Bouncer II output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-bouncer-ii-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_bouncer_ii.py")
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
