"""Regenerate only Immunocompromised-owned campaign evidence and ledgers."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256
from campaign_cli import no_arg_command
from regenerate_immuneresponse import (
    _exactly_one,
    _json_bytes,
    _metadata,
    _update_fingerprints,
)


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_immunocompromised"
FINDING = "B05-IMMUNOCOMP-001"
BLOCKER_IDENTITY = "trait:UT_immunocompromised"
DESCRIPTION = (
    "Every in-game minute, existing zombie infection increases by 1, up to a "
    "maximum of 100."
)
RUNTIME = (
    "UniversalTraits/media/lua/shared/UniversalTraits/traits/"
    "UT_immunocompromised.lua"
)
RELEASE = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/"
    "UniversalTraits/traits/UT_immunocompromised.lua"
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = (
    "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
)
TESTS = "UniversalTraits/test/run_tests.lua"
RESOLUTION = "change-impact/immunocompromised-infection-channel-resolution.json"
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


def _dimension(state: str, evidence: str, missing: str = "none") -> dict[str, str]:
    return {"state": state, "evidence": evidence, "missing_proof": missing}


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_05.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    proof = (
        "EveryOneMinute reads and writes only CharacterStat.ZOMBIE_INFECTION, "
        "adds exactly 1 when above zero, and caps the value at 100."
    )
    row["dimensions"]["source_intent"] = _dimension(
        "proven",
        "Pre-campaign master establishes the fixed zombie-infection increase and new-game marker; upstream MoreTraits wound behavior is not restored.",
    )
    row["dimensions"]["runtime_ut_core_path"] = _dimension("proven", proof)
    row["dimensions"]["numerical_behavior"] = _dimension("proven", proof)
    row["dimensions"]["java_lua"] = _dimension(
        "proven",
        "SVN 964 CharacterStat exposes ZOMBIE_INFECTION on a 0..100 domain; getApparentInfectionLevel is no longer called.",
    )
    row["dimensions"]["event_lifecycle"] = _dimension(
        "proven",
        "The minute callback removes its prior same-process registration before adding the current function; the new-game marker is idempotent.",
    )
    row["dimensions"]["description"] = _dimension(
        "proven",
        "English copy states the exact cadence, existing-infection condition, increase, and cap.",
    )
    row["dimensions"]["tests"] = _dimension(
        "proven",
        "Regression tests cover direct increase, cap, food-sickness isolation, zombie-fever isolation, marker creation, and reload idempotence.",
    )
    row["dimensions"]["mocks"] = _dimension(
        "proven",
        "The mock reproduces SVN 964 apparent-infection composition and separate CharacterStat channels, so the former cross-channel write fails the counterexamples.",
    )
    row["dimensions"]["source_release_parity"] = _dimension(
        "proven", "Assigned source and release runtime files are byte-identical."
    )
    row["overall_state"] = "runtime-unproven"
    finding = _exactly_one(row["findings"], "id", FINDING, relative)
    finding["resolution_state"] = "proven-correct"
    finding["resolution_evidence"] = (
        "The handler now derives zombie infection only from CharacterStat.ZOMBIE_INFECTION. "
        "Tests prove isolated food sickness cannot create infection and higher zombie fever "
        "cannot replace the underlying infection value."
    )
    finding["remaining_runtime_proof"] = (
        "Full Kahlua execution, current-version save/load, and rendered English remain unobserved."
    )
    row["unknowns"] = [
        "Full Kahlua execution and current-version save/load remain unobserved.",
        "Rendered English copy remains unobserved in game.",
        "No empirical balance telemetry exists.",
    ]
    row["validation"].update(
        runtime_checks_run=False,
        notes="Producer-faithful counterexamples, reload behavior, and source/release parity are statically validated; no deployment.",
    )
    replacements = {
        index: json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        for index, line in enumerate(lines)
        if json.loads(line).get("trait_id") == TRAIT
    }
    plan[relative] = (
        "\n".join(replacements.get(index, line) for index, line in enumerate(lines))
        + "\n"
    ).encode("utf-8")


def _plan_translation(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "translation_audit.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = _exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    description = row["english"]["description"]
    description.update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        translator_percent_mutates=False,
        dev_rejected_confusables=[],
        static_display_state="proven-correct",
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["rendered English not observed in game"]
    for source in (SOURCE_UI, RELEASE_UI):
        if _update_fingerprints(artifact, source, _metadata(root, source)) < 1:
            raise ValueError(f"{relative}: no fingerprint owner for {source}")
    plan[relative] = _json_bytes(artifact, compact=True)


def _plan_inventory(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, TESTS):
        _update_fingerprints(artifact, source, _metadata(root, source))
    plan[relative] = _json_bytes(artifact)


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    row = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["unresolved_proof"] = [
        "Full Kahlua execution and current-version save/load remain unobserved.",
        "Rendered English copy remains unobserved in game.",
        "No empirical balance telemetry exists.",
    ]
    row["release_parity"] = {
        "source_runtime_sha256": _metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": _metadata(root, RELEASE)["sha256"],
        "state": "proven-correct",
    }
    row["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "finding_id": FINDING,
        "producer_contract": "EveryOneMinute; direct CharacterStat.ZOMBIE_INFECTION only",
        "remaining_proof": "Current-build in-game execution after a full relaunch is unobserved.",
    }
    plan[relative] = _json_bytes(artifact)


def _plan_blocker(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    matches = [
        row for row in identities if row.get("semantic_identity") == BLOCKER_IDENTITY
    ]
    if len(matches) > 1:
        raise ValueError(
            f"{relative}: expected at most one {BLOCKER_IDENTITY}, found {len(matches)}"
        )
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY
    ]
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    plan[RESOLUTION] = _json_bytes(
        {
            "schema": "ut-immunocompromised-infection-channel-resolution-v1",
            "trait_id": TRAIT,
            "finding_id": FINDING,
            "authority": "pre-campaign UTMods master; upstream MoreTraits behavior is historical evidence only",
            "accepted_intent": {
                "cost": -6,
                "infection_increase": 1,
                "infection_cap": 100,
                "cadence": "every in-game minute",
                "infection_channel": "CharacterStat.ZOMBIE_INFECTION",
                "new_game_marker": "UT_immunocompromised=true",
                "scope": "single-player",
            },
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1664-1667",
                "PZCodebase/Java/source/zombie/characters/CharacterStat.java:35",
            ],
            "files": [
                _metadata(root, source)
                for source in (RUNTIME, RELEASE, SOURCE_UI, RELEASE_UI, TESTS)
            ],
            "counterexamples": [
                "food sickness above zero with zero zombie infection",
                "zombie fever above the underlying zombie infection",
                "zombie infection near the maximum",
                "same-process module reload",
            ],
            "preserved_surfaces": [
                "trait cost",
                "cadence",
                "infection increase and cap",
                "new-game marker",
                "registration",
                "grants and exclusions",
                "single-player scope",
            ],
            "static_validation": "Producer-faithful standard-Lua coverage, reload proof, and exact source/release parity.",
            "runtime_proof": "Unobserved; requires full Exit to Desktop and current-build in-game cadence and save/load checks.",
        }
    )


def _materialize(campaign: Path, plan: dict[str, bytes], overlay: Path) -> None:
    shutil.copytree(campaign, overlay, dirs_exist_ok=True)
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(
        prefix="regenerate-immunocompromised-plan-"
    ) as directory:
        overlay = Path(directory) / "campaign"
        _materialize(campaign, plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay)
        plan.update(
            {
                "final_trait_ledger.json": render_ledger(ledger).encode("utf-8"),
                "final_trait_ledger_rows.jsonl": render_trait_rows(ledger).encode(
                    "utf-8"
                ),
                "dimension_ledger_rows.jsonl": dimensions.encode("utf-8"),
                "remediation_queue.jsonl": queue.encode("utf-8"),
                "remediation_summary.json": summary.encode("utf-8"),
            }
        )
        _materialize(campaign, plan, overlay)
        update_release_blocker_queue_sha256(
            overlay / "remediation_queue.jsonl", overlay / "release_blocker_queue.json"
        )
        plan["release_blocker_queue.json"] = (
            overlay / "release_blocker_queue.json"
        ).read_bytes()
        _materialize(campaign, plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode(
            "utf-8"
        )


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    plan: dict[str, bytes] = {}
    _plan_batch(campaign, plan)
    _plan_translation(root, campaign, plan)
    _plan_inventory(root, campaign, plan)
    _plan_review(root, campaign, plan)
    _plan_blocker(campaign, plan)
    _plan_resolution(root, plan)
    _plan_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Immunocompromised output plan escaped its ownership set")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Immunocompromised output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file()
        or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = Path(
        tempfile.mkdtemp(prefix=".regenerate-immunocompromised-", dir=campaign)
    )
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
    cli_result = no_arg_command(
        sys.argv, "Usage: py -3 regenerate_immunocompromised.py"
    )
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
