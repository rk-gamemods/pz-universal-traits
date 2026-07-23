"""Regenerate only Tavern Brawler-owned campaign evidence and ledgers."""

from __future__ import annotations

import hashlib
import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import build_final_trait_ledger
import regenerate_owlperson as transaction
import regenerate_martial as base
from campaign_cli import no_arg_command

ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
HELPER = base.base.base.shared.base
TRAIT = "UniversalTraits:UT_tavernbrawler"
FINDINGS = ("B11-TAVERN-001",)
DESCRIPTION = "+1 to Small Blunt. Stomping a downed zombie kills it instantly."
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_tavernbrawler.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_tavernbrawler.lua"
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
SOURCE_DEFINITION = "UniversalTraits/media/scripts/UT_character_traits.txt"
RELEASE_DEFINITION = "UniversalTraits/release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt"
SOURCE_REGISTRY = "UniversalTraits/media/registries.lua"
RELEASE_REGISTRY = "UniversalTraits/release/UniversalTraits/42.0/media/registries.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
ACTIVE_AUDIT = "trait-deep-audit/active/batch/traits/UT_tavernbrawler.md"
RESOLUTION = "change-impact/tavernbrawler-stomp-contract.json"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl", "source_inventory.json", "translation_audit.json",
    "independent_reviews/traits_09_12.json", "release_blocker_queue.json", RESOLUTION,
    "final_trait_ledger.json", "final_trait_ledger_rows.jsonl", "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl", "remediation_summary.json", "campaign_manifest.json",
)


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return HELPER._dimension(state, evidence, missing) if missing else HELPER._dimension(state, evidence)


def _metadata(root: Path, relative: str) -> dict[str, object]:
    data = _normalized_bytes(root / relative)
    return {
        "path": relative,
        "sha256": hashlib.sha256(data).hexdigest().upper(),
        "bytes": len(data),
    }


