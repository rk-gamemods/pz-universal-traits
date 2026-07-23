"""Regenerate only Gordanite-owned campaign evidence and derived ledgers."""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import regenerate_humanhamster as base
from campaign_cli import no_arg_command

ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_gordanite"
RUNTIME_FINDING = "B04-gordanite-RUNTIME"
CLOSED_FINDINGS = (
    "IR0104-GORDANITE-DOUBLE-CALORIES",
    "IR0104-GORDANITE-HOOK-STACK",
    "IR0104-GORDANITE-ITEM-SCOPE",
)
FINDINGS = (RUNTIME_FINDING,)
FOOD_CROSS_FINDING = "XTF0104-FOOD-ITEM-MUTATION"
SHARED_BLOCKER = "shared-hook:item-consumption-wrapper-lifecycle"
GORDANITE_WRAPPER_QUEUE_ID = "finding:IR0104-GORDANITE-HOOK-STACK"
DESCRIPTION = "+2 to Cooking. Food you cook provides 50 percent more nutrition and calories."
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_gordanite.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_gordanite.lua"
)
HOOK = "UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua"
HOOK_RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/"
    "UT_ItemConsumptionHooks.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_gordanite.md"
RESOLUTION = "change-impact/gordanite-native-delta-resolution.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_04.jsonl",
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
    return HELPER._dimension(state, evidence, missing) if missing else HELPER._dimension(state, evidence)


