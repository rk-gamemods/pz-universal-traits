"""Regenerate only Sharpshooter-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_scardycat as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_sharpshooter"
FINDINGS = ("B10-SHARPSHOOTER-001",)
DESCRIPTION = (
    "+2 to Aiming. Equipped firearms have 25 percent more hit chance and effective range."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sharpshooter.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_sharpshooter.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_sharpshooter.md"
RESOLUTION = "change-impact/sharpshooter-weapon-lifecycle.json"
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


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_10.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
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
            "proven-correct", "All owned surfaces use UniversalTraits:UT_sharpshooter."
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is 4, XPBoosts grants Aiming=2, there are no grants or exclusions, and DisabledInMultiplayer is true.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master definition, English, and runtime agree on +2 Aiming and 25 percent more hit chance and effective range for equipped firearms.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "One UTCore handler reconciles at most two equipped ranged HandWeapons and owns only its applied hit-chance and maximum-range deltas.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "Hit chance is min(100, floor(base * 1.25)); raw maximum range is base * 1.25; restoration removes the actual applied deltas.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "The light vehicle-aware reconciliation runs every 30 player updates; OnSave performs one bounded pre-serialization restoration.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Sharpshooter has no cooldown beyond its reconciliation cadence."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "Swap, unequip, trait deactivation, invalid-player teardown, unregister, reload, and OnSave use one delta-restoration path; SVN 964 serializes both changed fields only after OnSave fires.",
            "A full current-build save/load, drop/transfer, death, and repeated-world-entry observation remains required.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves the integer hit-chance field, float maximum-range field, additive weapon-part changes, field serialization, and pre-cell-save OnSave ordering.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible tables, identity keys, numeric loops, and directly verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "One reload-safe UTCore registration and one replace-on-reload OnSave callback own all application and cleanup paths.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "Identity deduplication and per-field deltas preserve later additive weapon-part or mod changes without transferring the owner-bound bonus.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables Sharpshooter in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Sharpshooter."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English exactly states +2 Aiming and 25 percent more hit chance and effective range for equipped firearms.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost 4, +2 Aiming, and 1.25 field-multiplier contract.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "The 30-update handler examines at most two equipped objects plus the small tracked set; OnSave is event-driven and bounded.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact math, flooring, cap, ranged gating, swap, aliasing, external additive changes, save restoration, reload, definition, English, and parity.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "MockWeapon reproduces the two mutable field domains and Events.OnSave reproduces add/remove/fire registration for lifecycle proof.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Sharpshooter runtime, definition, and English source and 42.0 release pairs are byte-identical.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All Sharpshooter-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification reports no release drift; UniversalTraits lacks the separately tracked source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Sharpshooter dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "The corrected runtime owns and removes only its applied deltas on swap, unequip, trait deactivation, teardown, reload, and the pre-serialization OnSave boundary. Focused tests prove exact restoration and save reapplication."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua, live drop/transfer, trait removal, weapon-part changes, death, repeated world entry, save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua execution, full relaunch, repeated world entry, death, and current-version save/load remain unobserved.",
        "Live drop/transfer and weapon-part attachment or removal while active remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": (
            "SVN 964 HandWeapon.java:959-974,1543-1548,1612-1790,2068-2110 and GameWindow.java:1020-1085"
        ),
        "static_regression": "UniversalTraits standard-Lua suite",
        "runtime_checks_unrun": [
            "game launch",
            "drop and transfer",
            "weapon-part change",
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


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["supported_accepted_finding_ids"] = [*FINDINGS]
    row["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "resolved_finding_ids": [*FINDINGS],
        "open_finding_ids": [],
        "remaining_runtime_proof": (
            "Current-build Kahlua, live transfer, weapon-part changes, save/load, rendered English, balance, and profiler observation remain unrun."
        ),
    }
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "source_english_sha256": HELPER._metadata(root, SOURCE_UI)["sha256"],
        "release_english_sha256": HELPER._metadata(root, RELEASE_UI)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-sharpshooter-weapon-lifecycle-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost 4, Aiming=2, equipped ranged HandWeapons receive 1.25 hit-chance and maximum-range multipliers"
                ),
                "pz_snapshot": (
                    "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json"
                ),
            },
            "accepted_intent": {
                "cost": 4,
                "xp_boosts": {"Aiming": 2},
                "weapon_scope": "equipped ranged HandWeapon",
                "hit_chance_formula": "min(100, floor(base * 1.25))",
                "maximum_range_formula": "base * 1.25",
                "dispatch_throttle": 30,
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java:959-974,1543-1548,1612-1790,2068-2110",
                "PZCodebase/Java/source/zombie/GameWindow.java:1020-1085",
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
                "exact relative hit chance and range without compounding",
                "integer flooring and 100 hit-chance cap",
                "non-ranged rejection",
                "swap and unequip restoration",
                "primary-secondary identity deduplication",
                "later additive weapon-field change preservation",
                "pre-save restoration and next-dispatch reapplication",
                "duplicate load teardown and one tick/save registration",
                "definition, exact English, and source-release parity",
            ],
            "performance_model": (
                "One light handler runs every 30 player updates over at most two equipped objects plus the small tracked set; OnSave performs one bounded event-driven restoration."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build Kahlua, equip/swap/drop/transfer, trait removal, death, repeated world entry, weapon-part changes, save/load, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing Sharpshooter cost, Aiming grant, magnitude, ranged scope, or intended stacking",
            ],
        }
    )


@contextmanager
def _configured_base() -> Iterator[None]:
    replacements: dict[str, Any] = {
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
        raise RuntimeError("Sharpshooter output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_sharpshooter.py")
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
