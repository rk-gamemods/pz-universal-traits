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
    canonical_translator_confusable_gate_errors,
    render_report,
)
from build_campaign_manifest import (
    OUTPUT_PATH as MANIFEST_OUTPUT_PATH,
    build_manifest,
    render_manifest,
)
from build_remediation_queue import (
    DIMENSION_OUTPUT_PATH,
    QUEUE_OUTPUT_PATH,
    SUMMARY_OUTPUT_PATH,
    build_outputs,
)


RELEASE_BLOCKER_PATH = CAMPAIGN_ROOT / "release_blocker_queue.json"


def generated_artifact_errors(path: Path, expected: str, label: str) -> list[str]:
    if not path.exists():
        return [f"{label} is missing"]
    if path.read_text(encoding="utf-8") != expected:
        return [f"{label} is stale or nondeterministic"]
    return []


def release_blocker_link_errors(
    release_blocker_path: Path, remediation_queue_path: Path
) -> list[str]:
    try:
        release_blocker_text = release_blocker_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ["release_blocker_queue.json is missing"]
    except OSError:
        return ["release_blocker_queue.json is unreadable"]

    try:
        release_blocker = json.loads(release_blocker_text)
    except json.JSONDecodeError:
        return ["release_blocker_queue.json is malformed JSON"]
    if not isinstance(release_blocker, dict):
        return ["release_blocker_queue.json must contain a JSON object"]
    if "remediation_queue_sha256" not in release_blocker:
        return ["release_blocker_queue.json is missing remediation_queue_sha256"]

    digest = release_blocker["remediation_queue_sha256"]
    if not (
        isinstance(digest, str)
        and len(digest) == 64
        and all(character in "0123456789abcdef" for character in digest)
    ):
        return ["release_blocker_queue.json has invalid remediation_queue_sha256"]

    try:
        remediation_queue_bytes = remediation_queue_path.read_bytes()
    except FileNotFoundError:
        return ["remediation_queue.jsonl is missing"]
    except OSError:
        return ["remediation_queue.jsonl is unreadable"]
    if hashlib.sha256(remediation_queue_bytes).hexdigest() != digest:
        return ["release_blocker_queue.json remediation_queue_sha256 does not match remediation_queue.jsonl exact bytes"]
    return []


def release_blocker_reference_errors(
    release_blocker_path: Path, remediation_queue_path: Path
) -> list[str]:
    try:
        release_blocker_text = release_blocker_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ["release_blocker_queue.json is missing"]
    except (OSError, UnicodeError):
        return ["release_blocker_queue.json is unreadable UTF-8"]

    try:
        release_blocker = json.loads(release_blocker_text)
    except json.JSONDecodeError:
        return ["release_blocker_queue.json is malformed JSON"]
    if not isinstance(release_blocker, dict):
        return ["release_blocker_queue.json must contain a JSON object"]

    blocker_errors: list[str] = []
    blocker_ids: list[str] = []
    blocker_id_set: set[str] = set()
    if "identities" not in release_blocker:
        blocker_errors.append("release_blocker_queue.json is missing identities")
        identities: object = []
    else:
        identities = release_blocker["identities"]
        if not isinstance(identities, list):
            blocker_errors.append("release_blocker_queue.json identities must be a list")
            identities = []

    for identity_index, identity in enumerate(identities):
        identity_label = f"release_blocker_queue.json identities[{identity_index}]"
        if not isinstance(identity, dict):
            blocker_errors.append(f"{identity_label} must be a JSON object")
            continue
        if "queue_ids" not in identity:
            blocker_errors.append(f"{identity_label} is missing queue_ids")
            continue
        queue_ids = identity["queue_ids"]
        if not isinstance(queue_ids, list):
            blocker_errors.append(f"{identity_label}.queue_ids must be a list")
            continue
        for queue_id_index, queue_id in enumerate(queue_ids):
            if not isinstance(queue_id, str) or not queue_id.strip():
                blocker_errors.append(
                    f"{identity_label}.queue_ids[{queue_id_index}] must be a nonempty string"
                )
                continue
            if queue_id not in blocker_id_set:
                blocker_id_set.add(queue_id)
                blocker_ids.append(queue_id)

    if blocker_errors:
        return blocker_errors

    queue_errors: list[str] = []
    reference_counts = {queue_id: 0 for queue_id in blocker_ids}
    try:
        with remediation_queue_path.open("r", encoding="utf-8", newline="") as queue_file:
            for line_number, line in enumerate(queue_file, start=1):
                line_label = f"remediation_queue.jsonl line {line_number}"
                if not line.strip():
                    queue_errors.append(f"{line_label} is blank")
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    queue_errors.append(f"{line_label} is malformed JSON")
                    continue
                if not isinstance(row, dict):
                    queue_errors.append(f"{line_label} must contain a JSON object")
                    continue
                if "queue_id" not in row:
                    queue_errors.append(f"{line_label} is missing queue_id")
                    continue
                queue_id = row["queue_id"]
                if not isinstance(queue_id, str) or not queue_id.strip():
                    queue_errors.append(
                        f"{line_label} queue_id must be a nonempty string"
                    )
                    continue
                if queue_id in reference_counts:
                    reference_counts[queue_id] += 1
    except FileNotFoundError:
        return blocker_errors + ["remediation_queue.jsonl is missing"]
    except (OSError, UnicodeError):
        return blocker_errors + ["remediation_queue.jsonl is unreadable UTF-8"]

    reference_errors: list[str] = []
    for queue_id in blocker_ids:
        count = reference_counts[queue_id]
        if count == 0:
            reference_errors.append(
                f"release blocker queue_id {queue_id!r} is missing from remediation_queue.jsonl"
            )
        elif count > 1:
            reference_errors.append(
                f"release blocker queue_id {queue_id!r} occurs {count} times in remediation_queue.jsonl"
            )
    return blocker_errors + queue_errors + reference_errors


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
    errors.extend(canonical_translator_confusable_gate_errors())

    expected_dimensions, expected_queue, expected_summary = build_outputs()
    errors.extend(
        generated_artifact_errors(
            DIMENSION_OUTPUT_PATH,
            expected_dimensions,
            "dimension_ledger_rows.jsonl",
        )
    )
    errors.extend(
        generated_artifact_errors(
            QUEUE_OUTPUT_PATH, expected_queue, "remediation_queue.jsonl"
        )
    )
    errors.extend(release_blocker_link_errors(RELEASE_BLOCKER_PATH, QUEUE_OUTPUT_PATH))
    errors.extend(
        release_blocker_reference_errors(RELEASE_BLOCKER_PATH, QUEUE_OUTPUT_PATH)
    )
    errors.extend(
        generated_artifact_errors(
            SUMMARY_OUTPUT_PATH, expected_summary, "remediation_summary.json"
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
        "dimension_records": len(expected_dimensions.splitlines()),
        "open_remediation_records": len(expected_queue.splitlines()),
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
