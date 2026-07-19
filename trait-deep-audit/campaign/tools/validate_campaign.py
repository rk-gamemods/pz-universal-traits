"""Validate deterministic coverage and schema invariants for the audit campaign."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from campaign_cli import no_arg_command

from build_final_trait_ledger import (
    CAMPAIGN_ROOT,
    OUTPUT_JSONL_PATH,
    OUTPUT_PATH,
    build_ledger,
    render_ledger,
    render_trait_rows,
)
from check_recurring_patterns import (
    OUTPUT_PATH as PATTERN_OUTPUT_PATH,
    build_report,
    render_report,
)
from build_campaign_manifest import (
    OUTPUT_PATH as MANIFEST_OUTPUT_PATH,
    build_manifest,
    render_manifest,
)


def generated_artifact_errors(path: Path, expected: str, label: str) -> list[str]:
    if not path.exists():
        return [f"{label} is missing"]
    if path.read_text(encoding="utf-8") != expected:
        return [f"{label} is stale or nondeterministic"]
    return []


def main() -> int:
    cli_result = no_arg_command(
        sys.argv,
        "Usage: py -3 validate_campaign.py",
    )
    if cli_result is not None:
        return cli_result
    expected = render_ledger(build_ledger())
    errors = generated_artifact_errors(OUTPUT_PATH, expected, "final_trait_ledger.json")

    expected_rows = render_trait_rows(json.loads(expected))
    errors.extend(
        generated_artifact_errors(
            OUTPUT_JSONL_PATH, expected_rows, "final_trait_ledger_rows.jsonl"
        )
    )

    expected_patterns = render_report(build_report())
    errors.extend(
        generated_artifact_errors(
            PATTERN_OUTPUT_PATH, expected_patterns, "recurring_pattern_findings.json"
        )
    )

    try:
        expected_manifest = render_manifest(build_manifest())
    except (OSError, ValueError) as error:
        errors.append(f"campaign manifest could not be rebuilt: {error}")
    else:
        errors.extend(
            generated_artifact_errors(
                MANIFEST_OUTPUT_PATH, expected_manifest, "campaign_manifest.json"
            )
        )

    ledger = json.loads(expected)
    traits = ledger["traits"]
    finding_ids = [finding_id for row in traits for finding_id in row["finding_ids"]]
    if len(finding_ids) != len(set(finding_ids)):
        errors.append("normalized ledger contains duplicate finding IDs")
    if any(len(row["dimensions"]) != 24 for row in traits):
        errors.append("one or more traits do not have 24 canonical dimensions")
    if any(not row.get("independent_review") for row in traits):
        errors.append("one or more traits lack an independent review")

    pattern_report = json.loads(expected_patterns)
    pattern_ids = [finding["id"] for finding in pattern_report["findings"]]
    if len(pattern_ids) != len(set(pattern_ids)):
        errors.append("recurring-pattern report contains duplicate finding IDs")
    independent_ids = [finding["id"] for finding in ledger["independent_review_findings"]]
    all_ids = finding_ids + independent_ids + pattern_ids
    if len(all_ids) != len(set(all_ids)):
        errors.append("finding IDs are not globally unique across campaign artifacts")

    result = {
        "ok": not errors,
        "errors": errors,
        "traits": len(traits),
        "findings": len(finding_ids),
        "independent_review_findings": ledger["counts"]["independent_review_findings"],
        "recurring_pattern_findings": len(pattern_ids),
        "globally_unique_finding_ids": len(set(all_ids)),
        "ledger_sha256": (
            hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest().upper()
            if OUTPUT_PATH.exists()
            else None
        ),
        "ledger_jsonl_sha256": (
            hashlib.sha256(OUTPUT_JSONL_PATH.read_bytes()).hexdigest().upper()
            if OUTPUT_JSONL_PATH.exists()
            else None
        ),
        "campaign_manifest_sha256": (
            hashlib.sha256(MANIFEST_OUTPUT_PATH.read_bytes()).hexdigest().upper()
            if MANIFEST_OUTPUT_PATH.exists()
            else None
        ),
    }
    print(json.dumps(result, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
