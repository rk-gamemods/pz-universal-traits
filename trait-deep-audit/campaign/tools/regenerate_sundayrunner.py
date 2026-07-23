"""Regenerate only Sunday Runner-owned campaign evidence and ledgers."""

from __future__ import annotations

import hashlib
import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import build_remediation_queue as remediation
import regenerate_martial as base
import regenerate_owlperson as transaction
from campaign_cli import no_arg_command

ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.base.base.shared.base
TRAIT = "UniversalTraits:UT_sundayrunner"
FINDINGS = ("B11-SUNDAY-001",)
DESCRIPTION = "Sprinting increases unhappiness by 2 every in-game minute."
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_sundayrunner.md"
PRD = "PRD.md"
RESOLUTION = "change-impact/sundayrunner-unhappiness-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl", "source_inventory.json", "translation_audit.json",
    "independent_reviews/traits_09_12.json", "release_blocker_queue.json", RESOLUTION,
    "final_trait_ledger.json", "final_trait_ledger_rows.jsonl", "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl", "remediation_summary.json", "campaign_manifest.json",
)


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing) if missing else HELPER._dimension(state, evidence)


def _input_bytes_lf(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def _input_metadata_lf(root: Path, relative: str) -> dict[str, object]:
    data = _input_bytes_lf(root / relative)
    return {"path": relative, "sha256": hashlib.sha256(data).hexdigest().upper(), "bytes": len(data)}


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_11.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": old["registration"],
        "definition_parser": _dimension("proven-correct", "Cost -1, multiplayer disabled, no XP boosts or grants, and reciprocal Sprint Demon exclusion are exact."),
        "namespace": old["namespace"],
        "cost_xp_grants_exclusions": _dimension("proven-correct", "Cost -1; no XP boosts or grants; reciprocal exclusion with UniversalTraits:UT_sprintdemon."),
        "source_intent": _dimension("proven-correct", "Accepted UT intent preserves a conditional sprinting unhappiness penalty without historical stress or OnTick behavior."),
        "runtime_path": _dimension("proven-correct", "UTCore EveryOneMinute resolves getPlayer; only a local sprinting trait holder receives +2 CharacterStat.UNHAPPINESS."),
        "numbers": _dimension("proven-correct", "Exactly +2 per qualifying event, capped at the native unhappiness maximum."),
        "cadence": _dimension("runtime-unproven", "One application per owned EveryOneMinute callback.", "Current-build event production is unobserved."),
        "cooldown": _dimension("not-applicable", "No cooldown."),
        "reset_save_load": _dimension("runtime-unproven", "Duplicate module load leaves one replacement handler.", "Full relaunch and current-version save-load remain unobserved."),
        "java_lua": _dimension("proven-correct", "SVN 964 anchors generic CharacterStat access, isSprinting, and the no-player EveryOneMinute producer."),
        "kahlua": _dimension("runtime-unproven", "Lua shapes and Java receiver calls are statically compatible.", "Live current-build Kahlua execution remains unobserved."),
        "events": _dimension("proven-correct", "The wrapper ignores event arguments and resolves only getPlayer for EveryOneMinute."),
        "stacking_interactions": _dimension("proven-correct", "Running, walking, idle, nil, absent/removed trait, and non-local players receive no change; reload does not stack."),
        "multiplayer": _dimension("not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."),
        "display": _dimension("proven-correct", "Exact English display name is Sunday Runner."),
        "description": _dimension("proven-correct", "English states the exact sprint condition, +2 amount, and per-game-minute cadence."),
        "localization": _dimension("coverage-gap", "Exact English keys exist with source/release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _dimension("runtime-unproven", "Accepted cost -1 contract is unchanged.", "No gameplay balance observation exists."),
        "performance": _dimension("runtime-unproven", "One constant-time minute handler with early guards.", "No current-build profiler capture exists."),
        "tests": _dimension("proven-correct", "Focused standard-Lua cases cover exact effect, local routing, negatives, clamp, unrelated non-effects, metadata, copy, and reload replacement."),
        "mocks": _dimension("proven-correct", "Mocks expose native CharacterStat storage, sprint state, local-player routing, XP observation, and event handler counts."),
        "source_release_parity": _dimension("proven-correct", "Runtime, UI, definition, registry, tests, mocks, and audit are fingerprinted; packaged counterparts are byte-identical."),
        "packaging": _dimension("proven-correct", "Sunday-owned 42.0 runtime, UI, definition, and registry counterparts are present and identical."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Sunday Runner dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence="Accepted commits 23524ac and ec57b7f prove aligned copy, runtime, reciprocal exclusion, exact metadata, event routing, negative cases, native clamp, and reload replacement.",
        missing_proof="",
        remaining_runtime_proof="Live Kahlua, current-build event production, relaunch/save-load, rendered English, balance, profiler, and non-English locales remain unobserved.",
    )
    row["unknowns"] = [
        "Live current-build Kahlua and current-build EveryOneMinute production remain unobserved.",
        "Full relaunch, current-version save-load, death, repeated world entry, gameplay balance, and profiler observation remain unrun.",
        "Rendered English and non-English localization remain unobserved.",
    ]
    row["validation"] = {
        "engine_contract": "SVN revision 964 LuaEventManager/Stats/IsoPlayer anchors",
        "behavior_commits": ["23524ac", "ec57b7f426c9b1376597064b840368bc5105348f"],
        "static_regression": "UniversalTraits focused Sunday Runner standard-Lua cases",
        "runtime_checks_unrun": ["live Kahlua/event production", "full relaunch and save-load", "rendered English", "balance and profiler"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = ("\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n").encode()


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
                   SOURCE_REGISTRY, RELEASE_REGISTRY, MOCKS, TESTS, ACTIVE_AUDIT, PRD):
        HELPER._update_fingerprints(artifact, source, _input_metadata_lf(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row.update(
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        supported_accepted_finding_ids=list(FINDINGS),
        rejected_accepted_finding_ids=[],
        omissions=[],
        omission_disposition="no Sunday-specific omission remains after accepted event, metadata, copy, exclusion, and reload coverage",
        unresolved_runtime_proof_ids=["RP0912-KAHLUA-001", "RP0912-SAVELOAD-001", "RP0912-BALANCE-PERF-001", "RP0912-LOCALE-001"],
        resolution_record=RESOLUTION,
    )
    row["release_parity"] = {
        "runtime_source": _input_metadata_lf(root, RUNTIME)["sha256"],
        "runtime_release": _input_metadata_lf(root, RELEASE)["sha256"],
        "ui_source": _input_metadata_lf(root, SOURCE_UI)["sha256"],
        "ui_release": _input_metadata_lf(root, RELEASE_UI)["sha256"],
        "definition_source": _input_metadata_lf(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": _input_metadata_lf(root, RELEASE_DEFINITION)["sha256"],
        "registry_source": _input_metadata_lf(root, SOURCE_REGISTRY)["sha256"],
        "registry_release": _input_metadata_lf(root, RELEASE_REGISTRY)["sha256"],
        "tests": _input_metadata_lf(root, TESTS)["sha256"],
        "mocks": _input_metadata_lf(root, MOCKS)["sha256"],
        "state": "proven-correct",
    }
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
             SOURCE_REGISTRY, RELEASE_REGISTRY, TESTS, MOCKS, ACTIVE_AUDIT, PRD)
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-sundayrunner-unhappiness-contract-v1",
        "trait_id": TRAIT,
        "authority": {
            "honest_pre_campaign_commit": "a32f251e7cebdc27b533907b6b16c7aa135eb882",
            "accepted_behavior_commits": ["23524ac", "ec57b7f426c9b1376597064b840368bc5105348f"],
            "pz_snapshot": "SVN revision 964",
        },
        "accepted_intent": {
            "cost": -1, "xp_boosts": {}, "grants": [],
            "exclusions": ["UniversalTraits:UT_sprintdemon"],
            "multiplayer": False, "event": "UTCore EveryOneMinute",
            "player": "local getPlayer only", "condition": "isSprinting()==true",
            "effect": {"stat": "CharacterStat.UNHAPPINESS", "delta": 2, "cap": "native domain"},
            "explicit_non_effects": ["stress", "panic", "boredom", "Fitness", "Sprinting level", "XP", "legacy BodyDamage unhappiness"],
            "english": DESCRIPTION,
        },
        "engine_anchors": ["SVN 964 LuaEventManager EveryOneMinute producer", "SVN 964 Stats CharacterStat domain", "SVN 964 IsoPlayer.isSprinting"],
        "resolved_findings": list(FINDINGS),
        "resolved_independent_defects": ["stale Fitness copy", "missing reciprocal exclusion", "missing focused behavior proof", "event-argument ambiguity", "duplicate-handler ambiguity"],
        "retained_runtime_proof": ["current-build Kahlua", "current-build event production", "full relaunch", "current-version save-load", "death and repeated world entry", "rendered English", "non-English localization", "gameplay balance", "profiler"],
        "files": [_input_metadata_lf(root, source) for source in files],
        "runtime_proof": "Unobserved; static and standard-Lua evidence do not establish current-version live gameplay.",
        "non_goals": ["multiplayer", "backward save migration", "deployment", "historical stress restoration"],
    })


@contextmanager
def _reviewed_recurring_findings(campaign: Path) -> Iterator[None]:
    """Keep derived projections bound to the reviewed campaign artifact."""
    path = campaign / "recurring_pattern_findings.json"
    artifact = json.loads(path.read_text(encoding="utf-8"))
    findings = artifact.get("findings")
    if not isinstance(findings, list):
        raise ValueError("recurring pattern findings artifact is malformed")
    original = remediation.build_report
    try:
        remediation.build_report = lambda: artifact
        yield
    finally:
        remediation.build_report = original


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
    with _reviewed_recurring_findings(campaign), _configured_base():
        plan = base.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Sunday Runner output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace=transaction.os.replace) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Sunday Runner output set")
    original = transaction.OWNED_OUTPUTS
    try:
        transaction.OWNED_OUTPUTS = OWNED_OUTPUTS
        return transaction.commit_plan(plan, campaign, replace)
    finally:
        transaction.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_sundayrunner.py")
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
