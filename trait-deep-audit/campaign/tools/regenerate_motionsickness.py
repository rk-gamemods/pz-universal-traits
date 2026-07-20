"""Regenerate only Motion Sickness-owned campaign evidence and derived ledgers."""
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
from check_recurring_patterns import build_report, render_report


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_motionsickness"
STALE_FINDING = "IR0508-OM-012"
OPEN_FINDING = "UT6-MOTION-DESC"
BLOCKER_IDENTITY = "trait:UT_motionsickness"
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua"
OWNED_OUTPUTS = (
    "trait_batches/batch_06.jsonl",
    "independent_reviews/traits_05_08.json",
    "release_blocker_queue.json",
    "change-impact/motionsickness-stale-runtime-finding-resolution.json",
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "recurring_pattern_findings.json",
    "campaign_manifest.json",
)
TRANSACTION_NAME = ".regenerate_motionsickness-transaction"
JOURNAL_VERSION = 1


def _json_bytes(value: object, *, compact: bool = False) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=None if compact else 2,
        separators=(",", ":") if compact else None,
    )
    return (text + "\n").encode("utf-8")


def _digest(data: bytes) -> dict[str, object]:
    return {"sha256": hashlib.sha256(data).hexdigest().upper(), "bytes": len(data)}


def _write_durable(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())


def _journal_path(campaign: Path) -> Path:
    return campaign / TRANSACTION_NAME / "journal.json"


def _load_journal(campaign: Path) -> tuple[Path, dict[str, Any]] | None:
    transaction = campaign / TRANSACTION_NAME
    if not transaction.exists():
        return None
    journal_path = transaction / "journal.json"
    try:
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RuntimeError(
            f"Motion Sickness recovery required; retained transaction at {transaction}: malformed journal ({error})"
        ) from error
    expected_campaign = str(campaign.resolve())
    if (
        not isinstance(journal, dict)
        or journal.get("version") != JOURNAL_VERSION
        or journal.get("campaign") != expected_campaign
        or journal.get("owned_outputs") != list(OWNED_OUTPUTS)
        or not isinstance(journal.get("entries"), list)
    ):
        raise RuntimeError(
            f"Motion Sickness recovery required; retained transaction at {transaction}: foreign or unsupported journal"
        )
    entries = journal["entries"]
    if [entry.get("path") for entry in entries if isinstance(entry, dict)] != journal.get("changed"):
        raise RuntimeError(
            f"Motion Sickness recovery required; retained transaction at {transaction}: journal entry mismatch"
        )
    if not isinstance(journal.get("changed"), list) or not set(journal["changed"]).issubset(OWNED_OUTPUTS):
        raise RuntimeError(
            f"Motion Sickness recovery required; retained transaction at {transaction}: ownership mismatch"
        )
    for entry in entries:
        relative = entry.get("path") if isinstance(entry, dict) else None
        if (
            not isinstance(relative, str)
            or Path(relative).is_absolute()
            or ".." in Path(relative).parts
            or relative not in OWNED_OUTPUTS
            or not isinstance(entry.get("staged"), dict)
            or not isinstance(entry.get("preimage"), dict)
            or entry["preimage"].get("exists") not in (True, False)
        ):
            raise RuntimeError(
                f"Motion Sickness recovery required; retained transaction at {transaction}: unsafe journal path or metadata"
            )
    return transaction, journal


def _matches(path: Path, metadata: dict[str, object]) -> bool:
    if not path.is_file():
        return False
    return _digest(path.read_bytes()) == {
        "sha256": metadata.get("sha256"),
        "bytes": metadata.get("bytes"),
    }


