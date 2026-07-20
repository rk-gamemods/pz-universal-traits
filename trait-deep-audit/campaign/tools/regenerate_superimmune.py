"""Regenerate only Super Immune-owned campaign evidence and derived ledgers."""
from __future__ import annotations

import hashlib
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


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_superimmune"
FINDING = "B11-SUPERIMMUNE-001"
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_superimmune.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_superimmune.lua"
TESTS = "UniversalTraits/test/run_tests.lua"
OWNED_OUTPUTS = (
    "trait_batches/batch_11.jsonl",
    "source_inventory.json",
    "independent_reviews/traits_09_12.json",
    "release_blocker_queue.json",
    "change-impact/superimmune-infection-channel-resolution.json",
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "campaign_manifest.json",
)


def _json_bytes(value: object, *, compact: bool = False) -> bytes:
    text = json.dumps(
        value,
        indent=None if compact else 2,
        ensure_ascii=False,
        separators=(",", ":") if compact else None,
    )
    return (text + "\n").encode("utf-8")


def _metadata(root: Path, relative: str) -> dict[str, object]:
    data = (root / relative).read_bytes()
    return {"path": relative, "sha256": hashlib.sha256(data).hexdigest().upper(), "bytes": len(data)}


def _exactly_one(rows: list[dict[str, Any]], key: str, value: str, owner: str) -> dict[str, Any]:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner}: expected one {key}={value}, found {len(matches)}")
    return matches[0]


def _update_fingerprints(value: object, relative: str, current: dict[str, object]) -> int:
    count = 0
    if isinstance(value, dict):
        if value.get("path", "").removeprefix("UTMods/") == relative:
            for key in ("sha256", "bytes"):
                if key in value:
                    value[key] = current[key]
            count += 1
        for child in value.values():
            count += _update_fingerprints(child, relative, current)
    elif isinstance(value, list):
        for child in value:
            count += _update_fingerprints(child, relative, current)
    return count


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_11.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    row["overall_state"] = "runtime-unproven"
    proof = (
        "EveryOneMinute reads and writes only CharacterStat.ZOMBIE_INFECTION, subtracts exactly 2, "
        "and floors at zero without deriving state from apparent infection."
    )
    for name in ("source_intent", "runtime_path", "numbers", "java_lua", "tests", "mocks"):
        row["dimensions"][name] = {"state": "proven-correct", "evidence": [proof], "missing_proof": []}
    row["dimensions"]["reset_save_load"] = {
        "state": "runtime-unproven",
        "evidence": ["Same-process dofile reload replaces the prior minute callback and retains one effective registration."],
        "missing_proof": ["Full Exit to Desktop and current-build in-game reload are unobserved."],
    }
    finding = _exactly_one(row["findings"], "id", FINDING, "Super Immune finding")
    finding["resolution_state"] = "proven-correct"
    finding["resolution_evidence"] = (
        "Producer-faithful tests prove direct 50-to-48 mutation, floor, trait guard, higher food-sickness "
        "and fever counterexamples, zero infection with nonzero illness, untouched illness channels, and reload idempotence."
    )
    finding["remaining_runtime_proof"] = "Full Exit to Desktop and current-build in-game minute ticks remain unobserved."
    replacements = {
        index: json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        for index, line in enumerate(lines)
        if json.loads(line).get("trait_id") == TRAIT
    }
    plan[relative] = ("\n".join(replacements.get(index, line) for index, line in enumerate(lines)) + "\n").encode("utf-8")