def _input_bytes_lf(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def _input_metadata_lf(root: Path, relative: str) -> dict[str, object]:
    data = _input_bytes_lf(root / relative)
    return {
        "path": relative,
        "sha256": hashlib.sha256(data).hexdigest().upper(),
        "bytes": len(data),
    }


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_04.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _dimension("proven-correct", "Registry, definition, runtime id, and English keys agree."),
        "definition_parser": _dimension(
            "proven-correct", "Cost 4, Cooking +2, no grants or exclusions, and multiplayer-disabled metadata pass deterministic parsing."
        ),
        "namespace": _dimension("proven-correct", "Every owned surface uses UniversalTraits:UT_gordanite."),
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct", "Pre-campaign master and current source agree on cost 4, Cooking +2, and no grants or exclusions."
        ),
        "source_intent": _dimension(
            "proven-correct", "Pre-campaign master establishes food cooked by the player at 1.5 times native hunger relief and calories."
        ),
        "runtime_path": _dimension(
            "proven-correct", "The trait file is declaration-only; completed and interrupted eating snapshot immutable native deltas and add one half after one native call."
        ),
        "numbers": _dimension(
            "proven-correct", "Each independently positive native hunger-relief and calorie delta receives exactly a 0.5 additive correction."
        ),
        "cadence": _dimension(
            "proven-correct", "No tick or inventory scan exists; one correction follows each qualifying native complete or eat call."
        ),
        "cooldown": _dimension("not-applicable", "Gordanite has no cooldown or accumulator."),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "The accepted path owns no persistent food mutation or Gordanite modData.",
            "Current-version save/load and repeated world entry remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct", "SVN 964 complete and eat paths, chef access, meal stats, and nutrition deltas were statically traced."
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "The accepted implementation uses guarded Kahlua-compatible calls and independently protected identity getters.",
            "Actual current-build Kahlua execution remains unobserved.",
        ),
        "events": _dimension(
            "proven-correct", "Stable sentinels make repeated hook installation a no-op and preserve one native call and one effect."
        ),
        "stacking_interactions": _dimension(
            "proven-correct", "Gourmand and Gordanite add from one immutable native hunger delta for exactly 2.0 times relief; Wildsman is unchanged."
        ),
        "multiplayer": _dimension(
            "not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."
        ),
        "display": _dimension("proven-correct", "The exact English display name is Gordanite."),
        "description": _dimension(
            "proven-correct", "English accurately states Cooking +2 and 50 percent more nutrition and calories for food the player cooked."
        ),
        "localization": _dimension(
            "coverage-gap", "Exact English keys exist with source-release parity.", "No non-English UniversalTraits locale exists."
        ),
        "balance": _dimension(
            "runtime-unproven", "Cost 4, Cooking +2, and the accepted 1.5 multiplier are unchanged.", "No gameplay telemetry exists."
        ),
        "performance": _dimension(
            "runtime-unproven", "The accepted path performs bounded snapshots and constant-time corrections with no scans.", "No current-build profiler capture exists."
        ),
        "tests": _dimension(
            "proven-correct", "Focused 13/13 and full 586/586 cover identity fallbacks, fail-closed cases, immutable deltas, composition, returns, errors, and parity."
        ),
        "mocks": _dimension(
            "proven-correct", "Focused doubles independently fail username and full-name getters and model native hunger and calorie deltas."
        ),
        "source_release_parity": _dimension(
            "proven-correct", "The final review proved exact source-release parity and reported hook SHA-256 C4F91442FB1B0ACA042CA5311E5F986B061CD5702FEFC10739CAA1A0A8A0B6F9."
        ),
        "packaging": _dimension(
            "coverage-gap", "No release drift exists for Gordanite-owned runtime surfaces.", "The unrelated missing source poster remains open."
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Gordanite dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [RUNTIME, HOOK, TESTS, ACTIVE_AUDIT, RESOLUTION]
    runtime = HELPER._exactly_one(row["findings"], "id", RUNTIME_FINDING, relative)
    runtime.update(
        resolution_state="runtime-unproven",
        implementation_status="static-proof-complete-runtime-proof-retained",
        reproduction_evidence="Accepted static, test, review, and parity evidence is complete; no game launch was performed.",
        missing_proof="Actual current-build Kahlua/SVN 964 completed and interrupted meal consumption, repeated world entry, and save/load.",
        recommended_correction="Run the retained in-game proof checklist before runtime closure.",
    )
    row["unknowns"] = [
        "Actual current-build Kahlua/SVN 964 consumption remains unobserved.",
        "Full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
        "Rendered English, gameplay balance, and profiler observation remain unobserved.",
        "The missing source poster is unrelated and remains separate.",
    ]
    row["validation"] = {
        "accepted_runtime_commits": [
            "5b8b28fd2cac6198dadeb3c703f24706967aac9f",
            "6497d16ddc181cb387d069daa96c94ebcec2d549",
        ],
        "final_independent_review": "ACCEPT at 6497d16d after one rejected chef-identity fallback",
        "focused_suite": "13/13",
        "full_universaltraits_suite": "586/586",
        "accepted_review_reported_hook_sha256": "C4F91442FB1B0ACA042CA5311E5F986B061CD5702FEFC10739CAA1A0A8A0B6F9",
        "runtime_checks_unrun": ["game launch", "current-build Kahlua", "real meal consumption", "save/load"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = (
        "\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines))
        + "\n"
    ).encode("utf-8")


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (
        RUNTIME, RELEASE, HOOK, HOOK_RELEASE, SOURCE_UI, RELEASE_UI,
        SOURCE_DEFINITION, RELEASE_DEFINITION, SOURCE_REGISTRY, RELEASE_REGISTRY,
        MOCKS, TESTS, ACTIVE_AUDIT,
    ):
        HELPER._update_fingerprints(artifact, source, _input_metadata_lf(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_01_04.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    for omission_id in CLOSED_FINDINGS:
        omission = HELPER._exactly_one(row["omissions"], "id", omission_id, relative)
        omission.update(
            state="proven-correct",
            resolution_state="implemented-and-statically-validated",
            resolution_evidence="Accepted final behavior at 6497d16d removes persistent item mutation and scan ownership, uses immutable native deltas, and is duplicate-load safe.",
            remaining_runtime_proof="Actual current-build Kahlua/SVN 964 meal consumption remains unobserved.",
        )
    row.update(
        review_state="accepted",
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        resolution_record=RESOLUTION,
        superseding_review={
            "state": "accepted-static-resolution-runtime-unproven",
            "historical_review_preserved": True,
            "review_chronology": [
                {
                    "snapshot": "5b8b28fd2cac6198dadeb3c703f24706967aac9f",
                    "disposition": "changes-requested",
                    "finding": "Chef full-name fallback was lost when username lookup failed.",
                },
                {
                    "snapshot": "6497d16ddc181cb387d069daa96c94ebcec2d549",
                    "disposition": "accepted",
                    "finding": "Exact three-file identity correction accepted with focused 13/0 and full 586/0.",
                },
            ],
            "resolved_finding_ids": list(CLOSED_FINDINGS),
            "retained_finding_ids": [RUNTIME_FINDING],
        },
        unresolved_proof=[
            "Actual current-build Kahlua/SVN 964 completed and interrupted consumption remains unobserved.",
            "Full desktop relaunch, repeated world entry, and current-version save/load remain unobserved.",
            "Only English localization exists; gameplay balance and profiler evidence remain unobserved.",
        ],
    )
    cross = HELPER._exactly_one(artifact["cross_trait_findings"], "id", FOOD_CROSS_FINDING, relative)
    if TRAIT not in cross.get("affected_surfaces", []) and cross.get("state") != "proven-correct":
        raise ValueError("Gordanite is not the final owner of the food-item cross finding")
    cross.update(
        state="proven-correct",
        affected_surfaces=[],
        reproduction_evidence="Gourmand and Gordanite now compute consumption-time corrections from immutable native deltas without persistent item mutation.",
        missing_proof="Actual current-build Kahlua consumption remains unobserved for each trait.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Covered by Gordanite and Gourmand native-delta, transfer-state, composition, and parity tests.",
        resolution_state="implemented-and-statically-validated",
        resolution_evidence="Gordanite was the last remaining trait owner; accepted 6497d16d removes it and leaves no affected trait.",
    )
    row["release_parity"] = {
        "trait_source": _input_metadata_lf(root, RUNTIME)["sha256"],
        "trait_release": _input_metadata_lf(root, RELEASE)["sha256"],
        "hook_source": _input_metadata_lf(root, HOOK)["sha256"],
        "hook_release": _input_metadata_lf(root, HOOK_RELEASE)["sha256"],
        "accepted_review_reported_hook_sha256": "C4F91442FB1B0ACA042CA5311E5F986B061CD5702FEFC10739CAA1A0A8A0B6F9",
        "state": "proven-correct",
    }
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    hook_source = _input_metadata_lf(root, HOOK)
    hook_release = _input_metadata_lf(root, HOOK_RELEASE)
    if hook_source["sha256"] != hook_release["sha256"]:
        raise ValueError("Gordanite source/release hook parity mismatch")
    files = (
        RUNTIME, RELEASE, HOOK, HOOK_RELEASE, SOURCE_UI, RELEASE_UI,
        SOURCE_DEFINITION, RELEASE_DEFINITION, SOURCE_REGISTRY, RELEASE_REGISTRY,
        TESTS, MOCKS, ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-gordanite-native-delta-resolution-v1",
        "trait_id": TRAIT,
        "authority": {
            "pre_campaign_master": "a32f251e7cebdc27b533907b6b16c7aa135eb882",
            "accepted_runtime_commits": [
                "5b8b28fd2cac6198dadeb3c703f24706967aac9f",
                "6497d16ddc181cb387d069daa96c94ebcec2d549",
            ],
            "pz_snapshot": "SVN revision 964",
            "final_independent_review": {
                "verdict": "ACCEPT",
                "snapshot": "6497d16d",
                "focused": {"passed": 13, "failed": 0},
                "full_universaltraits": {"passed": 586, "failed": 0},
            },
        },
        "review_iterations": [
            {
                "snapshot": "5b8b28fd2cac6198dadeb3c703f24706967aac9f",
                "disposition": "changes-requested",
                "finding": "Username getter failure incorrectly prevented the independently valid full-name chef match.",
                "resolved_by": "6497d16ddc181cb387d069daa96c94ebcec2d549",
            },
            {
                "snapshot": "6497d16ddc181cb387d069daa96c94ebcec2d549",
                "disposition": "accepted",
                "finding": "Exact three-file correction preserves independent identity fallbacks and fail-closed invalid identities.",
                "resolved_by": None,
            },
        ],
        "accepted_intent": {
            "cost": 4,
            "cooking_xp": 2,
            "grants": [],
            "exclusions": [],
            "food_benefit_multiplier": 1.5,
            "english": DESCRIPTION,
        },
        "runtime_contract": {
            "trait_file": "declaration-only",
            "native_calls_per_action": 1,
            "delta_source": "immutable pre-native and post-native snapshots",
            "bonus": "0.5 of each independently positive hunger-relief and calorie delta",
            "chef_identity": "independently protected non-empty username or full name",
            "invalid_identity": "fail closed",
            "gourmand_composition": "exactly 2.0 times native hunger relief",
            "wildsman": "unchanged",
            "persistent_gordanite_state": False,
            "duplicate_load": "one wrapper and one effect",
            "native_returns_and_errors": "preserved",
        },
        "resolved_findings": list(CLOSED_FINDINGS),
        "resolved_cross_findings": [FOOD_CROSS_FINDING],
        "retained_runtime_findings": [RUNTIME_FINDING],
        "files": [_input_metadata_lf(root, source) for source in files],
        "accepted_review_reported_hook_sha256": "C4F91442FB1B0ACA042CA5311E5F986B061CD5702FEFC10739CAA1A0A8A0B6F9",
        "package_verification": {
            "release_drift": [],
            "known_unrelated": ["missing-source:poster.png"],
        },
        "retained_runtime_proof": [
            "full exit-to-desktop relaunch and current-build Kahlua load",
            "completed and interrupted real meal consumption",
            "username and full-name chef identity variants",
            "Gourmand composition and repeated world entry",
            "current-version save/load",
            "rendered English, gameplay balance, and profiler observation",
        ],
        "runtime_proof": "Unobserved; accepted static and standard-Lua evidence does not establish actual in-game Kahlua/SVN 964 consumption.",
        "non_goals": ["multiplayer", "backward migration", "deployment", "rebalance"],
    })


def _rewrite_shared_blocker(campaign: Path) -> None:
    path = campaign / "release_blocker_queue.json"
    artifact = json.loads(path.read_text(encoding="utf-8"))
    blocker = HELPER._exactly_one(artifact["identities"], "semantic_identity", SHARED_BLOCKER, str(path))
    queue_ids = blocker.get("queue_ids", [])
    if queue_ids.count(GORDANITE_WRAPPER_QUEUE_ID) > 1:
        raise ValueError("duplicate Gordanite wrapper queue ownership")
    blocker["queue_ids"] = [queue_id for queue_id in queue_ids if queue_id != GORDANITE_WRAPPER_QUEUE_ID]
    blocker["evidence_scope"] = (
        "The shared wrapper sentinel is statically corrected. Allergic, Antivaxxer, Addicted to Caffeine, "
        "and Pills Allergy records remain queued until their assigned trait closures reconcile them."
    )
    path.write_bytes(HELPER._json_bytes(artifact))


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
        "SOURCE_REGISTRY": SOURCE_REGISTRY,
        "RELEASE_REGISTRY": RELEASE_REGISTRY,
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
    original_metadata = HELPER._metadata
    try:
        for name, value in replacements.items():
            setattr(base, name, value)
        HELPER._metadata = _input_metadata_lf
        yield
    finally:
        HELPER._metadata = original_metadata
        for name, value in originals.items():
            setattr(base, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with tempfile.TemporaryDirectory(prefix="regenerate-gordanite-plan-") as directory:
        overlay = Path(directory) / "campaign"
        shutil.copytree(campaign, overlay, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        _rewrite_shared_blocker(overlay)
        with _configured_base():
            plan = base.build_plan(root, overlay)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Gordanite output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace=None) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Gordanite output set")
    with _configured_base():
        if replace is None:
            return base.commit_plan(plan, campaign)
        return base.commit_plan(plan, campaign, replace=replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_gordanite.py")
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