def recover_transaction(
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> bool:
    loaded = _load_journal(campaign)
    if loaded is None:
        return False
    transaction, journal = loaded
    try:
        for entry in reversed(journal["entries"]):
            relative = entry["path"]
            destination = campaign / relative
            staged_meta = entry["staged"]
            preimage = entry["preimage"]
            destination_is_staged = _matches(destination, staged_meta)
            if preimage["exists"]:
                if _matches(destination, preimage):
                    continue
                backup = transaction / "backups" / relative
                if not _matches(backup, preimage):
                    raise RuntimeError(f"backup integrity mismatch for {relative}")
                if not destination_is_staged:
                    raise RuntimeError(f"destination is neither staged nor preimage for {relative}")
                rollback = transaction / "rollback" / relative
                _write_durable(rollback, backup.read_bytes())
                replace(rollback, destination)
                if not _matches(destination, preimage):
                    raise RuntimeError(f"rollback verification failed for {relative}")
            else:
                if not destination.exists():
                    continue
                if not destination_is_staged:
                    raise RuntimeError(f"foreign destination blocks rollback for {relative}")
                destination.unlink()
                if destination.exists():
                    raise RuntimeError(f"rollback deletion failed for {relative}")
    except BaseException as error:
        raise RuntimeError(
            f"Motion Sickness recovery required; retained transaction at {transaction}: {error}"
        ) from error
    shutil.rmtree(transaction)
    return True


def _metadata(root: Path, relative: str) -> dict[str, object]:
    data = (root / relative).read_bytes()
    return {
        "path": relative,
        "sha256": hashlib.sha256(data).hexdigest().upper(),
        "bytes": len(data),
    }


def _exactly_one(rows: list[dict[str, Any]], key: str, value: str, owner: str) -> dict[str, Any]:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner}: expected one {key}={value}, found {len(matches)}")
    return matches[0]


def _dimension(state: str, evidence: str, missing_proof: str | list[str] = "none") -> dict[str, object]:
    return {"state": state, "evidence": evidence, "missing_proof": missing_proof}


