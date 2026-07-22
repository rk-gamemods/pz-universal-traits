"""Regenerate only Staunch-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

import regenerate_sharpshooter as base
from campaign_cli import no_arg_command


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.HELPER
TRAIT = "UniversalTraits:UT_staunch"
FINDINGS = ("B11-STAUNCH-BLEED-STACK-001",)
DESCRIPTION = (
    "You have solid medical training and recover from treated wounds well. +1 to First Aid. "
    "Bandaged wounds stop bleeding faster, but unbandaged wounds are unaffected."
)
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_staunch.lua"
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/"
    "UT_staunch.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = (
    "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
)
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_staunch.md"
RESOLUTION = "change-impact/staunch-bleed-decay-composition.json"
CORE_STAT = "UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
CORE_STAT_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
CORE_HOOK = "UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua"
CORE_HOOK_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua"
CORE_MOCKS = "UT_CORE/test/UTCoreMocks.lua"
CORE_TESTS = "UT_CORE/test/run_tests.lua"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl",
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
    relative = "trait_batches/batch_11.jsonl"
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
            "proven-correct", "All owned surfaces use UniversalTraits:UT_staunch."
        ),
        "cost_xp_grants_exclusions": HELPER._dimension(
            "proven-correct",
            "Cost is 10, XPBoosts grants Doctor=1, no grants or exclusions exist, and DisabledInMultiplayer is true.",
        ),
        "source_intent": HELPER._dimension(
            "proven-correct",
            "Pre-campaign master defines 3x bandaged wound closure and explicitly requires 4.5x when combined with Thick Blood.",
        ),
        "runtime_path": HELPER._dimension(
            "proven-correct",
            "OnCreatePlayer and one throttled lifecycle handler own a named 3.0 bandaged-only source consumed by the shared bleed-decay hook.",
        ),
        "numbers": HELPER._dimension(
            "proven-correct",
            "Native rates are 0.0002 bandaged and 0.00002 unbandaged per update; exact factor products are 3.0 alone, 4.5 with Thick Blood, and 0.99 with Anemic while bandaged.",
        ),
        "cadence": HELPER._dimension(
            "proven-correct",
            "OnCreatePlayer applies immediately, a light vehicle-aware handler reconciles every 30 updates, and the core hook applies accumulated extra decay every 10 updates.",
        ),
        "cooldown": HELPER._dimension(
            "not-applicable", "Staunch has no probabilistic trigger or cooldown."
        ),
        "reset_save_load": HELPER._dimension(
            "runtime-unproven",
            "Named-source removal covers deactivation, invalid player, replacement, unregister, and reload; OnCreatePlayer reasserts on new game and save load.",
            "A full current-build new-game and save-load lifecycle remains unobserved.",
        ),
        "java_lua": HELPER._dimension(
            "proven-correct",
            "SVN 964 proves event ordering, native BodyPart rates, the 0-based body-part list, setters, bandage state, and embedded-glass floor.",
        ),
        "kahlua": HELPER._dimension(
            "runtime-unproven",
            "The implementation uses Kahlua-compatible tables, numeric loops, pcall boundaries, and verified Java receiver methods.",
            "Current-build Kahlua execution is unobserved.",
        ),
        "events": HELPER._dimension(
            "proven-correct",
            "New-game OnNewGame precedes OnCreatePlayer; save load fires OnCreatePlayer; registrations are replace-on-reload and teardown-aware.",
        ),
        "stacking_interactions": HELPER._dimension(
            "proven-correct",
            "Independent factors multiply deterministically: Thick Blood remains 1.5x on all wounds and composes to 4.5x bandaged; Anemic composes to 0.99x bandaged and remains 0.33x unbandaged.",
        ),
        "multiplayer": HELPER._dimension(
            "not-applicable",
            "The definition disables Staunch in multiplayer and multiplayer support is an explicit product non-goal.",
        ),
        "display": HELPER._dimension(
            "proven-correct", "The exact English display name is Staunch."
        ),
        "description": HELPER._dimension(
            "proven-correct",
            "English states +1 First Aid, faster bandaged wound closure, and no unbandaged benefit without inventing a stack formula for the player.",
        ),
        "localization": HELPER._dimension(
            "coverage-gap",
            "The exact English keys exist in source and release.",
            "No non-English UniversalTraits locale exists.",
        ),
        "balance": HELPER._dimension(
            "runtime-unproven",
            "Static behavior remains the pre-campaign cost 10, Doctor=1, and 3.0 bandaged factor contract.",
            "No gameplay telemetry or comparative balance session exists.",
        ),
        "performance": HELPER._dimension(
            "runtime-unproven",
            "Staunch adds one scalar bucket write every 30 updates; the existing core hook still scans at most 64 parts every 10 updates.",
            "No current-build profiler capture exists.",
        ),
        "tests": HELPER._dimension(
            "proven-correct",
            "Focused tests cover exact wound-state math, Thick Blood and Anemic composition, source removal, legacy preservation, deactivation, and duplicate load.",
        ),
        "mocks": HELPER._dimension(
            "proven-correct",
            "Mock BodyPart now exposes bleeding time, bandage state, and embedded-glass state; event mocks support removal and handler counts.",
        ),
        "source_release_parity": HELPER._dimension(
            "proven-correct",
            "Staunch runtime and both changed UT_CORE runtime pairs are byte-identical between source and 42.0 release.",
        ),
        "packaging": HELPER._dimension(
            "coverage-gap",
            "All Staunch-owned 42.0 runtime, definition, and English counterparts are present and identical.",
            "Read-only package verification still tracks the separate missing source poster.",
        ),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Staunch dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence=(
            "Staunch now owns a named bandaged-only factor. The shared hook multiplies independent all-wound and bandaged factors, producing the master-required 4.5x Thick Blood combination without overwriting either owner."
        ),
        missing_proof="",
        remaining_runtime_proof=(
            "Current-build Kahlua, live wound-state combinations, new game, save load, trait removal, death, repeated world entry, embedded glass, rendered English, balance, and profiler observation remain unrun."
        ),
    )
    row["unknowns"] = [
        "Current-build Kahlua, live new-game and save-load lifecycle, death, and repeated world entry remain unobserved.",
        "Live bandaged, unbandaged, embedded-glass, Thick Blood, Anemic, and trait-removal behavior remain unobserved.",
        "Rendered English, balance telemetry, and profiler capture remain unobserved.",
        "Only English UI localization exists in the closed-world source inventory.",
        "Multiplayer and backward save migration are explicit non-goals.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "engine_contract": (
            "SVN 964 BodyPart.java:215-233,1260-1266; IsoPlayer.java:2011-2035,2233-2242; "
            "IsoGameCharacter.java:9731-9743; IsoWorld.java:2160-2209; GameLoadingState.java:400-431"
        ),
        "static_regression": ["UT_CORE standard-Lua suite", "UniversalTraits standard-Lua suite"],
        "runtime_checks_unrun": [
            "game launch",
            "new game and save load",
            "wound-state composition",
            "trait removal and death",
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
            "Current-build Kahlua, live wound composition, new game, save load, trait removal, death, rendered English, balance, and profiler observation remain unrun."
        ),
    }
    row["release_parity"] = {
        "source_runtime_sha256": HELPER._metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": HELPER._metadata(root, RELEASE)["sha256"],
        "source_core_stat_sha256": HELPER._metadata(root, CORE_STAT)["sha256"],
        "release_core_stat_sha256": HELPER._metadata(root, CORE_STAT_RELEASE)["sha256"],
        "source_core_hook_sha256": HELPER._metadata(root, CORE_HOOK)["sha256"],
        "release_core_hook_sha256": HELPER._metadata(root, CORE_HOOK_RELEASE)["sha256"],
        "state": "proven-correct",
    }
    row["resolution_record"] = RESOLUTION
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = HELPER._json_bytes(
        {
            "schema": "ut-staunch-bleed-decay-composition-v1",
            "trait_id": TRAIT,
            "authority": {
                "accepted_baseline": "pre-campaign UTMods master",
                "accepted_contract": (
                    "cost 10, Doctor=1, 3.0 bandaged-only wound-closure factor, and 4.5 combined bandaged factor with Thick Blood"
                ),
                "pz_snapshot": "SVN revision 964; Steam BuildID 23504596 is recorded outside VERSION.json",
            },
            "accepted_intent": {
                "cost": 10,
                "xp_boosts": {"Doctor": 1},
                "staunch_bandaged_factor": 3.0,
                "staunch_unbandaged_factor": 1.0,
                "thick_blood_combined_bandaged_factor": 4.5,
                "anemic_combined_bandaged_factor": 0.99,
                "runtime_scope": "single-player",
            },
            "resolved_findings": [*FINDINGS],
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyPart.java:215-233,1260-1266",
                "PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2011-2035,2233-2242",
                "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:9731-9743",
                "PZCodebase/Java/source/zombie/iso/IsoWorld.java:2160-2209",
                "PZCodebase/Java/source/zombie/gameStates/GameLoadingState.java:400-431",
                CORE_STAT,
                CORE_HOOK,
                RUNTIME,
            ],
            "files": [
                HELPER._metadata(root, source)
                for source in (
                    RUNTIME,
                    RELEASE,
                    CORE_STAT,
                    CORE_STAT_RELEASE,
                    CORE_HOOK,
                    CORE_HOOK_RELEASE,
                    SOURCE_UI,
                    RELEASE_UI,
                    SOURCE_DEFINITION,
                    RELEASE_DEFINITION,
                    MOCKS,
                    TESTS,
                    CORE_MOCKS,
                    CORE_TESTS,
                    ACTIVE_AUDIT,
                )
            ],
            "regression_cases": [
                "named bandaged-only source without legacy overwrite",
                "exact Staunch-only bandaged and unbandaged behavior",
                "exact 4.5x and 1.5x Staunch plus Thick Blood behavior",
                "exact 0.99x and 0.33x Staunch plus Anemic behavior",
                "named-source removal preserving another modifier",
                "deactivation and player replacement cleanup",
                "duplicate load registration replacement and stale-state cleanup",
                "source-release parity",
            ],
            "performance_model": (
                "One scalar bucket write every 30 player updates; the existing shared hook scans the bounded body-part list every 10 updates."
            ),
            "runtime_proof": (
                "Unobserved; requires full Exit to Desktop, current-build Kahlua, new game, save load, bandaged and unbandaged wounds, Thick Blood, Anemic, trait removal, death, repeated world entry, embedded glass, rendered English, balance, and profiler observation."
            ),
            "non_goals": [
                "multiplayer",
                "backward save migration",
                "deployment",
                "changing Staunch cost, First Aid grant, magnitude, wound scope, or selection compatibility",
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
        raise RuntimeError("Staunch output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    with _configured_base():
        return base.commit_plan(plan, campaign, replace)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_staunch.py")
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
