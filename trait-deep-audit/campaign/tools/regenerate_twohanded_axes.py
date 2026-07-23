"""Regenerate only Two-Handed Axe-owned campaign evidence and ledgers."""

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
TRAIT = "UniversalTraits:UT_twohanded_axes"
FINDINGS = ("B12-TWOHANDED-AXES-001",)
RELATED_HISTORY = ("IR0104-AXES-CRIT-MUTATION",)
DESCRIPTION = "+2 to Axe. Two-handed axe attacks have +10 percent critical hit chance."
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_twohanded_axes.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_twohanded_axes.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_twohanded_axes.md"
RESOLUTION = "change-impact/twohanded-axes-critical-chance-ownership.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_12.jsonl",
    "source_inventory.json",
    "translation_audit.json",
    "independent_reviews/traits_09_12.json",
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
    relative = "trait_batches/batch_12.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": old["registration"],
        "definition_parser": _dimension(
            "proven-correct",
            "Cost 4, Axe +2, no grants, multiplayer disabled, and complete reciprocal WeaponTree exclusions are unchanged.",
        ),
        "namespace": old["namespace"],
        "cost_xp_grants_exclusions": _dimension(
            "proven-correct",
            "Cost 4; Axe +2; no grants; existing reciprocal WeaponTree exclusions and single-player scope are preserved.",
        ),
        "source_intent": _dimension(
            "proven-correct",
            "Accepted intent is exactly +10 displayed critical-chance points, capped at 100, for an eligible owner using an eligible two-handed Axe.",
        ),
        "runtime_path": _dimension(
            "proven-correct",
            "Every 30 owned tick dispatches, exact primary/secondary weapon objects are classified, stale objects restored, and eligible objects refreshed with transient exact-object ownership.",
        ),
        "numbers": _dimension(
            "proven-correct",
            "targetDisplayed=min(100,baseRaw*sharpness+10); targetRaw=targetDisplayed/sharpness; non-sharp weapons use sharpness 1.",
        ),
        "cadence": _dimension(
            "runtime-unproven",
            "Static registration specifies one vehicle-aware owned tick handler throttled to 30 dispatches.",
            "Live current-build cadence and callback production remain unobserved.",
        ),
        "cooldown": _dimension("not-applicable", "No cooldown or timestamp state exists."),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "Unequip, trait loss, death, inactive teardown, and reload replacement restore tracked contributions in focused proof; no persistent modData is created.",
            "Full desktop relaunch and current-version save-load remain unobserved.",
        ),
        "java_lua": _dimension(
            "runtime-unproven",
            "Current static source supports the HandWeapon, Axe-category, handedness, sharpness, critical-chance, and tick-dispatch surfaces used.",
            "Live current-build Java-Lua bridge receivers, return domains, and errors remain unobserved.",
        ),
        "kahlua": _dimension(
            "runtime-unproven",
            "The accepted source uses Kahlua-compatible Lua shapes and contains bridge calls with pcall.",
            "Live current-build Kahlua execution remains unobserved.",
        ),
        "events": _dimension(
            "proven-correct",
            "The handler is registered once by exact trait id with throttle 30, vehicle awareness, teardown, and reload-time unregister.",
        ),
        "stacking_interactions": _dimension(
            "runtime-unproven",
            "Focused proof preserves external raw writes and sharpness changes, isolates owners, deduplicates hands, and restores swaps and transfers.",
            "Live cross-owner weapon transfer remains unobserved.",
        ),
        "multiplayer": _dimension(
            "not-applicable",
            "DisabledInMultiplayer is true and multiplayer support is an explicit product non-goal.",
        ),
        "display": _dimension("proven-correct", "Exact English display name remains Two-Handed Axe."),
        "description": _dimension(
            "proven-correct",
            "English preserves +2 Axe and the accepted +10 two-handed Axe critical-chance claim.",
        ),
        "localization": _dimension(
            "proven-correct",
            "The complete supported English key pair exists with source-release parity; no other UniversalTraits locale is in scope.",
        ),
        "balance": _dimension(
            "proven-correct",
            "Accepted cost 4, Axe +2, and bounded +10 displayed points are unchanged; this milestone performs no rebalance.",
        ),
        "performance": _dimension(
            "runtime-unproven",
            "The bounded path checks at most two hand objects per throttled dispatch and tracks only exact objects currently owned by the handler.",
            "No current-build profiler or cadence observation exists.",
        ),
        "tests": _dimension(
            "proven-correct",
            "Sixteen focused standard-Lua cases cover formula, cap, domains, failures, refresh ownership, external composition, exact-object lifecycle, legacy retirement, isolation, idempotence, and parity.",
        ),
        "mocks": _dimension(
            "proven-correct",
            "Focused doubles expose sharpness-scaled critical state, injected getter/setter failures, exact object identity, modData, hands, lifecycle, and handler counts.",
        ),
        "source_release_parity": _dimension(
            "proven-correct",
            "Runtime, UI, definition, registry, tests, mocks, and audit are fingerprinted; packaged runtime, UI, definition, and registry counterparts are byte-identical.",
        ),
        "packaging": _dimension(
            "proven-correct",
            "All Two-Handed Axe-owned 42.0 runtime, UI, definition, and registry counterparts are present and identical.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Two-Handed Axe dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Accepted commits bb866066, fbec784, c3746c1, and "
            "6a2d55787650297d0b385e1138389f0e97f8ed10 prove exact-object restoration, "
            "bridge-error containment, failed-refresh ownership, tolerance, and idempotence in 16 focused cases."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua/Java bridge, full relaunch/current-version save-load, "
            "cross-owner live transfer, and profiler/cadence observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Live current-build Kahlua execution and Java-Lua bridge behavior remain unobserved.",
        "Full desktop relaunch and current-version save-load remain unobserved.",
        "Live cross-owner weapon transfer remains unobserved.",
        "Live tick cadence and profiler behavior remain unobserved.",
    ]
    row["validation"] = {
        "accepted_implementation_chain": [
            "bb866066",
            "fbec784",
            "c3746c1",
            "6a2d55787650297d0b385e1138389f0e97f8ed10",
        ],
        "final_independent_review": "ACCEPT; 16 focused cases passed; no blocking finding",
        "static_regression": "UniversalTraits focused Two-Handed Axe standard-Lua cases",
        "full_lua_suite": "not run by explicit campaign-evidence scope",
        "runtime_checks_unrun": [
            "current-build Kahlua and Java-Lua bridge",
            "full desktop relaunch and current-version save-load",
            "cross-owner live transfer",
            "profiler and cadence observation",
        ],
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
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row.update(
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        supported_accepted_finding_ids=list(FINDINGS),
        rejected_accepted_finding_ids=[],
        omissions=[],
        omission_disposition=(
            "no Two-Handed Axe-specific omission remains after exact-object lifecycle, "
            "bridge containment, failed-refresh ownership, tolerance, and idempotence proof"
        ),
        unresolved_runtime_proof_ids=[
            "RP0912-KAHLUA-001",
            "RP0912-SAVELOAD-001",
            "RP0912-BALANCE-PERF-001",
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
            "schema": "ut-twohanded-axes-critical-chance-ownership-v1",
            "trait_id": TRAIT,
            "authority": {
                "campaign_parent": "6a2d55787650297d0b385e1138389f0e97f8ed10",
                "accepted_implementation_chain": [
                    "bb866066",
                    "fbec784",
                    "c3746c1",
                    "6a2d55787650297d0b385e1138389f0e97f8ed10",
                ],
                "final_independent_review": {
                    "verdict": "ACCEPT",
                    "focused_cases": 16,
                    "blocking_findings": 0,
                },
            },
            "review_iterations": [
                {
                    "snapshot": "bb866066",
                    "disposition": "changes-requested",
                    "finding": "Java-Lua bridge and critical-state errors required containment.",
                    "resolved_by": "fbec784",
                },
                {
                    "snapshot": "fbec784",
                    "disposition": "changes-requested",
                    "finding": "A failed tracked refresh could discard exact-object ownership.",
                    "resolved_by": "c3746c1",
                },
                {
                    "snapshot": "c3746c1",
                    "disposition": "proof-requested",
                    "finding": "Scale-relative tolerance and no-rewrite idempotence required explicit regression proof.",
                    "resolved_by": "6a2d55787650297d0b385e1138389f0e97f8ed10",
                },
                {
                    "snapshot": "6a2d55787650297d0b385e1138389f0e97f8ed10",
                    "disposition": "accepted",
                    "finding": "No blocking finding; 16 focused cases passed.",
                    "resolved_by": None,
                },
            ],
            "accepted_intent": {
                "cost": 4,
                "xp_boosts": {"Axe": 2},
                "grants": [],
                "multiplayer": False,
                "eligible_owner": "current tick-dispatch owner with UniversalTraits:UT_twohanded_axes",
                "eligible_weapon": "exact HandWeapon object in either hand, Axe category, two-handed",
                "effect": "exactly +10 displayed critical-chance points capped at 100",
                "non_effects": [
                    "nonowners",
                    "ineligible weapons",
                    "unrelated modData",
                    "external critical-chance writes",
                    "other exact weapon objects",
                ],
                "english": DESCRIPTION,
            },
            "formula": {
                "sharpness_free": "displayed equals raw; effective sharpness is 1",
                "sharpness_bearing": "baseRaw=(displayed/currentSharpness)-ownedAppliedRawBonus",
                "target_displayed": "min(100, baseRaw * currentSharpness + 10)",
                "target_raw": "targetDisplayed / currentSharpness",
                "tracked_contribution": "targetRaw - baseRaw",
                "invalid_domains": "skip nonfinite displayed/raw/sharpness and nonpositive sharpness without losing existing ownership",
            },
            "lifecycle": {
                "ownership": "transient Lua table keyed by exact weapon object",
                "restoration": "subtract only the tracked raw contribution from the current raw value",
                "teardown": [
                    "unequip",
                    "hand swap",
                    "trait loss",
                    "death",
                    "inactive handler",
                    "reload replacement",
                ],
                "external_composition": "current external raw writes and sharpness changes are preserved",
                "cross_owner": "tracked objects restore before a different owner can retain the contribution",
                "legacy_retirement": "remove only UT_th_axesBaseCrit from encountered weapon modData",
                "persistent_moddata_written": False,
            },
            "resolved_findings": list(FINDINGS),
            "related_repaired_pattern_history": {
                "finding_ids": list(RELATED_HISTORY),
                "scope": (
                    "The accepted Two-Handed Axe path avoids the absolute cached-base mutation pattern. "
                    "IR0104 remains independently open for the separate UT_axes trait and is not closed by this milestone."
                ),
            },
            "focused_regression_cases": [
                "exact +10 displayed points and idempotence",
                "scale-relative rewrite tolerance",
                "category and handedness boundaries",
                "zero sharpness and general API failures",
                "every critical-state getter and setter failure",
                "ownership across failed tracked refresh",
                "every invalid sharpness domain",
                "cap 100 and sharpness conversion",
                "hand deduplication, swaps, and transfers",
                "trait loss, death, and inactive teardown",
                "external raw writes and sharpness changes",
                "selective UT_th_axesBaseCrit retirement",
                "duplicate-load restore and one handler",
                "cross-owner isolation and setter-failure drain",
                "setter-failure reload without retry or duplication",
                "contract and source-release parity",
            ],
            "files": [_input_metadata_lf(root, source) for source in files],
            "retained_runtime_proof": [
                "current-build Kahlua and Java-Lua bridge observation",
                "full desktop relaunch and current-version save-load",
                "cross-owner live transfer",
                "profiler and cadence observation",
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
        raise RuntimeError("Two-Handed Axe output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace=transaction.os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Two-Handed Axe output set")
    original = transaction.OWNED_OUTPUTS
    try:
        transaction.OWNED_OUTPUTS = OWNED_OUTPUTS
        return transaction.commit_plan(plan, campaign, replace)
    finally:
        transaction.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_twohanded_axes.py")
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