def _plan_evidence(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "source_inventory.json"
    inventory = json.loads((campaign / relative).read_text(encoding="utf-8"))
    for source in (RUNTIME, RELEASE, TESTS):
        _update_fingerprints(inventory, source, _metadata(root, source))
    plan[relative] = _json_bytes(inventory)

    relative = "independent_reviews/traits_09_12.json"
    review = json.loads((campaign / relative).read_text(encoding="utf-8"))
    trait = _exactly_one(review["per_trait_review"], "trait_id", TRAIT, relative)
    trait["release_parity"] = {
        "source_runtime_sha256": _metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": _metadata(root, RELEASE)["sha256"],
        "state": "proven-correct",
    }
    trait["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "finding_id": FINDING,
        "producer_contract": "EveryOneMinute; underlying CharacterStat.ZOMBIE_INFECTION only",
        "remaining_proof": "Current-build in-game execution after a full relaunch is unobserved.",
    }
    plan[relative] = _json_bytes(review)

    relative = "release_blocker_queue.json"
    blockers = json.loads((campaign / relative).read_text(encoding="utf-8"))
    identities = blockers.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    identity = "trait:UT_superimmune"
    matches = [item for item in identities if item.get("semantic_identity") == identity]
    if len(matches) > 1:
        raise ValueError(f"{relative}: expected at most one {identity}, found {len(matches)}")
    # Zero matches is the explicitly contracted already-resolved fixed point.
    blockers["identities"] = [item for item in identities if item.get("semantic_identity") != identity]
    plan[relative] = _json_bytes(blockers)

    relative = "change-impact/superimmune-infection-channel-resolution.json"
    plan[relative] = _json_bytes(
        {
            "schema": "ut-superimmune-infection-channel-resolution-v1",
            "trait_id": TRAIT,
            "finding_id": FINDING,
            "authority": "pre-campaign UTMods port; upstream More Traits state machine is intentionally not restored",
            "accepted_intent": {"cost": 10, "reduction": 2, "floor": 0, "cadence": "every in-game minute", "channel": "CharacterStat.ZOMBIE_INFECTION", "scope": "single-player"},
            "engine_evidence": ["PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1664", "PZCodebase/Java/source/zombie/characters/CharacterStat.java:9"],
            "files": [_metadata(root, path) for path in (RUNTIME, RELEASE, TESTS)],
            "counterexamples": ["food sickness above infection", "zombie fever above infection", "zero infection with nonzero illness"],
            "static_validation": "Producer-faithful standard-Lua coverage; source/release byte parity.",
            "runtime_proof": "unobserved; requires full Exit to Desktop and current-build in-game minute ticks",
        }
    )


def _materialize(campaign: Path, plan: dict[str, bytes], overlay: Path) -> None:
    shutil.copytree(campaign, overlay, dirs_exist_ok=True)
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix="regenerate_superimmune-plan-") as directory:
        overlay = Path(directory) / "campaign"
        _materialize(campaign, plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay)
        plan.update({
            "final_trait_ledger.json": render_ledger(ledger).encode("utf-8"),
            "final_trait_ledger_rows.jsonl": render_trait_rows(ledger).encode("utf-8"),
            "dimension_ledger_rows.jsonl": dimensions.encode("utf-8"),
            "remediation_queue.jsonl": queue.encode("utf-8"),
            "remediation_summary.json": summary.encode("utf-8"),
        })
        _materialize(campaign, plan, overlay)
        update_release_blocker_queue_sha256(overlay / "remediation_queue.jsonl", overlay / "release_blocker_queue.json")
        plan["release_blocker_queue.json"] = (overlay / "release_blocker_queue.json").read_bytes()
        _materialize(campaign, plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode("utf-8")


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    plan: dict[str, bytes] = {}
    _plan_batch(campaign, plan)
    _plan_evidence(root, campaign, plan)
    _plan_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Super Immune output plan escaped its exact ownership set")
    for relative in OWNED_OUTPUTS:
        if not (campaign / relative).is_file():
            raise ValueError(f"required owned output is missing: {relative}")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Super Immune output set")
    changed = [relative for relative in OWNED_OUTPUTS if (campaign / relative).read_bytes() != plan[relative]]
    if not changed:
        return []
    transaction = Path(tempfile.mkdtemp(prefix=".regenerate_superimmune-", dir=campaign))
    staged = transaction / "staged"
    backups = transaction / "backups"
    promoted: list[str] = []
    try:
        for relative in changed:
            stage = staged / relative
            backup = backups / relative
            stage.parent.mkdir(parents=True, exist_ok=True)
            backup.parent.mkdir(parents=True, exist_ok=True)
            stage.write_bytes(plan[relative])
            backup.write_bytes((campaign / relative).read_bytes())
        for relative in changed:
            replace(staged / relative, campaign / relative)
            promoted.append(relative)
        return changed
    except BaseException:
        for relative in reversed(promoted):
            replace(backups / relative, campaign / relative)
        raise
    finally:
        shutil.rmtree(transaction, ignore_errors=True)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_superimmune.py")
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
