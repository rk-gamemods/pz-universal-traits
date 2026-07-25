"""Truthful status accounting and the bounded single-player release profile."""

from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any

from .catalog import build_catalog
from .paths import (
    FINAL_LEDGER_ROWS_PATH,
    RELEASE_BLOCKER_PATH,
    RELEASE_PROFILE_PATH,
    REMEDIATION_QUEUE_PATH,
    REMEDIATION_SUMMARY_PATH,
    SOURCE_INVENTORY_PATH,
    TRANSLATION_AUDIT_PATH,
    UTMODS_ROOT,
)


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain one JSON object")
    return value


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{number} is not a JSON object")
        rows.append(value)
    return rows


def _git_head(root: Path) -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=10,
        check=False,
    )
    if completed.returncode != 0:
        raise ValueError(completed.stderr.strip() or "git rev-parse failed")
    return completed.stdout.strip()


def _git_quiet(root: Path, arguments: list[str]) -> int:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=10,
        check=False,
    )
    return completed.returncode


def _git_provenance(root: Path, inventory_head: str) -> dict[str, Any]:
    current_head = _git_head(root)
    with tempfile.TemporaryFile() as output:
        status = subprocess.run(
            ["git", "status", "--porcelain=v1", "--untracked-files=normal"],
            cwd=root,
            stdout=output,
            stderr=subprocess.DEVNULL,
            timeout=10,
            check=False,
        )
        output.seek(0)
        dirty = bool(output.read(1))

    ancestor_exit = _git_quiet(
        root, ["merge-base", "--is-ancestor", inventory_head, current_head]
    )
    source_diff_exit = (
        _git_quiet(
            root,
            [
                "diff",
                "--quiet",
                "--exit-code",
                f"{inventory_head}..{current_head}",
                "--",
                "UniversalTraits/media",
                "UT_CORE/media",
            ],
        )
        if ancestor_exit == 0
        else 2
    )
    return {
        "current_head": current_head,
        "worktree_clean": status.returncode == 0 and not dirty,
        "status_exit": status.returncode,
        "inventory_is_ancestor": ancestor_exit == 0,
        "ancestor_exit": ancestor_exit,
        "source_unchanged": source_diff_exit == 0,
        "source_diff_exit": source_diff_exit,
    }