def _normalized_bytes(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n")


def _normalized_sha256(path: Path) -> str:
    return hashlib.sha256(_normalized_bytes(path)).hexdigest().upper()


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_11.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = HELPER._exactly_one(rows, "trait_id", TRAIT, relative)
    old = row["dimensions"]
    dimensions = {
        "registration": old["registration"],
        "definition_parser": _dimension("proven-correct", "Cost 2, SmallBlunt +1, no grants or exclusions, and multiplayer disabled are exact in source and release definitions."),
        "namespace": old["namespace"],
        "cost_xp_grants_exclusions": _dimension("proven-correct", "Cost 2; SmallBlunt +1; no grants or exclusions; multiplayer disabled."),
        "source_intent": _dimension("proven-correct", "The accepted pre-campaign outcome is true-stomp instant kill, preserving the original 30 direct-health magnitude on the SVN 964 health scale."),
        "runtime_path": _dimension("proven-correct", "OnHitZombie gates local attacker, trait, and isShoveStompAnim, then subtracts 30 before vanilla damage and calls Kill(attacker) once when lethal."),
        "numbers": _dimension("proven-correct", "Thirty direct health is instant-kill magnitude against ordinary SVN 964 zombie health 1.8 through 2.1; it is not moderate damage."),
        "cadence": _dimension("runtime-unproven", "At most one trait application per owned OnHitZombie callback.", "Live event production and callback count remain unobserved."),
        "cooldown": _dimension("not-applicable", "No cooldown."),
        "reset_save_load": _dimension("runtime-unproven", "The module statically removes its previous owned callback before adding one replacement.", "New game, save-load, death, and repeated world entry remain unobserved."),
        "java_lua": _dimension("proven-correct", "SVN 964 exposes isShoveStompAnim, exact four-argument OnHitZombie production before super.Hit, health accessors, and Kill(attacker)."),
        "kahlua": _dimension("runtime-unproven", "The source uses verified Java-Lua receiver methods and compatible Lua shapes.", "Current-build Kahlua execution and values remain unobserved."),
        "events": _dimension("proven-correct", "Exact callback signature is OnHitZombie(zombie, attacker, bodyPart, weapon); SwipeStatePlayer sets the stomp flag before collision and clears it on exit."),
        "stacking_interactions": _dimension("proven-correct", "Armed prone, ordinary unarmed prone, standing, absent-trait, and wrong-player hits receive no trait damage; reload leaves one owned handler."),
        "multiplayer": _dimension("not-applicable", "DisabledInMultiplayer is true and multiplayer support is a product non-goal."),
        "display": _dimension("proven-correct", "Exact English display name is Tavern Brawler."),
        "description": _dimension("proven-correct", "English truthfully says a stomp kills a downed zombie instantly and retains Small Blunt +1."),
        "localization": _dimension("coverage-gap", "Exact English keys exist with source/release parity.", "No non-English UniversalTraits locale exists."),
        "balance": _dimension("runtime-unproven", "Accepted cost-2 contract intentionally grants true-stomp instant kill.", "No gameplay balance telemetry exists."),
        "performance": _dimension("runtime-unproven", "One constant-time callback with early guards is registered.", "No current-build profiler capture exists."),
        "tests": _dimension("proven-correct", "Focused standard-Lua tests cover exact arguments, discriminator negatives, 30-point ordering, lethal attribution, trait/player gates, and reload-safe handler count."),
        "mocks": _dimension("proven-correct", "Mocks enforce exactly four event arguments, expose the true-stomp flag, track health writes and Kill calls, and reject prior false confidence."),
        "source_release_parity": _dimension("proven-correct", "Runtime, UI, definition, registry, tests, and mocks are fingerprinted; all packaged source/release pairs are byte-identical."),
        "packaging": _dimension("coverage-gap", "Tavern-owned 42.0 runtime, UI, definition, and registry counterparts are present and identical.", "The separate pre-existing source poster issue remains open."),
    }
    if tuple(dimensions) != HELPER.CANONICAL_DIMENSIONS:
        raise RuntimeError("Tavern Brawler dimension canonicalization drifted")
    row["dimensions"] = dimensions
    row["overall_state"] = "runtime-unproven"
    finding = HELPER._exactly_one(row["findings"], "id", FINDINGS[0], relative)
    finding.update(
        resolution_state="proven-correct",
        resolution_evidence="Accepted commit 0af8b161772237f245e5ef22be614b653279c20c proves the true-stomp discriminator, exact event signature, negative armed-prone case, exact health ordering, kill attribution, and reload-safe callback.",
        missing_proof="",
        remaining_runtime_proof="Current-build Kahlua, live event arguments and stomp flag timing, health ordering, handler count, kill attribution, lifecycle, gameplay, balance, profiler, rendered English, and localization remain unobserved.",
    )
    row["unknowns"] = [
        "Current-build Kahlua and live event arguments, stomp flag timing, health ordering, handler count, and kill attribution remain unobserved.",
        "New game, save-load, death, repeated world entry, gameplay, balance, and profiler observation remain unrun.",
        "Rendered English and non-English localization remain unobserved; the source poster issue remains separate.",
    ]
    row["validation"] = {
        "engine_contract": "SVN 964 SwipeStatePlayer.java:228,410; IsoGameCharacter.java:1163-1168,15249-15264; IsoZombie.java:554,1357",
        "behavior_commit": "0af8b161772237f245e5ef22be614b653279c20c",
        "static_regression": "UniversalTraits focused Tavern Brawler standard-Lua cases",
        "runtime_checks_unrun": ["game launch", "live event/flag/order/kill", "new game and save-load", "profiler capture"],
        "explicit_non_goals": ["multiplayer", "backward save migration", "deployment"],
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    plan[relative] = ("\n".join(replacement if parsed.get("trait_id") == TRAIT else line for parsed, line in zip(rows, lines)) + "\n").encode()


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
                   SOURCE_REGISTRY, RELEASE_REGISTRY, MOCKS, TESTS, ACTIVE_AUDIT):
        HELPER._update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = HELPER._exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["supported_accepted_finding_ids"] = list(FINDINGS)
    row["rejected_accepted_finding_ids"] = []
    row["omissions"] = []
    row["omission_disposition"] = "no Tavern-specific omission remains; armed-prone, signature, mock-confidence, and duplicate-handler defects are closed by 0af8b16"
    row["unresolved_runtime_proof_ids"] = ["RP0912-KAHLUA-001", "RP0912-SAVELOAD-001", "RP0912-BALANCE-PERF-001", "RP0912-LOCALE-001"]
    row["resolution_record"] = RESOLUTION
    row["release_parity"] = {
        "runtime_source": _metadata(root, RUNTIME)["sha256"],
        "runtime_release": _metadata(root, RELEASE)["sha256"],
        "ui_source": _metadata(root, SOURCE_UI)["sha256"],
        "ui_release": _metadata(root, RELEASE_UI)["sha256"],
        "definition_source": _metadata(root, SOURCE_DEFINITION)["sha256"],
        "definition_release": _metadata(root, RELEASE_DEFINITION)["sha256"],
        "registry_source": _metadata(root, SOURCE_REGISTRY)["sha256"],
        "registry_release": _metadata(root, RELEASE_REGISTRY)["sha256"],
        "tests": _metadata(root, TESTS)["sha256"],
        "mocks": _metadata(root, MOCKS)["sha256"],
        "state": "proven-correct",
    }
    plan[relative] = HELPER._json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    files = (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, SOURCE_DEFINITION, RELEASE_DEFINITION,
             SOURCE_REGISTRY, RELEASE_REGISTRY, TESTS, MOCKS, ACTIVE_AUDIT)
    plan[RESOLUTION] = HELPER._json_bytes({
        "schema": "ut-tavernbrawler-stomp-contract-v1",
        "trait_id": TRAIT,
        "authority": {"accepted_behavior_commit": "0af8b161772237f245e5ef22be614b653279c20c", "pz_snapshot": "SVN revision 964"},
        "accepted_intent": {"cost": 2, "xp_boosts": {"SmallBlunt": 1}, "grants": [], "exclusions": [], "multiplayer": False, "trigger": "attacker:isShoveStompAnim()", "direct_health_before_vanilla": 30, "outcome": "instant kill for ordinary SVN 964 zombies"},
        "engine_sequence": [
            "SwipeStatePlayer.java:228 sets shoveStompAnim",
            "IsoZombie.java:1357 fires OnHitZombie(zombie,attacker,bodyPart,weapon) before super.Hit",
            "UT_tavernbrawler subtracts 30 and calls Kill(attacker) once when lethal",
            "SwipeStatePlayer.java:410 clears shoveStompAnim on exit",
        ],
        "health_scale": {"ordinary_zombie": "1.8 through 2.1", "anchor": "IsoZombie.java:554", "conclusion": "30 is instant-kill magnitude, not moderate damage"},
        "resolved_findings": list(FINDINGS),
        "resolved_independent_defects": ["armed-prone false positive", "wrong event signature", "test/mock false confidence", "duplicate handler"],
        "retained_runtime_proof": ["current-build Kahlua", "live event arguments and stomp flag", "health ordering", "handler count", "kill attribution", "new game and save-load", "death and repeated world entry", "gameplay and balance", "profiler", "rendered English", "non-English localization", "source poster issue"],
        "files": [_metadata(root, source) for source in files],
        "runtime_proof": "Unobserved; static and standard-Lua evidence do not establish current-version live gameplay.",
        "non_goals": ["multiplayer", "backward save migration", "deployment"],
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
    original_metadata = HELPER._metadata
    original_ledger_sha256 = build_final_trait_ledger._sha256
    try:
        for name, value in replacements.items():
            setattr(base, name, value)
        HELPER._metadata = _metadata
        build_final_trait_ledger._sha256 = _normalized_sha256
        yield
    finally:
        build_final_trait_ledger._sha256 = original_ledger_sha256
        HELPER._metadata = original_metadata
        for name, value in originals.items():
            setattr(base, name, value)


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    with _configured_base():
        plan = base.build_plan(root, campaign)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Tavern Brawler output plan escaped its ownership set")
    return plan


def commit_plan(plan: dict[str, bytes], campaign: Path = CAMPAIGN, replace=transaction.os.replace) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Tavern Brawler output set")
    if all(
        (campaign / relative).is_file()
        and _normalized_bytes(campaign / relative) == plan[relative].replace(b"\r\n", b"\n")
        for relative in OWNED_OUTPUTS
    ):
        return []
    original = transaction.OWNED_OUTPUTS
    try:
        transaction.OWNED_OUTPUTS = OWNED_OUTPUTS
        return transaction.commit_plan(plan, campaign, replace)
    finally:
        transaction.OWNED_OUTPUTS = original


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_tavernbrawler.py")
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
