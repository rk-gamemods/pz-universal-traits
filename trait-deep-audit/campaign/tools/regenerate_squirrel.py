"""Regenerate only Squirrel-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import regenerate_owlperson as transaction
import regenerate_martial as base
from campaign_cli import no_arg_command

ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.base.base.shared.base
TRAIT = "UniversalTraits:UT_squirrel"
FINDINGS = ("B11-SQUIRREL-001", "B11-SQUIRREL-002")
DESCRIPTION = (
    "While running or sprinting, removes exactly 0.0015 fatigue every in-game minute. "
    "Walking and idling receive no benefit."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_squirrel.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_squirrel.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_squirrel.md"
RESOLUTION = "change-impact/squirrel-fatigue-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl", "source_inventory.json", "translation_audit.json",
    "independent_reviews/traits_09_12.json", "release_blocker_queue.json", RESOLUTION,
    "final_trait_ledger.json", "final_trait_ledger_rows.jsonl", "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl", "remediation_summary.json", "campaign_manifest.json",
)


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing) if missing else HELPER._dimension(state, evidence)


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_11.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": old["registration"],
        "definition_parser": _dimension("runtime-unproven", "Source and release definitions are byte-identical and pass the static consistency suite.", "Current-build ScriptManager parsing remains unobserved in game."),
        "namespace": old["namespace"],
        "cost_xp_grants_exclusions": _dimension("proven-correct", "Cost is 2; no XP boosts or grants; Pack Mouse, Top Heavy, and Sloth are bidirectionally excluded; multiplayer is disabled."),
        "source_intent": _dimension("proven-correct", "Upstream and the original UT port identify Squirrel as running/sprinting fatigue relief; pre-campaign translation regeneration introduced the unrelated carry copy."),
        "runtime_path": _dimension("proven-correct", "EveryOneMinute resolves the active player, gates trait ownership and running/sprinting, then removes FATIGUE."),
        "numbers": _dimension("proven-correct", "Each qualifying event removes the fixed constant 0.0015 with the native zero floor and no GameTime multiplier."),
        "cadence": _dimension("proven-correct", "One constant sample per EveryOneMinute event; focused tests prove multiplier invariance."),
        "cooldown": _dimension("not-applicable", "No cooldown beyond the minute cadence."),
        "reset_save_load": _dimension("runtime-unproven", "The path owns no persistent state and reload registration is statically idempotent.", "Repeated world entry and current-version save/load remain unobserved."),
        "java_lua": _dimension("proven-correct", "SVN 964 anchors EveryOneMinute production and Stats.remove(CharacterStat.FATIGUE, float), including bounded Stats.set behavior."),
        "kahlua": _dimension("runtime-unproven", "The source uses compatible Lua shapes and verified receivers.", "Current-build Kahlua execution remains unobserved."),
        "events": _dimension("proven-correct", "The shared periodic wrapper samples getPlayer once per EveryOneMinute firing and replaces the same trait/event handler on reload."),
        "stacking_interactions": _dimension("proven-correct", "Bidirectional Pack Mouse, Top Heavy, and Sloth exclusions match the accepted UT contract; no shared item or global mutation occurs."),
        "multiplayer": _dimension("not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."),
        "display": _dimension("proven-correct", "The exact English display name is Squirrel."),
        "description": _dimension("proven-correct", "English names the exact trigger, fixed 0.0015 per-minute fatigue removal, and idle/walking non-benefit without claiming carry behavior."),
        "localization": _dimension("coverage-gap", "Exact English keys exist with source/release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _dimension("runtime-unproven", "The accepted static contract is a cost-2 conditional 0.0015 fatigue refund.", "No gameplay balance telemetry exists."),
        "performance": _dimension("runtime-unproven", "The minute handler performs constant-time guards and one bounded stat removal.", "No current-build profiler capture exists."),
        "tests": _dimension("proven-correct", "Focused tests cover running, sprinting, idle, walking, no trait, exact amount, multiplier invariance, zero clamp, reload replacement, exclusions, description, and parity."),
        "mocks": _dimension("proven-correct", "Controllable movement, fatigue, multiplier, event, trait, definition, translation, and parity fixtures exercise the exact path."),
        "source_release_parity": _dimension("proven-correct", "Runtime, UI, definition, registries, tests, and mocks are fingerprinted; all packaged source/release pairs are byte-identical."),
        "packaging": _dimension("coverage-gap", "Squirrel-owned 42.0 runtime, UI, definition, and registry counterparts are present and identical.", "The existing UniversalTraits source poster issue remains separately open."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Squirrel dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    for finding in row["findings"]:
        finding.update(
            resolution_state="proven-correct",
            resolution_evidence=(
                "Accepted commit e4ed870d28bafadd30ae6e18559e7e6308aaefb8 plus exact static, "
                "regression, exclusion, copy, mock, and parity evidence resolves this defect."
            ),
            missing_proof="",
            remaining_runtime_proof=(
                "Current-build Kahlua/gameplay, live minute and fast-forward behavior, repeated world entry, "
                "save/load, rendered English, balance, and profiler observation remain unrun."
            ),
        )
    row["unknowns"] = [
        "Current-build Kahlua/gameplay, live minute and fast-forward behavior, repeated world entry, and save/load remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists; the package source poster issue remains open.",
        "Upstream timer, day-length, and sleep-trait rules are intentionally outside the accepted UT contract.",
    ]
    row["validation"] = {
        "engine_contract": "SVN 964 EveryOneMinute and Stats.remove/Stats.set anchors",
        "behavior_commit": "e4ed870d28bafadd30ae6e18559e7e6308aaefb8",
        "static_regression": "UniversalTraits standard-Lua focused Squirrel cases",
        "runtime_checks_unrun": ["game launch", "live fast-forward", "current-version save-load", "profiler capture"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment", "upstream timing/sleep rules"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = ("\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n").encode()


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
                   SOURCE_REGISTRY, RELEASE_REGISTRY, MOCKS, TESTS, ACTIVE_AUDIT):
        HELPER._update_fingerprints(artifact, source, HELPER._metadata(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "accepted"
    row["supported_accepted_finding_ids"] = list(FINDINGS)
    row["rejected_accepted_finding_ids"] = []
    row["omissions"] = []
    row["omission_disposition"] = "no Squirrel-specific omission remains; exact cross-trait proof gaps are retained"
    row["unresolved_runtime_proof_ids"] = ["RP0912-KAHLUA-001", "RP0912-SAVELOAD-001", "RP0912-BALANCE-PERF-001", "RP0912-LOCALE-001"]
    row["resolution_record"] = RESOLUTION
    row["release_parity"] = {
        "runtime_source": HELPER._metadata(root, RUNTIME)["sha256"],
        "runtime_release": HELPER._metadata(root, RELEASE)["sha256"],
        "ui_source": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "ui_release": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "definition_source": HELPER._metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": HELPER._metadata(root, RELEASE_DEFINITION)["sha256"],
        "registry_source": HELPER._metadata(root, SOURCE_REGISTRY)["sha256"],
        "registry_release": HELPER._metadata(root, RELEASE_REGISTRY)["sha256"],
        "tests": HELPER._metadata(root, TESTS)["sha256"],
        "mocks": HELPER._metadata(root, MOCKS)["sha256"],
        "state": "proven-correct",
    }
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
             SOURCE_REGISTRY, RELEASE_REGISTRY, TESTS, MOCKS, ACTIVE_AUDIT)
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-squirrel-fatigue-contract-v1",
        "trait_id": TRAIT,
        "authority": {
            "accepted_behavior_commit": "e4ed870d28bafadd30ae6e18559e7e6308aaefb8",
            "campaign_runner_correction": "c0cc3bb763fa072a3a245b949550c22020d4316b",
            "pz_snapshot": "SVN revision 964",
        },
        "accepted_intent": {
            "cost": 2, "trigger": "running or sprinting at EveryOneMinute sample",
            "fatigue_removal": 0.0015, "game_time_multiplier": False,
            "xp_boosts": [], "grants": [],
            "exclusions": ["UniversalTraits:UT_packmouse", "UniversalTraits:UT_topheavy", "UniversalTraits:UT_sloth"],
            "multiplayer": False,
        },
        "provenance": {
            "fatigue_identity": "present in upstream evidence and the original UT port",
            "carry_mismatch": "introduced by pre-campaign bulk translation regeneration",
            "excluded_upstream_rules": ["tick cadence", "day-length multiplier", "sleep-trait modifiers"],
        },
        "resolved_findings": list(FINDINGS),
        "retained_runtime_proof": [
            "current-build Kahlua/gameplay", "live minute and fast-forward behavior",
            "repeated world entry and current-version save/load", "rendered English",
            "balance telemetry", "profiler capture", "non-English localization", "source poster issue",
        ],
        "files": [HELPER._metadata(root, source) for source in files],
        "runtime_proof": "Unobserved; static evidence does not establish current-version gameplay execution.",
        "non_goals": ["multiplayer", "backward save migration", "deployment", "upstream timing/day-length/sleep rules"],
    })


@contextmanager
def _configured_base() -> Iterator[None]:
    replacements = {
        "TRAIT": TRAIT, "FINDINGS": FINDINGS, "DESCRIPTION": DESCRIPTION, "RUNTIME": RUNTIME,
        "RELEASE": RELEASE, "SOURCE_UI": SOURCE_UI, "RELEASE_UI": RELEASE_UI,
        "SOURCE_DEFINITION": SOURCE_DEFINITION, "RELEASE_DEFINITION": RELEASE_DEFINITION,
        "MOCKS": MOCKS, "TESTS": TESTS, "ACTIVE_AUDIT": ACTIVE_AUDIT, "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS, "_plan_batch": _plan_batch, "_plan_inventory": _plan_inventory,
        "_plan_review": _plan_review, "_plan_resolution": _plan_resolution,
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
        raise RuntimeError("Squirrel output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace=transaction.os.replace) -> list[str]:
    original = transaction.OWNED_OUTPUTS
    try:
        transaction.OWNED_OUTPUTS = OWNED_OUTPUTS
        return transaction.commit_plan(plan, campaign, replace)
    finally:
        transaction.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_squirrel.py")
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
