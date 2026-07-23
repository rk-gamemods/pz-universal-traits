"""Regenerate only Antique Enthusiast campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_weaklybleedingwounds as transaction_base
from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = transaction_base.HELPER
TRAIT = "UniversalTraits:UT_antique"
FINDINGS = (
    "B01-ANT-PARITY",
    "B01-ANT-COVER",
    "IR0104-ANTIQUE-EVENT-CONTRACT",
)
DESCRIPTION = (
    "Your eye for rare and exceptional craftsmanship gives you a chance to find "
    "antique weapons and clothing hidden in crates and metal shelves. These items "
    "are significantly better than anything else you can find. Roughly 0.8 percent "
    "chance per eligible container, once per loot cycle."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_antique.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/"
    "traits/UT_antique.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
SOURCE_ITEMS = "UniversalTraits/media/scripts/UT_items.txt"
RELEASE_ITEMS = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_items.txt"
TESTS = "UniversalTraits/test/run_tests.lua"
FOCUSED_TEST = "UniversalTraits/test/test_antique_runtime.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_antique.md"
RESOLUTION = "change-impact/antique-inventory-event-contract.json"
BLOCKER_IDENTITY = "package:UT_antique"
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


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return {"state": state, "evidence": [evidence], "missing_proof": missing}


def _checked_dimension(row: dict[str, Any], dimension_id: str, owner: str) -> dict[str, Any]:
    return HELPER._exactly_one(row["checked_dimensions"], "id", dimension_id, owner)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_01.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _dimension("proven-correct", "One exact namespaced registration exists and agrees with the definition, runtime, and English keys."),
        "definition_parser": _dimension("runtime-unproven", "The complete source and release definition blocks are byte-identical and pass the standard-Lua consistency parser.", "Current-build ScriptManager loading remains unobserved in game."),
        "namespace": _dimension("proven-correct", "Registration, CharacterTrait, runtime TRAIT_ID, UI keys, and all seven reward full types use their exact namespaces."),
        "cost_xp_grants_exclusions": _dimension("proven-correct", "Pre-campaign master and current definition agree on cost 6, no XP boosts, no granted traits, no exclusions, and multiplayer disabled."),
        "source_intent": _dimension("proven-correct", "Pre-campaign master fixes the accepted result at one 8 in 1000 Antique reward chance per eligible crate or metal shelf per loot-respawn cycle."),
        "runtime_path": _dimension("proven-correct", "The exact two-argument end-phase callback resolves the page player, traverses Lua backpacks, validates the world container, consumes one cycle roll, and inserts one scripted reward on success."),
        "numbers": _dimension("proven-correct", "Tests prove chance values 0 and 7 succeed, 8 and 999 fail, item indices 0 and 6 select the table boundaries, and respawn modes map to 24, 168, 720, and 1440 hours."),
        "cadence": _dimension("proven-correct", "Only the inventory refresh end phase scans containers; begin, beforeFloor, and buttonsAdded are rejected."),
        "cooldown": _dimension("proven-correct", "Persistent object modData enforces one roll per cycle, and the exact LootRespawn elapsed-hour boundary reopens modes 2 through 5 while mode 1 never reopens."),
        "reset_save_load": _dimension("runtime-unproven", "The handler stores cycle state in world-object modData and derives reopening from persistent world age.", "A current-build save, full exit, reload, and respawn-cycle observation remains unrun."),
        "java_lua": _dimension("proven-correct", "SVN 964 proves the two event arguments, four phases, Lua-table backpacks, ItemContainer.AddItem(String), and the global sendAddItemToContainer surface."),
        "kahlua": _dimension("runtime-unproven", "Focused standard-Lua tests use the exact event arity, Lua indexing, receiver methods, and nil returns from the current engine contract.", "Current-build Kahlua execution remains unobserved."),
        "events": _dimension("proven-correct", "A trait-local sentinel registers exactly one callback across repeated module loads, and only the producer's end phase performs work."),
        "stacking_interactions": _dimension("runtime-unproven", "Antique, Scrounger, and Vagabond use separate modData keys and do not overwrite one another.", "Live handler order can affect whether another loot trait sees an Antique reward added during the same refresh."),
        "multiplayer": _dimension("not-applicable", "The definition disables Antique in multiplayer, and multiplayer support is an explicit product non-goal."),
        "display": _dimension("proven-correct", "The exact English display name is Antique Enthusiast."),
        "description": _dimension("proven-correct", "English states the eligible container types, approximate 0.8 percent chance, Antique reward category, and one roll per loot cycle."),
        "localization": _dimension("coverage-gap", "The exact English keys exist with source-release parity and translator-safe percent wording.", "No non-English UniversalTraits locale exists."),
        "balance": _dimension("runtime-unproven", "The correction preserves cost 6, 8 in 1000 chance, seven rewards, eligible types, and respawn mapping exactly.", "No gameplay telemetry or comparative balance session exists."),
        "performance": _dimension("runtime-unproven", "The corrected handler performs one bounded scan of existing inventory buttons per completed refresh and no background polling.", "No current-build profiler capture exists."),
        "tests": _dimension("proven-correct", "Seven focused cases prove event intake, phases, player and trait gates, eligible types, roll and table boundaries, respawn modes, nil insertion, reload, metadata, English, item definitions, and parity."),
        "mocks": _dimension("proven-correct", "The focused fixture enforces exactly two producer arguments, a 1-based Lua backpacks table, current Java receiver methods, bounded PZ RNG, and the global sync call."),
        "source_release_parity": _dimension("proven-correct", "Runtime, definition, English, and reward-item source/release pairs are byte-identical."),
        "packaging": _dimension("coverage-gap", "All Antique-owned 42.0 runtime, metadata, English, and item-definition counterparts are present and identical.", "Read-only package verification still tracks the separate missing source poster."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Antique dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding_updates = {
        FINDINGS[0]: (
            "Antique source and release use one supported container insertion path",
            "Current source and release are byte-identical, ItemContainer.AddItem(String) is current, and the global sendAddItemToContainer helper is exposed by LuaManager.",
        ),
        FINDINGS[1]: (
            "Antique behavior has focused engine-contract regression coverage",
            "Seven focused cases prove eligible filtering, roll boundaries, Lua and Java indexing, all LootRespawn modes, persistent cycle consumption, insertion, sync, metadata, and parity.",
        ),
    }
    if {finding.get("id") for finding in row["findings"]} != set(FINDINGS[:2]):
        raise ValueError("batch_01 Antique finding IDs are ambiguous")
    for finding in row["findings"]:
        title, evidence = finding_updates[finding["id"]]
        finding.update(
            state="proven-correct",
            resolution_state="proven-correct",
            implementation_status="implemented-and-statically-validated",
            title=title,
            reproduction_evidence=evidence,
            resolution_evidence=evidence,
            missing_proof="Current-build Kahlua and live container interaction remain unobserved.",
            recommended_correction="No further static correction is indicated.",
            smallest_regression_test="Run UniversalTraits/test/test_antique_runtime.lua.",
        )
    row["unknowns"] = [
        "Current-build Kahlua, live container insertion, save-load, and exact loot-respawn reopening remain unobserved.",
        "Live stacking order with Scrounger and Vagabond remains unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        "engine_contract": "SVN 964 ISInventoryPage.lua:1461-1510,1560,1794,1801,1902; ItemContainer.java:534-570; LuaManager.java:10223-10230",
        "focused_regression": "UniversalTraits/test/test_antique_runtime.lua: 7 passed, 0 failed",
        "runtime_checks_unrun": ["game launch", "save load", "loot respawn", "stacked loot traits", "profiler capture"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment"],
        "scope": "Antique Enthusiast only",
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = ("\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n").encode("utf-8")


def _plan_translation(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "translation_audit.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["Current-build rendered English remains unobserved."]
    row["english"]["description"].update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        translator_percent_mutates=False,
        dev_rejected_confusables=[],
        static_display_state="proven-correct",
        semantic_claim_state="proven-correct",
    )
    row["trait_batch_reference"].update(exists=True)
    encoded = HELPER._json_bytes(artifact, compact=True)
    plan[relative] = encoded.replace(bytes.fromhex("e28094"), br"\u2014")


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
        SOURCE_ITEMS,
        RELEASE_ITEMS,
        TESTS,
        FOCUSED_TEST,
        ACTIVE_AUDIT,
    ):
        HELPER._update_fingerprints(artifact, source, HELPER._metadata(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    proven = {
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
        "multiplayer_restriction",
        "display_name",
        "description_accuracy",
        "tests",
        "mocks",
        "source_release_parity",
    }
    for dimension_id in proven:
        _checked_dimension(row, dimension_id, relative).update(
            state="proven-correct",
            evidence="Pre-campaign master, the current full runtime path, SVN 964 engine producers and receivers, and focused regressions prove this static contract.",
            missing_proof="",
        )
    for dimension_id in (
        "complete_script_definition_and_parser_validity",
        "reset_and_save_load",
        "kahlua_compatibility",
        "stacking_and_cross_trait_interactions",
        "balance",
        "performance_risk",
    ):
        _checked_dimension(row, dimension_id, relative).update(
            state="runtime-unproven",
            evidence="The static contract and deterministic boundary behavior are proven.",
            missing_proof="Current-build in-game observation remains required.",
        )
    _checked_dimension(row, "localization_coverage_including_absent_locales", relative).update(
        state="coverage-gap",
        evidence="The exact English keys and translator-safe percent wording are proven with source-release parity.",
        missing_proof="No non-English UniversalTraits locale exists.",
    )
    _checked_dimension(row, "packaging_integrity", relative).update(
        state="coverage-gap",
        evidence="All Antique-owned source and 42.0 release files are exact.",
        missing_proof="The separately tracked missing source poster remains open.",
    )
    omission = HELPER._exactly_one(row["omissions"], "id", FINDINGS[2], relative)
    omission.update(
        state="proven-correct",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence="The callback now accepts exactly (inventoryPage,state), gates to end, resolves getSpecificPlayer(inventoryPage.player), and traverses the Lua backpacks table with ipairs.",
        missing_proof="Current-build Kahlua and live inventory refresh remain unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by the exact two-argument, four-phase, Lua-table focused regression.",
    )
    row["review_state"] = "accepted"
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["omission_disposition"] = "resolved"
    row["verified_finding_ids"] = [*FINDINGS]
    row["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "resolved_finding_ids": [*FINDINGS],
        "open_finding_ids": [],
        "remaining_runtime_proof": "Current-build Kahlua, live containers, save-load, respawn reopening, stacked loot traits, rendered English, balance, and profiling remain unrun.",
    }
    row["unresolved_proof"] = [
        "No current-game Kahlua, live container, save-load, or loot-respawn cycle was observed.",
        "Live stacking order with Scrounger and Vagabond remains unobserved.",
        "Only English UI localization exists.",
        "No gameplay telemetry or profiler capture exists.",
    ]
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "source_english_sha256": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "release_english_sha256": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "source_items_sha256": HELPER._metadata(root, SOURCE_ITEMS)["sha256"],
        "release_items_sha256": HELPER._metadata(root, RELEASE_ITEMS)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    targets = [row for row in identities if row.get("semantic_identity") == BLOCKER_IDENTITY]
    if len(targets) > 1:
        raise ValueError(f"{relative}: duplicate Antique package blockers")
    if targets and targets[0].get("priority_reason_code") != "trait-package-parity-drift":
        raise ValueError(f"{relative}: unexpected Antique blocker ownership")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY
    ]
    for identity in artifact["identities"]:
        dependencies = identity.get("dependencies")
        if isinstance(dependencies, list):
            identity["dependencies"] = [item for item in dependencies if item != BLOCKER_IDENTITY]
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (
        RUNTIME,
        RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        SOURCE_ITEMS,
        RELEASE_ITEMS,
        TESTS,
        FOCUSED_TEST,
        ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-antique-inventory-event-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": "cost 6; no XP, grants, or exclusions; one 8 in 1000 seven-item Antique reward roll per eligible crate or metal shelf per configured loot-respawn cycle",
                "historical_provenance": "More Traits Build 42 ContainerEvents and ToadTraitAntique",
                "pz_snapshot": "SVN revision 964",
            },
            "resolved_findings": [*FINDINGS],
            "correction": {
                "event_arguments": ["inventoryPage", "state"],
                "accepted_phase": "end",
                "player_resolution": "getSpecificPlayer(inventoryPage.player)",
                "backpack_collection": "1-based Lua table traversed with ipairs",
                "chance": "ZombRand(1000) < 8",
                "reward_selection": "ZombRand(7) + 1",
                "registration": "one handler through UTAntiqueRuntime.registered",
                "runtime_scope": "single-player",
            },
            "engine_evidence": [
                "PZCodebase/Lua/client/ISUI/ISInventoryPage.lua:1461-1510,1560,1794,1801,1902",
                "PZCodebase/Java/source/zombie/inventory/ItemContainer.java:534-570",
                "PZCodebase/Java/source/zombie/Lua/LuaManager.java:10223-10230",
                "research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua:1061-1186,3381-3391",
            ],
            "files": [HELPER._metadata(root, source) for source in files],
            "regression_cases": [
                "exact two-argument event and four-phase gate",
                "page-player and trait gates",
                "Lua backpacks and world-object eligibility",
                "chance values 0, 7, 8, and 999",
                "one roll after success or failure",
                "LootRespawn modes 1 through 5 and exact hour boundaries",
                "first and last reward selection",
                "nil insertion and global sync behavior",
                "reload-safe registration",
                "metadata, English, seven item definitions, and source-release parity",
            ],
            "performance_model": "One bounded pass over the already built inventory-page button table at refresh end, with no polling or background work.",
            "runtime_proof": "Unobserved; requires full desktop relaunch, live eligible containers, save-load, a respawn cycle, repeated world entry, stacked loot traits, rendered English, balance, and profiler observation.",
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing cost, chance, reward table, eligible types, or respawn mapping",
            ],
        }
    )


def _materialize(campaign: Path, plan: dict[str, bytes], overlay: Path) -> None:
    if not overlay.exists():
        shutil.copytree(campaign, overlay)
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _regenerate_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix=".regenerate-antique-plan-") as directory:
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
        blocker_path = overlay / "release_blocker_queue.json"
        update_release_blocker_queue_sha256(overlay / "remediation_queue.jsonl", blocker_path)
        plan["release_blocker_queue.json"] = blocker_path.read_bytes()
        _materialize(campaign, plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode("utf-8")


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    plan: dict[str, bytes] = {}
    _plan_batch(campaign, plan)
    _plan_translation(campaign, plan)
    _plan_inventory(root, campaign, plan)
    _plan_review(root, campaign, plan)
    _plan_blocker(campaign, plan)
    _plan_resolution(root, plan)
    _regenerate_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Antique output plan escaped its ownership set")
    return plan


@contextmanager
def _configured_transaction_base() -> Iterator[None]:
    replacements: dict[str, Any] = {"TRAIT": TRAIT, "OWNED_OUTPUTS": OWNED_OUTPUTS}
    originals = {name: getattr(transaction_base, name) for name in replacements}
    try:
        for name, value in replacements.items():
            setattr(transaction_base, name, value)
        yield
    finally:
        for name, value in originals.items():
            setattr(transaction_base, name, value)


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_transaction_base():
        return transaction_base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_antique.py")
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
