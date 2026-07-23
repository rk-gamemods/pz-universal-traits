"""Regenerate only Short Blade-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_owlperson as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_short_blades"
FINDINGS = (
    "B10-SHORT_BLADES-001",
)
DESCRIPTION = "+2 to Small Blade. Small Blade weapons have +10 critical-chance points, and primary-hand attacks with them have 50 percent lower melee delay."
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_short_blades.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_short_blades.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_short_blades.md"
RESOLUTION = "change-impact/short_blades-critical-chance-lifecycle.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_10.jsonl",
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


def _old_dimension(
    dimensions: dict[str, Any], canonical: str, legacy: str | None = None
) -> dict[str, Any]:
    for key in (canonical, legacy):
        if key is not None and key in dimensions:
            return dimensions[key]
    raise KeyError(f"missing Short Blade dimension: {canonical}")


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_10.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": HELPER._dimension(
            "proven-correct",
            "The namespaced registry entry, complete definition, runtime key, and English keys agree.",
        ),
        "definition_parser": HELPER._dimension(
            "runtime-unproven",
            "The complete source and release definitions are byte-identical and parse in the standard-Lua consistency suite.",
            "Current-build ScriptManager parsing has not been observed in game.",
        ),
        "namespace": HELPER._dimension(
            "proven-correct", "All owned surfaces use UniversalTraits:UT_short_blades."
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is 4, XPBoosts grants SmallBlade=2, the reciprocal weapon-tree exclusions are unchanged, and DisabledInMultiplayer is true.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master establishes +2 Small Blade and +10 displayed critical chance; current accepted runtime also retains the primary-hand 50 percent melee-delay effect.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "The UTCore handler reconciles equipped Small Blade weapons, applies one owner-scoped raw delta, and restores every no-longer-eligible tracked object.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "The effect adds exactly 10 displayed critical-chance points, caps at 100, and records the actual applied raw delta.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "UTCore dispatches the light handler every 30 player updates, including vehicle reconciliation.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Short Blade has no cooldown beyond its 30-update reconciliation cadence."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "Unequip, swap, unregister, duplicate load, trait-handler deactivation, and invalid-player teardown all use the same delta restoration path; SVN 964 HandWeapon save/load omits criticalChance.",
            "A full current-build drop/transfer, repeated-world-entry, death, and save/load observation remains required.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves HandWeapon category membership, sharpness, displayed getter, raw setter, save/load field list, and script initialization contracts.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible tables, identity keys, pcall, numeric loops, and verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "One reload-safe UTCore registration owns the handler and teardown callback; UTCore rebuild and invalid-player paths invoke teardown.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "Identity deduplication and the per-owner raw delta preserve later external changes without changing the separate primary-hand melee-delay path.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables Short Blade in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Short Blade."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English exactly states +2 Small Blade, +10 critical-chance points, and the primary-hand 50 percent melee-delay effect.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost 4, +2 skill, and +10 displayed critical-chance contract.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "The 30-update handler examines at most two equipped items plus the small tracked-weapon set.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact delta, cap, sharpness domains, exact category rejection, both hands, swap, deduplication, trait lifecycle, external changes, bridge failures, reload, delay scope, definition, copy, and parity.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "MockWeapon reproduces SVN 964's sharpness-adjusted getter, raw setter, exact WeaponCategory membership, and raw-field assertion surface.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Short Blade runtime, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All Short Blade-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Short Blade dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "The corrected runtime owns only its applied raw delta and restores it on swap, unequip, unregister, reload, and shared teardown paths. Focused tests prove transfer-equivalent restoration and modifier composition."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua, live drop/transfer, trait removal, death, repeated world entry, save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, death, and current-version save/load remain unobserved.",
        "Live drop/transfer and concurrent external critical-chance mutation remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": "SVN 964 HandWeapon.java:1495-1500,1612-1845 and Item.java:2149",
        "static_regression": "UniversalTraits standard-Lua suite",
        "runtime_checks_unrun": [
            "game launch",
            "drop and transfer",
            "current-version save-load",
            "profiler capture",
        ],
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
    runtime_files = artifact["inventory"]["raw_source_sets"]["runtime_files"]
    runtime_files["ids"] = sorted({*runtime_files["ids"], TRAIT})
    runtime_files["paths"] = sorted({*runtime_files["paths"], RUNTIME})
    runtime_files["count"] = len(runtime_files["ids"])
    for mapping_id, mapping in artifact["reconciliation"][
        "pairwise_bidirectional_mappings"
    ].items():
        if "runtime_files" not in mapping_id:
            continue
        for field in ("left_missing", "left_extra", "right_missing", "right_extra"):
            mapping[field] = [item for item in mapping[field] if item != TRAIT]
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
        HELPER._update_fingerprints(artifact, source, HELPER._metadata(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row.update(
        accepted_overall_state="runtime-unproven",
        independent_state="runtime-unproven",
        omission_disposition=(
            "B10-SHORT_BLADES-001 is implemented and statically validated. "
            "The trait now has both the critical-chance and primary-hand melee-delay runtime paths; "
            "current-build execution, balance/performance, and absent locales remain unresolved."
        ),
        supported_accepted_finding_ids=[*FINDINGS],
    )
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-short_blades-critical-chance-lifecycle-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": "cost 4, SmallBlade=2, +10 displayed critical-chance points on exact Small Blade weapons, plus the retained primary-hand 50 percent melee-delay effect",
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 4,
                "xp_boosts": {"SmallBlade": 2},
                "weapon_category": "WeaponCategory.SMALL_BLADE",
                "displayed_critical_chance_delta": 10,
                "displayed_critical_chance_cap": 100,
                "dispatch_throttle": 30,
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java:1495-1500,1612-1845",
                "PZCodebase/Java/source/zombie/scripting/objects/Item.java:2149",
                "UT_CORE/media/lua/shared/UTCore/UTCore_TickDispatch.lua:28-177,379-496",
                RUNTIME,
            ],
            "files": [
                HELPER._metadata(root, source)
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
                "exact +10 displayed critical chance without compounding",
                "100 cap with exact capped-delta restoration",
                "sharpness-adjusted getter and raw setter conversion",
                "non-Small-Blade and zero-sharpness rejection",
                "swap and unequip restoration",
                "primary-secondary identity deduplication",
                "later external raw-field change preservation",
                "external raw mutation preservation and independent restoration",
                "duplicate load teardown and one registration",
                "definition, exact English, and source-release parity",
            ],
            "performance_model": (
                "One light handler runs every 30 player updates and examines at most two equipped items plus the small tracked-weapon set."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build Kahlua, equip/swap/drop/transfer, trait removal, death, repeated world entry, save/load, sharpness, external modifier overlap, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing Short Blade cost, skill grant, magnitude, category, or intended stacking",
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
        raise RuntimeError("Short Blade output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Short Blade output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate-short_blades-", dir=campaign))
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
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_short_blades.py")
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