def _plan_batch(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_06.jsonl"
    lines = (campaign / relative).read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    finding = _exactly_one(row.get("findings", []), "id", OPEN_FINDING, f"{relative} Motion Sickness finding")
    if finding.get("resolution_state") not in (None, "confirmed-defect"):
        raise ValueError(f"{relative}: {OPEN_FINDING} must remain unresolved")

    row["overall_state"] = "confirmed-defect"
    dimensions = row["dimensions"]
    runtime_evidence = (
        "Current source and release register the central tick handler with vehicleAware=true and throttle=60; "
        "the handler adds exactly 0.01 STRESS while tick.vehicle is non-nil and caps at 1."
    )
    dimensions["runtime_shared_script_only_path"] = _dimension("proven", runtime_evidence)
    dimensions["cadence"] = _dimension("proven", runtime_evidence)
    dimensions["event_lifecycle"] = _dimension("proven", runtime_evidence)
    dimensions["tests_mocks"] = _dimension(
        "proven",
        "The current standard-Lua suite covers the dispatcher-backed Motion Sickness path; this is mock evidence only.",
    )
    for name in ("java_lua", "kahlua", "reset_save_load"):
        dimensions[name] = _dimension(
            "runtime-unproven",
            "Static source and standard-Lua tests support the dispatcher-backed path without establishing current-game execution.",
            "Current Build 42 in-game execution after a full exit/relaunch and save/load remains unobserved.",
        )
    dimensions["multiplayer"] = _dimension(
        "not-applicable",
        "Explicit non-goal: UTMods is single-player-only and the trait definition is disabled in multiplayer.",
        "none",
    )
    row["unknowns"] = [
        "Current Build 42 in-game/Kahlua and save/load execution remain unobserved.",
        "Rendered UI, non-EN locale behavior, and balance/profiler evidence remain unobserved.",
        "Multiplayer support, synchronization, migration, proof, and tests are explicit non-goals under the controlling UTMods scope.",
    ]
    row["validation"] = {
        **row.get("validation", {}),
        "evidence_mode": "current source/release inspection plus standard-Lua tests; no in-game proof claimed",
        "runtime_checks_unrun": ["game launch", "save-load"],
        "explicit_non_goals": ["multiplayer support", "multiplayer synchronization", "multiplayer migration", "multiplayer proof/tests"],
    }
    replacements = {
        index: json.dumps(row, ensure_ascii=False, separators=(",", ":"))
        for index, parsed in enumerate(rows)
        if parsed.get("trait_id") == TRAIT
    }
    plan[relative] = ("\n".join(replacements.get(index, line) for index, line in enumerate(lines)) + "\n").encode("utf-8")


def _plan_review(root: Path, campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_05_08.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    trait = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    omission = _exactly_one(trait.get("omissions", []), "id", STALE_FINDING, f"{relative} omissions")
    omission.update(
        {
            "state": "proven-correct",
            "resolution_state": "closed-stale-finding",
            "resolution_evidence": (
                "Current source and release no longer call GameTime.getTicks; both use the central tick dispatcher "
                "with vehicleAware=true and throttle=60. The prior invalid-runtime-api premise is stale."
            ),
            "missing_proof": "Current Build 42 in-game/Kahlua and save/load execution remain unobserved.",
            "recommended_correction": "No runtime correction in this reconciliation; retain current dispatcher-backed implementation.",
            "smallest_regression_test": "Keep the existing dispatcher-backed Motion Sickness standard-Lua coverage and run current-game proof separately.",
        }
    )
    trait["review_state"] = "accepted"
    trait["unresolved_proof"] = [
        "Current Build 42 in-game/Kahlua and save/load execution remain unobserved.",
        "Rendered UI, non-EN locale behavior, and balance/profiler evidence remain unobserved.",
        "Multiplayer is an explicit non-goal under the controlling single-player-only UTMods scope.",
    ]
    trait["explicit_non_goals"] = {
        "multiplayer": "support, synchronization, migration, proof, tests, and documentation are out of scope"
    }
    trait["release_parity"] = {
        "source_runtime_sha256": _metadata(root, RUNTIME)["sha256"],
        "release_runtime_sha256": _metadata(root, RELEASE)["sha256"],
        "state": "proven-correct",
    }
    trait["resolution_record"] = "change-impact/motionsickness-stale-runtime-finding-resolution.json"
    plan[relative] = _json_bytes(artifact)


def _plan_blockers(campaign: Path, plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = json.loads((campaign / relative).read_text(encoding="utf-8"))
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    matches = [row for row in identities if row.get("semantic_identity") == BLOCKER_IDENTITY]
    if len(matches) > 1:
        raise ValueError(f"{relative}: expected at most one {BLOCKER_IDENTITY}, found {len(matches)}")
    if matches and (
        matches[0].get("priority_reason_code") != "invalid-runtime-api"
        or matches[0].get("queue_ids") != [f"finding:{STALE_FINDING}"]
    ):
        raise ValueError(f"{relative}: unexpected {BLOCKER_IDENTITY} ownership")
    artifact["identities"] = [row for row in identities if row.get("semantic_identity") != BLOCKER_IDENTITY]
    dependency_matches = 0
    for identity in artifact["identities"]:
        dependencies = identity.get("dependencies")
        if not isinstance(dependencies, list):
            raise ValueError(f"{relative}: dependencies must be lists")
        dependency_matches += dependencies.count(BLOCKER_IDENTITY)
        identity["dependencies"] = [item for item in dependencies if item != BLOCKER_IDENTITY]
    if dependency_matches > 1:
        raise ValueError(f"{relative}: expected at most one dependency on {BLOCKER_IDENTITY}, found {dependency_matches}")
    package_identity = _exactly_one(
        artifact["identities"],
        "semantic_identity",
        "package:UniversalTraits-release-reconciliation",
        relative,
    )
    stale_pattern_queue_id = "finding:RP-PACKAGE-PARITY-UniversalTraits"
    if package_identity.get("queue_ids", []).count(stale_pattern_queue_id) > 1:
        raise ValueError(f"{relative}: duplicate {stale_pattern_queue_id}")
    package_identity["queue_ids"] = [
        item for item in package_identity.get("queue_ids", []) if item != stale_pattern_queue_id
    ]
    plan[relative] = _json_bytes(artifact)


def _plan_resolution(root: Path, plan: dict[str, bytes]) -> None:
    relative = "change-impact/motionsickness-stale-runtime-finding-resolution.json"
    plan[relative] = _json_bytes(
        {
            "schema": "ut-motionsickness-stale-runtime-finding-resolution-v1",
            "trait_id": TRAIT,
            "closed_finding_id": STALE_FINDING,
            "preserved_finding_id": OPEN_FINDING,
            "resolution": {
                "state": "closed-stale-finding",
                "reason": "The reviewed invalid GameTime.getTicks call is absent from current source and release runtime.",
                "current_contract": "central tick dispatcher; vehicleAware=true; throttle=60; +0.01 STRESS while in a vehicle; cap 1",
                "semantic_change": "none",
            },
            "files": [_metadata(root, path) for path in (RUNTIME, RELEASE)],
            "preserved_uncertainty": {
                "description_display_localization": OPEN_FINDING,
                "runtime_unproven_dimensions": ["java_lua", "kahlua", "reset_save_load"],
                "in_game_proof": "not claimed; current Build 42 execution after full exit/relaunch and save/load remains unobserved",
            },
            "explicit_non_goals": {
                "multiplayer": "UTMods is single-player-only; multiplayer support, synchronization, migration, proof, tests, and documentation are out of scope"
            },
        }
    )


def _materialize(campaign: Path, plan: dict[str, bytes], overlay: Path) -> None:
    shutil.copytree(campaign, overlay, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _plan_derived(campaign: Path, plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix="regenerate_motionsickness-plan-") as directory:
        overlay = Path(directory) / "campaign"
        plan["recurring_pattern_findings.json"] = render_report(build_report()).encode("utf-8")
        _materialize(campaign, plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay)
        plan.update(
            {
                "final_trait_ledger.json": render_ledger(ledger).encode("utf-8"),
                "final_trait_ledger_rows.jsonl": render_trait_rows(ledger).encode("utf-8"),
                "dimension_ledger_rows.jsonl": dimensions.encode("utf-8"),
                "remediation_queue.jsonl": queue.encode("utf-8"),
                "remediation_summary.json": summary.encode("utf-8"),
            }
        )
        _materialize(campaign, plan, overlay)
        update_release_blocker_queue_sha256(overlay / "remediation_queue.jsonl", overlay / "release_blocker_queue.json")
        plan["release_blocker_queue.json"] = (overlay / "release_blocker_queue.json").read_bytes()
        _materialize(campaign, plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode("utf-8")


def build_plan(root: Path = ROOT, campaign: Path = CAMPAIGN) -> dict[str, bytes]:
    recover_transaction(campaign)
    plan: dict[str, bytes] = {}
    _plan_batch(campaign, plan)
    _plan_review(root, campaign, plan)
    _plan_blockers(campaign, plan)
    _plan_resolution(root, plan)
    _plan_derived(campaign, plan)
    if set(plan) != set(OWNED_OUTPUTS):
        raise RuntimeError("Motion Sickness output plan escaped its exact ownership set")
    missing = [relative for relative in OWNED_OUTPUTS if relative not in plan]
    if missing:
        raise ValueError(f"missing planned Motion Sickness outputs: {missing}")
    for relative in OWNED_OUTPUTS:
        if relative.startswith("change-impact/"):
            continue
        if not (campaign / relative).is_file():
            raise ValueError(f"required owned output is missing: {relative}")
    return plan


def commit_plan(
    plan: dict[str, bytes],
    campaign: Path = CAMPAIGN,
    replace: Callable[[str | Path, str | Path], None] = os.replace,
) -> list[str]:
    recover_transaction(campaign, replace=replace)
    if set(plan) != set(OWNED_OUTPUTS):
        raise ValueError("refusing a non-canonical Motion Sickness output set")
    changed = [
        relative
        for relative in OWNED_OUTPUTS
        if not (campaign / relative).is_file() or (campaign / relative).read_bytes() != plan[relative]
    ]
    if not changed:
        return []
    transaction = campaign / TRANSACTION_NAME
    transaction.mkdir()
    staged = transaction / "staged"
    backups = transaction / "backups"
    try:
        entries = []
        for relative in changed:
            stage = staged / relative
            _write_durable(stage, plan[relative])
            current = campaign / relative
            if current.is_file():
                backup = backups / relative
                preimage_data = current.read_bytes()
                _write_durable(backup, preimage_data)
                preimage = {"exists": True, **_digest(preimage_data)}
            else:
                preimage = {"exists": False}
            entries.append({"path": relative, "preimage": preimage, "staged": _digest(plan[relative])})
        for entry in entries:
            if not _matches(staged / entry["path"], entry["staged"]):
                raise RuntimeError(f"staged content verification failed for {entry['path']}")
        journal = {
            "version": JOURNAL_VERSION,
            "campaign": str(campaign.resolve()),
            "owned_outputs": list(OWNED_OUTPUTS),
            "changed": changed,
            "entries": entries,
        }
        _write_durable(transaction / "journal.tmp", _json_bytes(journal))
        os.replace(transaction / "journal.tmp", transaction / "journal.json")
        for relative in changed:
            destination = campaign / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            replace(staged / relative, destination)
        for entry in entries:
            if not _matches(campaign / entry["path"], entry["staged"]):
                raise RuntimeError(f"promotion verification failed for {entry['path']}")
        shutil.rmtree(transaction)
        return changed
    except Exception:
        if (transaction / "journal.json").is_file():
            recover_transaction(campaign, replace=replace)
        elif transaction.exists():
            shutil.rmtree(transaction)
        raise


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_motionsickness.py")
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
