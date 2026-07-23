"""Regenerate only Paramedic campaign evidence and derived ledgers."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import build_remediation_queue as remediation
import regenerate_heavilybleedingwounds as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_paramedic"
CLOSED_FINDING = "B08-UT_paramedic-ONACTIONADDED"
RETAINED_FINDING = "B08-UT_paramedic-RUNTIME-PROOF"
FINDINGS = (CLOSED_FINDING,)
DESCRIPTION = "+2 to Doctor. Medical treatments (bandaging, stitching) are applied 50% faster."
MEDICAL_ACTION_TYPES = (
    "ISMedicalCheckAction",
    "ISApplyBandage",
    "ISCleanBurn",
    "ISComfreyCataplasm",
    "ISGarlicCataplasm",
    "ISPlantainCataplasm",
    "ISDisinfect",
    "ISRemoveBullet",
    "ISRemoveGlass",
    "ISSplint",
    "ISStitch",
)
INVENTED_ACTION_TYPES = ("ISApplyComfrey", "ISApplyGarlic", "ISApplyPlantain")
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_paramedic.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_paramedic.lua"
)
SHARED_RUNTIME = "UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua"
SHARED_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
MOCKS = "UT_CORE/test/run_tests.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_paramedic.md"
RESOLUTION = "change-impact/paramedic-medical-action-resolution.json"
SHARED_BLOCKER = "event-registry:timed-action-added"
PARAMEDIC_QUEUE_ID = f"dimension:{TRAIT}:events"
PITCREW_QUEUE_ID = "dimension:UniversalTraits:UT_pitcrew:events"
OWNED_OUTPUTS = (
    "trait_batches/batch_08.jsonl",
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


def _d(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing)


def _lua_table_keys(source: str, table_name: str) -> tuple[str, ...]:
    match = re.search(
        rf"local\s+{re.escape(table_name)}\s*=\s*\{{(?P<body>.*?)\n\}}",
        source,
        re.DOTALL,
    )
    if not match:
        raise ValueError(f"shared work-speed hook is missing {table_name}")
    return tuple(re.findall(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*true,\s*$", match.group("body"), re.MULTILINE))


def _without_lua_comments(source: str) -> str:
    return re.sub(r"--[^\r\n]*", "", source)


def _canonical_text_metadata(root: Path, relative: str) -> dict[str, Any]:
    data = (root / relative).read_bytes().replace(b"\r\n", b"\n")
    return {
        "path": relative,
        "sha256": hashlib.sha256(data).hexdigest().upper(),
        "bytes": len(data),
    }


def _shared_hook_evidence(root: Path) -> dict[str, Any]:
    source_path = root / SHARED_RUNTIME
    release_path = root / SHARED_RELEASE
    source_bytes = source_path.read_bytes()
    release_bytes = release_path.read_bytes()
    if source_bytes != release_bytes:
        raise ValueError("shared work-speed hook source and exact 42.0 release mirror diverge")

    source = _without_lua_comments(source_bytes.decode("utf-8").replace("\r\n", "\n"))
    medical_types = _lua_table_keys(source, "MEDICAL_ACTION_TYPES")
    constructor_types = _lua_table_keys(source, "CONSTRUCTOR_MEDICAL_ACTION_TYPES")
    if medical_types != MEDICAL_ACTION_TYPES:
        raise ValueError("shared work-speed hook medical action allowlist drifted")
    expected_constructors = ("ISMedicalCheckAction", "ISSplint")
    if constructor_types != expected_constructors:
        raise ValueError("shared work-speed hook constructor allowlist drifted")

    semantic_fragments = {
        "independent_half_factor": "math.floor(duration * 0.5)",
        "additive_modifiers_before_paramedic": (
            "duration = applyParamedicFactor(timedAction, duration)"
        ),
        "constructor_installation": (
            'patchConstructor("ISMedicalCheckAction")\n'
            '    patchConstructor("ISSplint")'
        ),
    }
    for name, fragment in semantic_fragments.items():
        if fragment not in source:
            raise ValueError(f"shared work-speed hook semantic anchor drifted: {name}")
    total_mod = source.find("local totalMod = workMod + readMod + transferMod + traitMod")
    factor = source.find(semantic_fragments["additive_modifiers_before_paramedic"])
    if total_mod < 0 or factor <= total_mod:
        raise ValueError("shared work-speed hook no longer applies the independent Paramedic factor after additive modifiers")

    guard_contracts = {
        "get_duration_skips_constructor_adjusted_action": re.search(
            r"if\s+timedAction\._utParamedicDurationApplied\s+or\s+not\s+hasParamedic"
            r"\s*\(\s*timedAction\s*\)\s+then\s+return\s+duration\s+end",
            source,
        ),
        "constructor_skips_already_adjusted_action": re.search(
            r"if\s+not\s+CONSTRUCTOR_MEDICAL_ACTION_TYPES\s*\[\s*action\.Type\s*\]"
            r".*?\bor\s+action\._utParamedicDurationApplied\b"
            r".*?\bor\s+type\s*\(\s*action\.maxTime\s*\)\s*~=\s*\"number\""
            r".*?\bor\s+not\s+hasParamedic\s*\(\s*action\s*\)\s+then\s+return\s+end",
            source,
            re.DOTALL,
        ),
        "constructor_marks_adjusted_after_half_factor": re.search(
            r"action\.maxTime\s*=\s*applyParamedicFactor\s*\(\s*action\s*,\s*action\.maxTime\s*\)"
            r"\s*action\._utParamedicDurationApplied\s*=\s*true\b",
            source,
        ),
    }
    missing_guard_contracts = [name for name, match in guard_contracts.items() if match is None]
    if missing_guard_contracts:
        raise ValueError(
            "shared work-speed hook constructor/getDuration double-apply guard drifted: "
            + ", ".join(missing_guard_contracts)
        )

    return {
        "source": HELPER._metadata(root, SHARED_RUNTIME),
        "release_42_0": HELPER._metadata(root, SHARED_RELEASE),
        "byte_identical": True,
        "exact_medical_action_types": list(medical_types),
        "constructor_action_types": list(constructor_types),
        "semantic_anchors": [
            {
                "id": name,
                "kind": "line-independent-source-fragment",
                "fragment": fragment,
            }
            for name, fragment in semantic_fragments.items()
        ] + [
            {"id": name, "kind": "semantic-source-contract"}
            for name in guard_contracts
        ],
        "ordering": {
            "id": "additive-modifiers-then-independent-paramedic-half",
            "kind": "line-independent-relative-order",
            "before": "local totalMod = workMod + readMod + transferMod + traitMod",
            "after": semantic_fragments["additive_modifiers_before_paramedic"],
        },
    }


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_08.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _d("proven-correct", "Registry, definition, runtime ID, and English keys agree."),
        "definition_parser": _d("runtime-unproven", "Cost 4, Doctor +2, no grants or exclusions, and multiplayer-disabled metadata pass deterministic parsing.", "Current-build ScriptManager loading remains unobserved."),
        "namespace": _d("proven-correct", "Every owned surface uses UniversalTraits:UT_paramedic."),
        "cost_xp_grants_exclusions": _d("proven-correct", "Cost is 4, Doctor is +2, and no grants or exclusions exist."),
        "source_intent": _d("proven-correct", "Pre-campaign intent is Doctor +2 plus an independent 0.5 medical action duration multiplier."),
        "runtime_path": _d("proven-correct", "UTCore.applyWorkDuration owns the exact medical allowlist and applies Paramedic independently of additive work-speed modifiers."),
        "numbers": _d("proven-correct", "All eleven accepted medical types map 120 to 60; ordinary and invented types remain 120."),
        "cadence": _d("proven-correct", "Duration is derived per medical action query or constructor patch and never compounds."),
        "cooldown": _d("not-applicable", "Paramedic has no cooldown."),
        "reset_save_load": _d("runtime-unproven", "The live trait check needs no persisted marker.", "Current-build new game, save/load, death, and repeated world entry remain unobserved."),
        "java_lua": _d("proven-correct", "SVN 964 and accepted review prove the eleven exact action Type identifiers and the shared duration boundary."),
        "kahlua": _d("runtime-unproven", "The hook uses Kahlua-compatible tables and guarded method replacement.", "Current-build Kahlua execution remains unobserved."),
        "events": _d("proven-correct", "The invented OnActionAdded event is gone; the existing shared OnGameBoot work-duration hook owns installation."),
        "stacking_interactions": _d("proven-correct", "The 0.5 Paramedic factor composes independently with additive work speed and is applied once."),
        "multiplayer": _d("not-applicable", "The definition disables Paramedic in multiplayer and multiplayer support is a product non-goal."),
        "display": _d("proven-correct", "The English display name is Paramedic."),
        "description": _d("proven-correct", "English accurately states Doctor +2 and medical treatments at 50 percent faster."),
        "localization": _d("coverage-gap", "Exact English keys exist with source-release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _d("runtime-unproven", "Cost 4, Doctor +2, and the 0.5 independent multiplier are unchanged.", "No gameplay telemetry exists."),
        "performance": _d("runtime-unproven", "Allowlist lookup and duration composition are constant-time with no scans or polling.", "No current-build profiler capture exists."),
        "tests": _d("proven-correct", "Deterministic tests cover eleven positive identifiers, three invented negatives, ordinary actions, independent composition, no compounding, and constructor patching."),
        "mocks": _d("proven-correct", "The invented event mock is absent and tests exercise the owned shared duration hook."),
        "source_release_parity": _d("proven-correct", "Paramedic trait and shared work-duration runtime source-release pairs are byte-identical."),
        "packaging": _d("coverage-gap", "Paramedic-owned runtime, definition, and English 42.0 counterparts are present and identical.", "Read-only package verification still tracks the separate missing source poster."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Paramedic dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [
        RUNTIME,
        SHARED_RUNTIME,
        SHARED_RELEASE,
        "UT_CORE/test/run_tests.lua:1158-1215",
        "UniversalTraits/test/run_tests.lua:4220-4245",
        ACTIVE_AUDIT,
    ]
    closed = HELPER._exactly_one(row["findings"], "id", CLOSED_FINDING, relative)
    closed.update(
        resolution_state="proven-correct",
        implementation_status="implemented-and-statically-validated",
        resolution_evidence="The accepted shared hook replaces the nonexistent event and tests all eleven exact SVN 964 action types plus the three invented negative identifiers.",
        missing_proof="Current-build Kahlua and representative real medical actions remain unobserved.",
        recommended_correction="No further static correction is indicated.",
        smallest_regression_test="Run the focused UTCore and UniversalTraits Paramedic duration cases.",
    )
    retained = HELPER._exactly_one(row["findings"], "id", RETAINED_FINDING, relative)
    retained.update(
        resolution_state="runtime-unproven",
        implementation_status="static-proof-complete-runtime-proof-retained",
        reproduction_evidence="Deterministic source, release, and tests prove the owned static path; no game launch was performed.",
        missing_proof="Full exit-to-desktop relaunch, current-build Kahlua, real medical actions, and save/load.",
        recommended_correction="Run the exact retained in-game checklist before runtime readiness.",
    )
    row["unknowns"] = [
        "Current-build Kahlua after full desktop relaunch remains unobserved.",
        "Representative real medical actions and current-version save/load remain unobserved.",
        "Rendered English, balance, and profiler observation remain unobserved.",
        "Only English localization exists; multiplayer and backward migration are non-goals.",
    ]
    row["validation"] = {
        "accepted_runtime_commits": [
            "6929d4221ecf6b9a204a7438e13608fa6d9549a8",
            "6d6fb2758f0b1db8fc2d717a507f27bc3631c304",
        ],
        "exact_medical_action_types": list(MEDICAL_ACTION_TYPES),
        "rejected_invented_action_types": list(INVENTED_ACTION_TYPES),
        "runtime_checks_unrun": ["game launch", "full desktop relaunch", "real medical actions", "save/load", "profiler"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = (
        "\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n"
    ).encode("utf-8")


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["superseding_review"] = {
        "state": "accepted-static-resolution-runtime-unproven",
        "supersedes_implementation_state_only": True,
        "historical_review_preserved": True,
        "resolved_finding_ids": [CLOSED_FINDING],
        "retained_finding_ids": [RETAINED_FINDING],
        "accepted_runtime_commits": [
            "6929d4221ecf6b9a204a7438e13608fa6d9549a8",
            "6d6fb2758f0b1db8fc2d717a507f27bc3631c304",
        ],
        "exact_medical_action_types": list(MEDICAL_ACTION_TYPES),
        "rejected_invented_action_types": list(INVENTED_ACTION_TYPES),
        "remaining_runtime_proof": "Full desktop relaunch, current-build Kahlua, real medical action exercise, and save/load remain unobserved.",
    }
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "shared_work_speed_hook": _shared_hook_evidence(root),
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    shared_hook = _shared_hook_evidence(root)
    files = (
        RUNTIME, RELEASE, SHARED_RUNTIME, SHARED_RELEASE, SOURCE_UI, RELEASE_UI,
        SOURCE_DEFINITION, RELEASE_DEFINITION, MOCKS, TESTS, ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-paramedic-medical-action-resolution-v1",
        "trait_id": TRAIT,
        "historical_review": {
            "state": "preserved",
            "finding": CLOSED_FINDING,
            "reason": "The first implementation correctly failed because OnActionAdded and its mock were invented.",
        },
        "superseding_resolution": {
            "state": "accepted-static-resolution-runtime-unproven",
            "runtime_commits": [
                "6929d4221ecf6b9a204a7438e13608fa6d9549a8",
                "6d6fb2758f0b1db8fc2d717a507f27bc3631c304",
            ],
            "closed_findings": [CLOSED_FINDING],
            "retained_findings": [RETAINED_FINDING],
        },
        "accepted_intent": {"cost": 4, "doctor_xp": 2, "exclusions": [], "medical_duration_multiplier": 0.5},
        "exact_medical_action_types": list(MEDICAL_ACTION_TYPES),
        "rejected_invented_action_types": list(INVENTED_ACTION_TYPES),
        "shared_work_speed_hook": shared_hook,
        "files": [HELPER._metadata(root, source) for source in files],
        "remaining_runtime_proof": [
            "full exit-to-desktop relaunch and current-build Kahlua load",
            "representative real medical action exercise",
            "current-version save/load and repeated world entry",
            "rendered English, gameplay balance, and profiler observation",
        ],
        "non_goals": ["multiplayer", "backward save migration", "deployment", "balance or intent changes"],
    })


def _rewrite_shared_blocker(campaign: Path) -> None:
    path = campaign / "release_blocker_queue.json"
    artifact = json.loads(path.read_text(encoding="utf-8"))
    blocker = HELPER._exactly_one(artifact["identities"], "semantic_identity", SHARED_BLOCKER, str(path))
    queue_ids = blocker.get("queue_ids", [])
    if queue_ids.count(PARAMEDIC_QUEUE_ID) > 1 or queue_ids.count(PITCREW_QUEUE_ID) != 1:
        raise ValueError("shared Paramedic/Pit Crew blocker has unexpected queue accounting")
    blocker["queue_ids"] = [item for item in queue_ids if item != PARAMEDIC_QUEUE_ID]
    blocker["evidence_scope"] = "Pit Crew registers OnActionAdded, which is absent from the current event registry."
    path.write_bytes(HELPER._json_bytes(artifact))


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
    replacements: dict[str, Any] = {
        "TRAIT": TRAIT, "FINDINGS": FINDINGS, "DESCRIPTION": DESCRIPTION,
        "RUNTIME": RUNTIME, "RELEASE": RELEASE, "SOURCE_UI": SOURCE_UI,
        "RELEASE_UI": RELEASE_UI, "SOURCE_DEFINITION": SOURCE_DEFINITION,
        "RELEASE_DEFINITION": RELEASE_DEFINITION, "MOCKS": MOCKS, "TESTS": TESTS,
        "ACTIVE_AUDIT": ACTIVE_AUDIT, "RESOLUTION": RESOLUTION,
        "OWNED_OUTPUTS": OWNED_OUTPUTS, "_plan_batch": _plan_batch,
        "_plan_review": _plan_review, "_plan_resolution": _plan_resolution,
    }
    originals = {name: getattr(base, name) for name in replacements}
    original_metadata = HELPER._metadata
    try:
        HELPER._metadata = _canonical_text_metadata
        for name, value in replacements.items():
            setattr(base, name, value)
        yield
    finally:
        HELPER._metadata = original_metadata
        for name, value in originals.items():
            setattr(base, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with tempfile.TemporaryDirectory(prefix="regenerate-paramedic-plan-") as directory:
        overlay = Path(directory) / "campaign"
        shutil.copytree(campaign, overlay, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        _rewrite_shared_blocker(overlay)
        with _reviewed_recurring_findings(overlay), _configured_base():
            plan = base.build_plan(root, overlay)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Paramedic output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_paramedic.py")
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
