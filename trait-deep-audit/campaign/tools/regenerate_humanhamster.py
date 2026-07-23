"""Regenerate only Human Hamster-owned campaign evidence and ledgers."""

from __future__ import annotations

import hashlib
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
TRAIT = "UniversalTraits:UT_humanhamster"
FINDINGS = ("B05-HAMSTER-001", "B05-HAMSTER-002")
DESCRIPTION = (
    "Carry 2 more weight. If your inventory is below 80% full or you are not wearing an "
    "inventory container, craving builds each minute and adds 0.02/0.04/0.08 stress per minute "
    "after 10/30/60 minutes. Meeting both conditions resets craving."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_humanhamster.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_humanhamster.lua"
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
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_humanhamster.md"
RESOLUTION = "change-impact/humanhamster-owned-state-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_05.jsonl",
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


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing) if missing else HELPER._dimension(state, evidence)


def _input_bytes_lf(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def _input_metadata_lf(root: Path, relative: str) -> dict[str, object]:
    data = _input_bytes_lf(root / relative)
    return {"path": relative, "sha256": hashlib.sha256(data).hexdigest().upper(), "bytes": len(data)}


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_05.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    dimensions = {
        "registration": _dimension(
            "proven-correct",
            "CharacterTrait.register uses the exact UniversalTraits:UT_humanhamster id.",
        ),
        "definition_parser": _dimension(
            "proven-correct", "Cost -1, no XP boosts or grants, no exclusions, and multiplayer disabled."
        ),
        "namespace": _dimension(
            "proven-correct",
            "Registration, definition CharacterTrait, runtime TRAIT_ID, and English keys are consistently namespaced.",
        ),
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct", "Cost -1; no XP boosts, grants, or exclusions; single-player only."
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Accepted intent preserves +2 carry and the existing 80 percent plus worn-container craving model with 10/30/60 minute stress tiers.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "Owned tick dispatch applies only the Human Hamster carry bucket, evaluates inventory load and WornItems through size plus zero-based getItemByIndex, and updates craving stress.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "+2 carry; craving resets only at 80 percent or more capacity with a worn inventory container; stress adds 0.02/0.04/0.08 per minute after 10/30/60 minutes.",
        ),
        "cadence": _dimension(
            "runtime-unproven",
            "One owned callback evaluates the trait per in-game minute.",
            "Live current-build callback cadence remains unobserved.",
        ),
        "cooldown": _dimension("not-applicable", "No cooldown exists; craving is tiered accumulated minute state."),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "Focused proof removes only Human Hamster-owned carry and craving on trait loss, replacement, death, dispatcher deactivation, and duplicate module evaluation.",
            "Full relaunch and current-version save-load remain unobserved.",
        ),
        "java_lua": _dimension(
            "proven-correct",
            "SVN 964 WornItems exposes size() and zero-based getItemByIndex(int), returning InventoryItem; the invalid numeric getItem call is removed.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "Accepted source uses Kahlua-compatible Lua shapes and current static bridge signatures.",
            "Live current-build Kahlua execution remains unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "The trait uses one dispatcher registration with explicit teardown; duplicate evaluation replaces prior owned state without stacking.",
        ),
        "stacking_interactions": _dimension(
            "proven-correct",
            "Focused production teardown preserves an external +4 carry bucket and unrelated state while recomputing capacity from 14 to 12.",
        ),
        "multiplayer": _dimension(
            "not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."
        ),
        "display": _dimension("proven-correct", "Exact English display name is Human Hamster."),
        "description": _dimension(
            "proven-correct",
            "English states +2 carry, the 80 percent plus worn-container condition, tier timing, exact stress amounts, cadence, and reset.",
        ),
        "localization": _dimension(
            "coverage-gap",
            "Exact English keys exist with source-release parity.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": _dimension(
            "runtime-unproven",
            "Accepted cost -1, +2 carry, and existing craving tiers are unchanged.",
            "No gameplay balance observation exists.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "The minute handler performs bounded inventory and worn-item traversal with early guards.",
            "No current-build profiler capture exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Thirteen focused cases cover WornItems indexing, carry/craving behavior, ownership composition, all teardown paths, duplicate evaluation, metadata, copy, and parity; full suite passes 570/570.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "Focused doubles implement size plus zero-based getItemByIndex and expose dispatcher teardown, carry buckets, craving state, death, replacement, and unrelated state.",
        ),
        "source_release_parity": _dimension(
            "proven-correct",
            "Runtime and English source/release pairs are byte-identical; definition and registry counterparts remain identical.",
        ),
        "packaging": _dimension(
            "coverage-gap",
            "Human Hamster-owned 42.0 runtime, UI, definition, and registry counterparts are present and identical.",
            "Whole-package verification remains blocked by the separately tracked missing root poster.png.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Human Hamster dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    evidence = (
        "Accepted commits a2e89918 and 8141d1a4230d7dd23bd9cb79f537e5af8b45f77f, focused 13/13, "
        "full 570/570, and independent ACCEPT prove the corrected API, truthful copy, and owned teardown."
    )
    for finding_id in FINDINGS:
        finding = HELPER._exactly_one(row["findings"], "id", finding_id, relative)
        finding.update(
            resolution_state="proven-correct",
            resolution_evidence=evidence,
            missing_proof="",
            remaining_runtime_proof=(
                "Live current-build Kahlua execution, full relaunch, and current-version save-load remain unobserved."
            ),
        )
    row["unknowns"] = [
        "Live current-build Kahlua execution remains unobserved.",
        "Full desktop relaunch and current-version save-load remain unobserved.",
        "No non-English UniversalTraits locale exists.",
        "Gameplay balance and profiler behavior remain unobserved.",
        "Whole-package verification remains blocked by the separately tracked missing root poster.png.",
    ]
    row["validation"] = {
        "accepted_implementation_commits": ["a2e89918", "8141d1a4230d7dd23bd9cb79f537e5af8b45f77f"],
        "final_independent_review": "ACCEPT at 8141d1a4; external +4 preserved; capacity 14 to 12",
        "focused_lua_suite": "13/13",
        "full_lua_suite": "570/570",
        "runtime_checks_unrun": ["live Kahlua", "full relaunch", "current-version save-load"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment", "rebalance"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = (
        "\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines))
        + "\n"
    ).encode()


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
        SOURCE_REGISTRY,
        RELEASE_REGISTRY,
        MOCKS,
        TESTS,
        ACTIVE_AUDIT,
    ):
        HELPER._update_fingerprints(artifact, source, _input_metadata_lf(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row.update(
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        supported_accepted_finding_ids=list(FINDINGS),
        rejected_accepted_finding_ids=[],
        omissions=[],
        omission_disposition=(
            "No Human Hamster-specific static omission remains after API, copy, carry ownership, craving ownership, "
            "dispatcher teardown, replacement, death, and duplicate-evaluation proof."
        ),
        unresolved_runtime_proof_ids=[
            "RP0508-KAHLUA-001",
            "RP0508-SAVELOAD-001",
            "RP0508-BALANCE-PERF-001",
            "RP0508-LOCALE-001",
        ],
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
    files = (
        RUNTIME,
        RELEASE,
        SOURCE_UI,
        RELEASE_UI,
        SOURCE_DEFINITION,
        RELEASE_DEFINITION,
        SOURCE_REGISTRY,
        RELEASE_REGISTRY,
        TESTS,
        MOCKS,
        ACTIVE_AUDIT,
    )
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-humanhamster-owned-state-contract-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_implementation_commits": [
                    "a2e89918da843e8f45c0e65115713f7f2d1ed027",
                    "8141d1a4230d7dd23bd9cb79f537e5af8b45f77f",
                ],
                "pz_snapshot": "SVN revision 964",
                "final_independent_review": {
                    "verdict": "ACCEPT",
                    "snapshot": "8141d1a4",
                    "focused_cases": 13,
                    "full_cases": 570,
                    "blocking_findings": 0,
                },
            },
            "review_iterations": [
                {
                    "snapshot": "a2e89918",
                    "disposition": "changes-requested",
                    "finding": "Dispatcher deactivation did not remove Human Hamster-owned carry and craving state.",
                    "resolved_by": "8141d1a4",
                },
                {
                    "snapshot": "8141d1a4",
                    "disposition": "accepted",
                    "finding": "Production teardown preserved external +4 and unrelated state, recomputing capacity 14 to 12.",
                    "resolved_by": None,
                },
            ],
            "accepted_intent": {
                "cost": -1,
                "carry_contribution": 2,
                "qualifying_reset": "inventory at least 80 percent full and an inventory container is worn",
                "craving_tiers": [
                    {"after_minutes": 10, "stress_per_minute": 0.02},
                    {"after_minutes": 30, "stress_per_minute": 0.04},
                    {"after_minutes": 60, "stress_per_minute": 0.08},
                ],
                "english": DESCRIPTION,
            },
            "api_contract": {
                "collection": "WornItems",
                "count": "size()",
                "indexing": "zero-based getItemByIndex(int)",
                "return": "InventoryItem",
                "retired_invalid_call": "numeric getItem(i)",
            },
            "lifecycle": {
                "ownership": "Human Hamster contributes only its own carry bucket and craving state.",
                "teardown": [
                    "trait loss",
                    "player replacement",
                    "death",
                    "dispatcher deactivation",
                    "duplicate module evaluation",
                ],
                "external_composition": "External carry buckets and unrelated state remain untouched.",
            },
            "resolved_findings": list(FINDINGS),
            "regression_cases": [
                "WornItems size and zero-based getItemByIndex",
                "exact cost and English contract",
                "exact +2 carry ownership",
                "80 percent plus worn-container reset",
                "10/30/60 minute stress tiers",
                "trait-loss cleanup",
                "player-replacement cleanup",
                "death cleanup",
                "dispatcher-deactivation cleanup",
                "duplicate-evaluation cleanup",
                "external +4 carry preservation",
                "unrelated-state preservation",
                "source-release parity",
            ],
            "files": [_input_metadata_lf(root, source) for source in files],
            "retained_runtime_proof": [
                "live current-build Kahlua execution",
                "full desktop relaunch",
                "current-version save-load",
            ],
            "separate_blockers": [
                "152 broader API baseline issues",
                "containerObj.getContainer smoke coverage",
                "missing root poster.png",
            ],
            "runtime_proof": "Unobserved; static and standard-Lua evidence do not establish current-version live gameplay.",
            "non_goals": ["multiplayer", "backward save migration", "deployment", "rebalance"],
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
    with _configured_base():
        plan = base.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Human Hamster output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace=transaction.os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Human Hamster output set")
    original = transaction.OWNED_OUTPUTS
    try:
        transaction.OWNED_OUTPUTS = OWNED_OUTPUTS
        return transaction.commit_plan(plan, campaign, replace)
    finally:
        transaction.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_humanhamster.py")
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