def build_status(root: Path = UTMODS_ROOT) -> dict[str, Any]:
    campaign = root / "trait-deep-audit/campaign"
    ledger_rows = _load_jsonl(campaign / FINAL_LEDGER_ROWS_PATH.name)
    queue_path = campaign / REMEDIATION_QUEUE_PATH.name
    queue_rows = _load_jsonl(queue_path)
    summary = _load_json(campaign / REMEDIATION_SUMMARY_PATH.name)
    blockers = _load_json(campaign / RELEASE_BLOCKER_PATH.name)
    profile = _load_json(campaign / RELEASE_PROFILE_PATH.name)
    source_inventory = _load_json(campaign / SOURCE_INVENTORY_PATH.name)
    translation = _load_json(campaign / TRANSLATION_AUDIT_PATH.name)
    catalog = build_catalog(root)

    trait_states = Counter(str(row.get("overall_state")) for row in ledger_rows)
    queue_states = Counter(str(row.get("state")) for row in queue_rows)
    queue_stages = Counter(str(row.get("stage")) for row in queue_rows)
    queue_by_id: dict[str, list[dict[str, Any]]] = {}
    for row in queue_rows:
        queue_id = row.get("queue_id")
        if isinstance(queue_id, str):
            queue_by_id.setdefault(queue_id, []).append(row)

    identities = blockers.get("identities", [])
    identity_ids = {
        identity.get("semantic_identity")
        for identity in identities
        if isinstance(identity.get("semantic_identity"), str)
    }
    gate_checks: list[dict[str, Any]] = []

    def check(check_id: str, passed: bool, detail: str) -> None:
        gate_checks.append({"id": check_id, "passed": passed, "detail": detail})

    inventory_head = (
        source_inventory.get("repo_identity", {}).get("git_head", "")
    )
    provenance = _git_provenance(root, inventory_head)
    check(
        "git-worktree-clean",
        provenance["worktree_clean"],
        f"status_exit={provenance['status_exit']}",
    )
    check(
        "source-inventory-ancestor",
        provenance["inventory_is_ancestor"],
        (
            f"inventory={inventory_head or 'missing'} "
            f"current={provenance['current_head']} "
            f"exit={provenance['ancestor_exit']}"
        ),
    )
    check(
        "source-inventory-source-unchanged",
        provenance["source_unchanged"],
        (
            "paths=['UniversalTraits/media','UT_CORE/media'] "
            f"exit={provenance['source_diff_exit']}"
        ),
    )
    check(
        "catalog-integrity",
        not catalog["integrity_errors"],
        f"errors={len(catalog['integrity_errors'])}",
    )
    recorded_queue_count = (
        summary.get("counts", {}).get("open_queue_records")
    )
    check(
        "summary-queue-count",
        recorded_queue_count == len(queue_rows),
        f"summary={recorded_queue_count} rows={len(queue_rows)}",
    )
    expected_queue_digest = blockers.get("remediation_queue_sha256")
    actual_queue_digest = hashlib.sha256(queue_path.read_bytes()).hexdigest()
    check(
        "release-blocker-queue-digest",
        expected_queue_digest == actual_queue_digest,
        f"recorded={expected_queue_digest} actual={actual_queue_digest}",
    )
    blocker_references = [
        queue_id
        for identity in identities
        for queue_id in identity.get("queue_ids", [])
        if isinstance(queue_id, str)
    ]
    missing_or_duplicate = sorted(
        queue_id
        for queue_id in blocker_references
        if len(queue_by_id.get(queue_id, [])) != 1
    )
    check(
        "release-blocker-live-rows",
        not missing_or_duplicate,
        f"invalid_queue_ids={missing_or_duplicate}",
    )
    dangling_dependencies = sorted(
        {
            dependency
            for identity in identities
            for dependency in identity.get("dependencies", [])
            if dependency not in identity_ids
        }
    )
    check(
        "release-blocker-dependencies",
        not dangling_dependencies,
        f"dangling={dangling_dependencies}",
    )
    open_identities = sorted(
        identity.get("semantic_identity")
        for identity in identities
        if identity.get("status") != "closed"
    )
    check(
        "release-blockers-closed",
        not open_identities,
        f"open={open_identities}",
    )
    classification_complete = bool(profile.get("classification_complete"))
    check(
        "normal-play-classification-complete",
        classification_complete,
        f"classification_complete={classification_complete}",
    )
    translation_rows = translation.get("per_trait_ledger", [])
    check(
        "translation-trait-coverage",
        len(translation_rows) == len(ledger_rows),
        f"translations={len(translation_rows)} traits={len(ledger_rows)}",
    )

    return {
        "schema_version": "utmods.workflow_status.v1",
        "profile": profile.get("profile_id"),
        "release_ready": all(item["passed"] for item in gate_checks),
        "counts": {
            "traits": len(ledger_rows),
            "trait_states": dict(sorted(trait_states.items())),
            "open_queue_records": len(queue_rows),
            "open_queue_states": dict(sorted(queue_states.items())),
            "open_queue_stages": dict(sorted(queue_stages.items())),
            "release_blocker_identities": len(identities),
            "catalog_rows": catalog["counts"]["rows"],
            "catalog_integrity_errors": catalog["counts"]["integrity_errors"],
        },
        "gate_checks": gate_checks,
        "catalog_integrity_errors": catalog["integrity_errors"],
        "notes": {
            "exhaustive_completion": (
                "The exhaustive audit completes only when all non-approved "
                "evidence obligations are proven-correct."
            ),
            "release_readiness": (
                "Release readiness is a narrower supported-profile gate. It does "
                "not erase or relabel the exhaustive backlog."
            ),
        },
    }
