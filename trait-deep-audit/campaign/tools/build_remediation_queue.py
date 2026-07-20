"""Build queryable dimension rows and the deterministic remediation queue."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any

from campaign_cli import no_arg_command
from build_final_trait_ledger import (
    CAMPAIGN_ROOT,
    CANONICAL_DIMENSIONS,
    TERMINAL_STATES,
    build_ledger,
    normalize_state,
)
from check_recurring_patterns import build_report


DIMENSION_OUTPUT_PATH = CAMPAIGN_ROOT / "dimension_ledger_rows.jsonl"
QUEUE_OUTPUT_PATH = CAMPAIGN_ROOT / "remediation_queue.jsonl"
SUMMARY_OUTPUT_PATH = CAMPAIGN_ROOT / "remediation_summary.json"

OPEN_STATES = frozenset({"confirmed-defect", "coverage-gap", "runtime-unproven"})
STATE_ORDER = {"confirmed-defect": 0, "coverage-gap": 1, "runtime-unproven": 2}
SEVERITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3, "not-applicable": 4}

STAGE_DIMENSIONS = {
    "inventory-contract": (
        "registration",
        "definition_parser",
        "namespace",
        "cost_xp_grants_exclusions",
        "source_intent",
    ),
    "product-semantics": ("runtime_path", "numbers", "cadence", "cooldown"),
    "runtime-contract": (
        "reset_save_load",
        "java_lua",
        "kahlua",
        "events",
        "stacking_interactions",
        "multiplayer",
    ),
    "player-facing": ("display", "description", "localization", "balance"),
    "validation": ("performance", "tests", "mocks"),
    "packaging": ("source_release_parity", "packaging"),
}
STAGE_ORDER = {stage: index for index, stage in enumerate(STAGE_DIMENSIONS)}
DIMENSION_STAGE = {
    dimension: stage
    for stage, dimensions in STAGE_DIMENSIONS.items()
    for dimension in dimensions
}

DIMENSION_DEPENDENCIES = {
    "definition_parser": ("registration",),
    "namespace": ("registration", "definition_parser"),
    "source_intent": ("registration", "definition_parser", "namespace"),
    "cost_xp_grants_exclusions": ("registration", "definition_parser", "namespace"),
    "runtime_path": ("registration", "definition_parser", "namespace", "source_intent"),
    "numbers": ("runtime_path",),
    "cadence": ("runtime_path",),
    "cooldown": ("runtime_path", "cadence"),
    "reset_save_load": ("runtime_path", "cooldown"),
    "java_lua": ("runtime_path",),
    "kahlua": ("runtime_path", "java_lua"),
    "events": ("runtime_path", "java_lua", "kahlua"),
    "stacking_interactions": ("runtime_path", "numbers", "events"),
    "multiplayer": ("runtime_path", "events", "reset_save_load"),
    "display": ("registration", "namespace"),
    "description": ("runtime_path", "numbers", "cadence", "cooldown"),
    "localization": ("display", "description"),
    "balance": ("runtime_path", "numbers", "cadence", "cooldown", "stacking_interactions"),
    "performance": ("runtime_path", "cadence", "events"),
    "tests": ("runtime_path", "numbers", "cadence", "cooldown", "events"),
    "mocks": ("java_lua", "kahlua", "events", "tests"),
    "source_release_parity": (
        "registration",
        "definition_parser",
        "runtime_path",
        "description",
        "localization",
        "tests",
    ),
    "packaging": ("source_release_parity",),
}

QUEUE_COLUMNS = (
    "queue_id",
    "subject_type",
    "status",
    "validation_mode",
    "depends_on",
    "trait_id",
    "batch",
    "dimension",
    "stage",
    "state",
    "evidence",
    "missing_proof",
    "source_dimensions",
    "finding_ids",
    "translation_terminal_state",
    "finding_id",
    "severity",
    "confidence",
    "title",
    "anchors",
    "affected_surfaces",
    "reproduction_evidence",
    "recommended_correction",
    "smallest_regression_test",
    "source_artifact",
)
QUEUE_LIST_COLUMNS = frozenset(
    {
        "depends_on",
        "evidence",
        "missing_proof",
        "source_dimensions",
        "finding_ids",
        "anchors",
        "affected_surfaces",
        "reproduction_evidence",
    }
)


def make_resolution_record(
    queue_id: str,
    commit_sha: str,
    task_id: str,
    changed_paths: list[str],
    validation_artifacts: list[str],
    resolution_evidence: str,
) -> dict[str, Any]:
    """Return one canonical, self-contained remediation resolution record."""

    def require_explicit_text(name: str, value: str) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{name} must be a non-empty string")
        return value

    def canonical_paths(name: str, values: list[str]) -> list[str]:
        if not isinstance(values, list) or not values:
            raise ValueError(f"{name} must be a non-empty list")
        for value in values:
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"{name} contains a blank path")
            path = PurePosixPath(value)
            if (
                value != value.strip()
                or "\\" in value
                or path.is_absolute()
                or re.match(r"^[A-Za-z]:", value)
                or value in {".", ".."}
                or ".." in path.parts
                or str(path) != value
            ):
                raise ValueError(
                    f"{name} paths must be repository-relative canonical POSIX paths"
                )
        if len(values) != len(set(values)):
            raise ValueError(f"{name} contains duplicate paths")
        return sorted(values)

    queue_id = require_explicit_text("queue_id", queue_id)
    task_id = require_explicit_text("task_id", task_id)
    resolution_evidence = require_explicit_text(
        "resolution_evidence", resolution_evidence
    )
    if not isinstance(commit_sha, str) or not re.fullmatch(
        r"[0-9a-fA-F]{40}", commit_sha
    ):
        raise ValueError("commit_sha must be exactly 40 hexadecimal characters")

    return {
        "queue_id": queue_id,
        "commit_sha": commit_sha.lower(),
        "task_id": task_id,
        "changed_paths": canonical_paths("changed_paths", changed_paths),
        "validation_artifacts": canonical_paths(
            "validation_artifacts", validation_artifacts
        ),
        "resolution_evidence": resolution_evidence,
    }


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def update_release_blocker_queue_sha256(
    queue_path: Path, release_blocker_path: Path
) -> None:
    """Update the release-blocker queue digest from the queue's exact raw bytes."""
    queue_digest = hashlib.sha256(queue_path.read_bytes()).hexdigest()
    release_blocker = json.loads(release_blocker_path.read_text(encoding="utf-8"))
    if not isinstance(release_blocker, dict):
        raise ValueError("release-blocker queue must be a JSON object")
    existing_digest = release_blocker.get("remediation_queue_sha256")
    if not isinstance(existing_digest, str) or not re.fullmatch(
        r"[0-9a-f]{64}", existing_digest
    ):
        raise ValueError(
            "remediation_queue_sha256 must be exactly 64 lowercase hexadecimal characters"
        )
    release_blocker["remediation_queue_sha256"] = queue_digest
    release_blocker_path.write_text(
        json.dumps(release_blocker, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise ValueError(f"{path.name}:{line_number}: {error}") from error
    return rows


def dimension_queue_id(trait_id: str, dimension: str) -> str:
    return f"dimension:{trait_id}:{dimension}"


def build_dimension_rows(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    """Flatten all 198 x 24 trait dimensions into queryable records."""
    rows: list[dict[str, Any]] = []
    for trait in ledger["traits"]:
        for dimension in CANONICAL_DIMENSIONS:
            detail = trait["dimensions"][dimension]
            rows.append(
                {
                    "queue_id": dimension_queue_id(trait["trait_id"], dimension),
                    "trait_id": trait["trait_id"],
                    "batch": trait["batch"],
                    "dimension": dimension,
                    "stage": DIMENSION_STAGE[dimension],
                    "state": detail["state"],
                    "evidence": detail["evidence"],
                    "missing_proof": detail["missing_proof"],
                    "source_dimensions": detail["source_dimensions"],
                    "finding_ids": trait["finding_ids"],
                    "translation_terminal_state": trait["translation_terminal_state"],
                }
            )
    return rows


def _first_pass_findings(campaign_root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted((campaign_root / "trait_batches").glob("batch_*.jsonl")):
        for trait in _load_jsonl(path):
            for finding in trait.get("findings", []):
                rows.append(
                    {
                        **finding,
                        "state": finding.get("resolution_state", "confirmed-defect"),
                        "trait_id": trait["trait_id"],
                        "source_artifact": f"trait_batches/{path.name}",
                    }
                )
    return rows


def _finding_stage(finding: dict[str, Any]) -> str:
    text = " ".join(
        str(value).lower()
        for value in (
            finding.get("title", ""),
            finding.get("affected_surfaces", ""),
            finding.get("anchors", ""),
        )
    )
    if any(word in text for word in ("package", "release", "deploy", "parity")):
        return "packaging"
    if any(word in text for word in ("translation", "localization", "description", "display")):
        return "player-facing"
    if any(word in text for word in ("event", "kahlua", "java", "lua", "runtime", "save", "load")):
        return "runtime-contract"
    if any(word in text for word in ("test", "mock", "tool", "validator", "documentation", "skill")):
        return "validation"
    return "product-semantics"


def build_finding_rows(ledger: dict[str, Any], campaign_root: Path) -> list[dict[str, Any]]:
    """Reconcile first-pass, independent, and recurring findings into one inventory."""
    findings = _first_pass_findings(campaign_root)
    findings.extend(
        {
            **finding,
            "source_artifact": "independent_reviews",
        }
        for finding in ledger["independent_review_findings"]
    )
    findings.extend(
        {
            **finding,
            "source_artifact": "recurring_pattern_findings.json",
        }
        for finding in build_report()["findings"]
    )

    ids = [str(finding["id"]) for finding in findings]
    if len(ids) != len(set(ids)):
        duplicates = sorted(item for item, count in Counter(ids).items() if count > 1)
        raise ValueError(f"finding IDs are not globally unique: {duplicates}")

    rows = []
    for finding in findings:
        state = normalize_state(str(finding.get("state", "confirmed-defect")), finding.get("missing_proof"))
        rows.append(
            {
                "queue_id": f"finding:{finding['id']}",
                "finding_id": finding["id"],
                "trait_id": finding.get("trait_id"),
                "stage": _finding_stage(finding),
                "state": state,
                "severity": str(finding.get("severity", "not-applicable")).lower(),
                "confidence": finding.get("confidence"),
                "title": finding.get("title"),
                "anchors": finding.get("anchors", []),
                "affected_surfaces": finding.get("affected_surfaces", []),
                "reproduction_evidence": finding.get(
                    "reproduction_evidence", finding.get("reproduction_or_source_evidence", [])
                ),
                "missing_proof": finding.get("missing_proof", []),
                "recommended_correction": finding.get("recommended_correction"),
                "smallest_regression_test": finding.get("smallest_regression_test"),
                "source_artifact": finding["source_artifact"],
            }
        )
    return sorted(rows, key=lambda row: row["queue_id"])


def build_queue(
    dimension_rows: list[dict[str, Any]], finding_rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    open_dimension_ids = {
        row["queue_id"] for row in dimension_rows if row["state"] in OPEN_STATES
    }
    queue: list[dict[str, Any]] = []
    for row in dimension_rows:
        if row["state"] not in OPEN_STATES:
            continue
        dependencies = [
            dimension_queue_id(row["trait_id"], dependency)
            for dependency in DIMENSION_DEPENDENCIES.get(row["dimension"], ())
            if dimension_queue_id(row["trait_id"], dependency) in open_dimension_ids
        ]
        queue.append(
            {
                **row,
                "subject_type": "trait-dimension",
                "status": "open",
                "validation_mode": (
                    "fix-and-regression"
                    if row["state"] in {"confirmed-defect", "coverage-gap"}
                    else "trace-simulate-and-prove"
                ),
                "depends_on": dependencies,
            }
        )
    for row in finding_rows:
        if row["state"] in OPEN_STATES:
            queue.append(
                {
                    **row,
                    "subject_type": "finding",
                    "status": "open",
                    "validation_mode": (
                        "fix-and-regression"
                        if row["state"] in {"confirmed-defect", "coverage-gap"}
                        else "trace-simulate-and-prove"
                    ),
                    "depends_on": [],
                }
            )
    ordered = sorted(
        queue,
        key=lambda row: (
            STAGE_ORDER[row["stage"]],
            STATE_ORDER[row["state"]],
            SEVERITY_ORDER.get(row.get("severity", "not-applicable"), 4),
            row["queue_id"],
        ),
    )
    return [
        {
            column: row.get(column, [] if column in QUEUE_LIST_COLUMNS else None)
            for column in QUEUE_COLUMNS
        }
        for row in ordered
    ]


def build_summary(
    ledger: dict[str, Any],
    dimension_rows: list[dict[str, Any]],
    finding_rows: list[dict[str, Any]],
    queue: list[dict[str, Any]],
) -> dict[str, Any]:
    def counts(rows: list[dict[str, Any]], key: str) -> dict[str, int]:
        return dict(sorted(Counter(str(row[key]) for row in rows).items()))

    return {
        "schema_version": "1.0.0",
        "queue_type": "closed-world UTMods remediation queue",
        "source_ledger_schema_version": ledger["schema_version"],
        "counts": {
            "traits": ledger["counts"]["traits"],
            "dimension_records": len(dimension_rows),
            "finding_records": len(finding_rows),
            "open_queue_records": len(queue),
            "dimension_states": counts(dimension_rows, "state"),
            "finding_states": counts(finding_rows, "state"),
            "queue_states": counts(queue, "state"),
            "queue_stages": counts(queue, "stage"),
            "queue_subject_types": counts(queue, "subject_type"),
        },
        "acceptance": {
            "complete_when": "open_queue_records is zero after source-derived regeneration",
            "allowed_terminal_state": "proven-correct",
            "deferrals": "require an explicit user-approved non-goal recorded in source audit evidence",
        },
    }


def render_jsonl(rows: list[dict[str, Any]]) -> str:
    return "".join(
        json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        for row in rows
    )


def render_summary(summary: dict[str, Any]) -> str:
    return json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def build_outputs(campaign_root: Path = CAMPAIGN_ROOT) -> tuple[str, str, str]:
    ledger = build_ledger(campaign_root)
    dimension_rows = build_dimension_rows(ledger)
    finding_rows = build_finding_rows(ledger, campaign_root)
    queue = build_queue(dimension_rows, finding_rows)
    summary = build_summary(ledger, dimension_rows, finding_rows, queue)
    return render_jsonl(dimension_rows), render_jsonl(queue), render_summary(summary)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 build_remediation_queue.py")
    if cli_result is not None:
        return cli_result
    try:
        dimension_text, queue_text, summary_text = build_outputs()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    DIMENSION_OUTPUT_PATH.write_text(dimension_text, encoding="utf-8", newline="\n")
    QUEUE_OUTPUT_PATH.write_text(queue_text, encoding="utf-8", newline="\n")
    SUMMARY_OUTPUT_PATH.write_text(summary_text, encoding="utf-8", newline="\n")
    print(
        json.dumps(
            {
                "ok": True,
                "dimension_records": len(dimension_text.splitlines()),
                "queue_records": len(queue_text.splitlines()),
                "dimension_sha256": _sha256(DIMENSION_OUTPUT_PATH),
                "queue_sha256": _sha256(QUEUE_OUTPUT_PATH),
                "summary_sha256": _sha256(SUMMARY_OUTPUT_PATH),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
