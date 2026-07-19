"""Build the deterministic, normalized UniversalTraits audit ledger."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

from campaign_cli import no_arg_command


CAMPAIGN_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = CAMPAIGN_ROOT / "final_trait_ledger.json"
OUTPUT_JSONL_PATH = CAMPAIGN_ROOT / "final_trait_ledger_rows.jsonl"

TERMINAL_STATES = (
    "proven-correct",
    "confirmed-defect",
    "coverage-gap",
    "runtime-unproven",
)
STATE_PRIORITY = {
    "proven-correct": 0,
    "runtime-unproven": 1,
    "coverage-gap": 2,
    "confirmed-defect": 3,
}

CANONICAL_DIMENSIONS = (
    "registration",
    "definition_parser",
    "namespace",
    "cost_xp_grants_exclusions",
    "source_intent",
    "runtime_path",
    "numbers",
    "cadence",
    "cooldown",
    "reset_save_load",
    "java_lua",
    "kahlua",
    "events",
    "stacking_interactions",
    "multiplayer",
    "display",
    "description",
    "localization",
    "balance",
    "performance",
    "tests",
    "mocks",
    "source_release_parity",
    "packaging",
)


def _aliases() -> dict[str, tuple[str, ...]]:
    groups = {
        ("registration",): ["registration"],
        ("definition_parser",): [
            "complete script definition and parser validity",
            "complete_script_definition_and_parser_validity",
            "complete_script_parser",
            "script_parser",
            "script_definition_parser_validity",
            "complete_script_definition_parser_validity",
            "definition_parser",
        ],
        ("namespace",): ["namespace"],
        ("cost_xp_grants_exclusions",): [
            "cost/XP/grants/exclusions and bidirectional exclusion behavior",
            "cost_XP_grants_exclusions_and_bidirectional_exclusion_behavior",
            "cost_xp_grants_exclusions",
            "cost_xp_grants_exclusions_reverse_exclusions",
            "cost",
            "xp",
            "grants",
            "exclusions",
            "bidirectional_exclusion_behavior",
            "bidirectional_exclusions",
        ],
        ("source_intent",): ["source-mod intent", "source_mod_intent", "source_intent"],
        ("runtime_path",): [
            "exact runtime path through UT_CORE or script-only behavior",
            "exact_runtime_path_through_UT_CORE_or_script_only_behavior",
            "runtime_ut_core_path",
            "runtime_shared_script_only_path",
            "runtime_utcore_or_script_only_path",
            "runtime_path",
        ],
        ("numbers",): ["numerical behavior", "numerical_behavior", "numbers"],
        ("cadence",): ["cadence"],
        ("cooldown",): ["cooldowns", "cooldown"],
        ("cadence", "cooldown", "reset_save_load"): ["cadence_cooldown_reset_save_load"],
        ("reset_save_load",): ["reset and save/load", "reset_and_save_load", "reset_save_load"],
        ("java_lua",): ["Java-Lua exposure", "Java_Lua_exposure", "java_lua"],
        ("kahlua",): ["Kahlua compatibility", "Kahlua_compatibility", "kahlua"],
        ("java_lua", "kahlua"): ["java_lua_kahlua"],
        ("events",): ["event lifecycle", "event_lifecycle", "lifecycle", "events"],
        ("stacking_interactions",): [
            "stacking and cross-trait interactions",
            "stacking_and_cross_trait_interactions",
            "stacking_cross_trait_interactions",
            "stacking_interactions",
        ],
        ("multiplayer",): ["multiplayer restriction", "multiplayer_restriction", "multiplayer"],
        ("display",): ["display name", "display_name", "display"],
        ("description",): ["description accuracy", "description_accuracy", "description"],
        ("localization",): [
            "localization coverage including absent locales",
            "localization_coverage_including_absent_locales",
            "localization_absent_locales",
            "localization_coverage_absent_locales",
            "localization",
        ],
        ("display", "description", "localization"): [
            "display_description_localization_absent_locales"
        ],
        ("balance",): ["balance"],
        ("performance",): ["performance risk", "performance_risk", "performance"],
        ("balance", "performance"): ["balance_performance"],
        ("tests",): ["tests"],
        ("mocks",): ["mocks"],
        ("tests", "mocks"): ["tests_mocks"],
        ("source_release_parity",): ["source/release parity", "source_release_parity"],
        ("packaging",): ["packaging integrity", "packaging_integrity", "packaging"],
    }
    result: dict[str, tuple[str, ...]] = {}
    for targets, names in groups.items():
        for name in names:
            result[normalize_label(name)] = targets
    return result


def normalize_label(value: str) -> str:
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", value.lower())).strip("_")


DIMENSION_ALIASES = _aliases()


def _as_text_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    text = str(value).strip()
    return [text] if text else []


def _dimension_missing_proof(raw: dict[str, Any]) -> list[str]:
    """Preserve canonical and legacy batch spellings of the missing-proof field."""
    values = []
    for key in ("missing_proof", "exact_missing_proof", "exact missing proof"):
        values.extend(_as_text_list(raw.get(key)))
    return list(dict.fromkeys(values))


def _has_meaningful_missing_proof(value: Any) -> bool:
    items = [item.lower() for item in _as_text_list(value)]
    return any(item not in {"none", "n/a", "not applicable", "not-applicable"} for item in items)


def normalize_state(value: str, missing_proof: Any = None) -> str:
    normalized = normalize_label(value)
    direct = {
        "proven": "proven-correct",
        "proven_correct": "proven-correct",
        "defect": "confirmed-defect",
        "confirmed_defect": "confirmed-defect",
        "gap": "coverage-gap",
        "coverage_gap": "coverage-gap",
        "runtime_unproven": "runtime-unproven",
        "partial": "coverage-gap",
        "reviewed": "runtime-unproven",
    }
    if normalized == "not_applicable":
        return "runtime-unproven" if _has_meaningful_missing_proof(missing_proof) else "proven-correct"
    if normalized not in direct:
        raise ValueError(f"unknown audit state: {value!r}")
    return direct[normalized]


def _merge_dimension(entries: list[dict[str, Any]]) -> dict[str, Any]:
    if not entries:
        raise ValueError("canonical dimension has no source entries")
    state = max((entry["state"] for entry in entries), key=STATE_PRIORITY.__getitem__)
    evidence = sorted({item for entry in entries for item in entry["evidence"]})
    missing = sorted({item for entry in entries for item in entry["missing_proof"]})
    source_dimensions = sorted({entry["source_dimension"] for entry in entries})
    return {
        "state": state,
        "evidence": evidence,
        "missing_proof": missing,
        "source_dimensions": source_dimensions,
    }


def normalize_dimensions(dimensions: dict[str, Any]) -> dict[str, dict[str, Any]]:
    collected: dict[str, list[dict[str, Any]]] = {name: [] for name in CANONICAL_DIMENSIONS}
    for source_name, raw in dimensions.items():
        if not isinstance(raw, dict):
            raise ValueError(f"dimension {source_name!r} is not an object")
        alias = normalize_label(source_name)
        targets = DIMENSION_ALIASES.get(alias)
        if targets is None:
            raise ValueError(f"unmapped audit dimension: {source_name!r}")
        missing = _dimension_missing_proof(raw)
        entry = {
            "state": normalize_state(str(raw.get("state", "")), missing),
            "evidence": _as_text_list(raw.get("evidence")),
            "missing_proof": missing,
            "source_dimension": source_name,
        }
        for target in targets:
            collected[target].append(entry)
    absent = [name for name, entries in collected.items() if not entries]
    if absent:
        raise ValueError(f"missing canonical dimensions: {', '.join(absent)}")
    return {name: _merge_dimension(collected[name]) for name in CANONICAL_DIMENSIONS}


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path.name}:{line_number}: {exc}") from exc
    return rows


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _review_finding(finding: dict[str, Any]) -> dict[str, Any]:
    required = {
        "id",
        "state",
        "severity",
        "confidence",
        "title",
        "anchors",
        "affected_surfaces",
        "missing_proof",
        "recommended_correction",
        "smallest_regression_test",
    }
    missing = sorted(required - set(finding))
    evidence = finding.get("reproduction_evidence", finding.get("reproduction_or_source_evidence"))
    if missing or evidence is None:
        raise ValueError(f"incomplete independent-review finding {finding.get('id')}: {missing}")
    state = normalize_state(str(finding["state"]), finding.get("missing_proof"))
    severity = str(finding["severity"]).lower()
    if severity not in {"critical", "high", "medium", "low"}:
        raise ValueError(f"invalid finding severity {finding['severity']!r}")
    return {
        "id": finding["id"],
        "state": state,
        "severity": severity,
        "confidence": finding["confidence"],
        "title": finding["title"],
        "anchors": finding["anchors"],
        "affected_surfaces": finding["affected_surfaces"],
        "reproduction_evidence": evidence,
        "missing_proof": finding["missing_proof"],
        "recommended_correction": finding["recommended_correction"],
        "smallest_regression_test": finding["smallest_regression_test"],
    }


def _load_independent_trait_reviews(
    campaign_root: Path,
    expected_ids: list[str],
) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]], dict[str, str]]:
    review_dir = campaign_root / "independent_reviews"
    partitions = (
        ("traits_01_04.json", expected_ids[:68]),
        ("traits_05_08.json", expected_ids[68:134]),
        ("traits_09_12.json", expected_ids[134:]),
    )
    by_trait: dict[str, dict[str, Any]] = {}
    findings: list[dict[str, Any]] = []
    hashes: dict[str, str] = {}
    finding_ids: set[str] = set()

    for filename, assigned in partitions:
        path = review_dir / filename
        artifact = _load_json(path)
        hashes[f"independent_reviews/{filename}"] = _sha256(path)
        rows = artifact.get("per_trait_review")
        if not isinstance(rows, list):
            raise ValueError(f"{filename} has no per_trait_review array")
        observed = [row["trait_id"] for row in rows]
        validate_membership(assigned, observed)

        artifact_findings = [
            _review_finding(finding)
            for row in rows
            for finding in row.get("omissions", [])
        ]
        artifact_findings.extend(
            _review_finding(finding) for finding in artifact.get("cross_trait_findings", [])
        )
        artifact_ids = [finding["id"] for finding in artifact_findings]
        duplicates = finding_ids.intersection(artifact_ids)
        if duplicates or len(artifact_ids) != len(set(artifact_ids)):
            raise ValueError(f"duplicate independent-review finding IDs: {sorted(duplicates)}")
        finding_ids.update(artifact_ids)
        findings.extend(artifact_findings)

        for row in rows:
            trait_id = row["trait_id"]
            if trait_id in by_trait:
                raise ValueError(f"trait independently reviewed more than once: {trait_id}")
            review_state = row.get("review_state", row.get("independent_state"))
            if review_state is None:
                raise ValueError(f"independent review state missing for {trait_id}")
            by_trait[trait_id] = {
                "artifact": f"independent_reviews/{filename}",
                "review_state": review_state,
                "omission_finding_ids": [finding["id"] for finding in row.get("omissions", [])],
                "cross_finding_ids": row.get(
                    "cross_trait_finding_ids", row.get("cross_finding_ids", [])
                ),
                "verified_first_pass_finding_ids": row.get(
                    "verified_finding_ids", row.get("supported_accepted_finding_ids", [])
                ),
                "rejected_first_pass_finding_ids": row.get(
                    "rejected_finding_ids", row.get("rejected_accepted_finding_ids", [])
                ),
                "unresolved_runtime_proofs": row.get(
                    "unresolved_runtime_proof_ids", row.get("unresolved_proof", [])
                ),
            }

    validate_membership(expected_ids, sorted(by_trait))
    findings.sort(key=lambda finding: finding["id"])
    return by_trait, findings, hashes


def validate_membership(expected: Iterable[str], observed: Iterable[str]) -> None:
    expected_list = sorted(expected)
    observed_list = list(observed)
    if observed_list != sorted(observed_list):
        raise ValueError("trait records are not globally sorted")
    if len(observed_list) != len(set(observed_list)):
        raise ValueError("duplicate trait records")
    if observed_list != expected_list:
        missing = sorted(set(expected_list) - set(observed_list))
        extra = sorted(set(observed_list) - set(expected_list))
        raise ValueError(f"trait membership mismatch; missing={missing}; extra={extra}")


def build_ledger(campaign_root: Path = CAMPAIGN_ROOT) -> dict[str, Any]:
    inventory_path = campaign_root / "source_inventory.json"
    translation_path = campaign_root / "translation_audit.json"
    inventory = _load_json(inventory_path)
    translation = _load_json(translation_path)
    expected_ids = inventory["inventory"]["raw_source_sets"]["registrations"]["ids"]
    translation_rows = {row["trait_id"]: row for row in translation["per_trait_ledger"]}
    independent_reviews, independent_findings, independent_hashes = _load_independent_trait_reviews(
        campaign_root, expected_ids
    )

    batch_paths = sorted((campaign_root / "trait_batches").glob("batch_*.jsonl"))
    if [path.name for path in batch_paths] != [f"batch_{number:02d}.jsonl" for number in range(1, 13)]:
        raise ValueError("expected exactly batch_01.jsonl through batch_12.jsonl")

    source_hashes = {
        "source_inventory.json": _sha256(inventory_path),
        "translation_audit.json": _sha256(translation_path),
        **independent_hashes,
    }
    records: list[dict[str, Any]] = []
    finding_ids: set[str] = set()
    for path in batch_paths:
        source_hashes[f"trait_batches/{path.name}"] = _sha256(path)
        for raw in _load_jsonl(path):
            trait_id = raw["trait_id"]
            findings = raw.get("findings", [])
            ids = [finding["id"] for finding in findings]
            duplicates = finding_ids.intersection(ids)
            if duplicates or len(ids) != len(set(ids)):
                raise ValueError(f"duplicate finding IDs: {sorted(duplicates or set(ids))}")
            finding_ids.update(ids)
            if trait_id not in translation_rows:
                raise ValueError(f"missing translation row for {trait_id}")
            records.append(
                {
                    "trait_id": trait_id,
                    "batch": raw["batch"],
                    "overall_state": normalize_state(raw["overall_state"]),
                    "dimensions": normalize_dimensions(raw["dimensions"]),
                    "finding_ids": ids,
                    "unknowns": raw.get("unknowns", []),
                    "translation_terminal_state": translation_rows[trait_id]["terminal_state"],
                    "independent_review": independent_reviews[trait_id],
                }
            )

    records.sort(key=lambda row: row["trait_id"])
    validate_membership(expected_ids, [row["trait_id"] for row in records])
    validate_membership(expected_ids, sorted(translation_rows))

    state_counts = {state: 0 for state in TERMINAL_STATES}
    dimension_state_counts = {state: 0 for state in TERMINAL_STATES}
    independent_review_state_counts: dict[str, int] = {}
    for record in records:
        state_counts[record["overall_state"]] += 1
        review_state = record["independent_review"]["review_state"]
        independent_review_state_counts[review_state] = (
            independent_review_state_counts.get(review_state, 0) + 1
        )
        for dimension in record["dimensions"].values():
            dimension_state_counts[dimension["state"]] += 1

    return {
        "schema_version": "1.0",
        "ledger_type": "normalized-trait-audit",
        "normalization_policy": {
            "canonical_dimensions": list(CANONICAL_DIMENSIONS),
            "state_precedence_for_merged_dimensions": [
                "confirmed-defect",
                "coverage-gap",
                "runtime-unproven",
                "proven-correct",
            ],
            "legacy_state_mapping": {
                "proven": "proven-correct",
                "defect": "confirmed-defect",
                "gap": "coverage-gap",
                "partial": "coverage-gap",
                "reviewed": "runtime-unproven",
                "not-applicable with missing proof": "runtime-unproven",
                "not-applicable without missing proof": "proven-correct",
            },
        },
        "source_artifact_sha256": dict(sorted(source_hashes.items())),
        "counts": {
            "traits": len(records),
            "unique_traits": len({row["trait_id"] for row in records}),
            "findings": len(finding_ids),
            "independent_reviewed_traits": len(independent_reviews),
            "independent_review_findings": len(independent_findings),
            "independent_review_states": dict(sorted(independent_review_state_counts.items())),
            "overall_states": state_counts,
            "dimension_states": dimension_state_counts,
        },
        "independent_review_findings": independent_findings,
        "traits": records,
    }


def render_ledger(ledger: dict[str, Any]) -> str:
    return json.dumps(ledger, indent=2, ensure_ascii=False, sort_keys=False) + "\n"


def render_trait_rows(ledger: dict[str, Any]) -> str:
    return "".join(
        json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        for row in ledger["traits"]
    )


def main() -> int:
    cli_result = no_arg_command(
        sys.argv,
        "Usage: py -3 build_final_trait_ledger.py",
    )
    if cli_result is not None:
        return cli_result
    ledger = build_ledger()
    OUTPUT_PATH.write_text(render_ledger(ledger), encoding="utf-8", newline="\n")
    OUTPUT_JSONL_PATH.write_text(render_trait_rows(ledger), encoding="utf-8", newline="\n")
    print(
        json.dumps(
            {
                "output": str(OUTPUT_PATH),
                "jsonl_output": str(OUTPUT_JSONL_PATH),
                "traits": ledger["counts"]["traits"],
                "findings": ledger["counts"]["findings"],
                "sha256": _sha256(OUTPUT_PATH),
                "jsonl_sha256": _sha256(OUTPUT_JSONL_PATH),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
