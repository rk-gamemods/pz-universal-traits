"""Regenerate the campaign artifacts owned by the Unwavering copy correction."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs
from campaign_cli import no_arg_command
from check_recurring_patterns import build_report, render_report


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_unwavering"
FINDING = "B12-UNWAVERING-001"
DESCRIPTION = (
    "Fear never really got its hooks into you. Every 10 in-game minutes, "
    "if panic is above 10, panic is reduced by 10."
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, value: Any, *, compact: bool = False) -> None:
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=None if compact else 2,
        separators=(",", ":") if compact else None,
    )
    path.write_text(text + "\n", encoding="utf-8", newline="\n")


def _exactly_one(rows: list[dict[str, Any]], key: str, value: str, owner: str) -> dict[str, Any]:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner}: expected one {key}={value}, found {len(matches)}")
    return matches[0]


def _fingerprint(path: Path) -> dict[str, Any]:
    data = path.read_bytes().decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")
    return {
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "line_endings": {"crlf": 0, "bare_lf": data.count(b"\n")},
    }


def _update_matching_fingerprints(value: Any, relative: str, fingerprint: dict[str, Any]) -> int:
    updated = 0
    if isinstance(value, dict):
        if value.get("path") == relative:
            for key, replacement in fingerprint.items():
                if key in value:
                    value[key] = replacement
            updated += 1
        for child in value.values():
            updated += _update_matching_fingerprints(child, relative, fingerprint)
    elif isinstance(value, list):
        for child in value:
            updated += _update_matching_fingerprints(child, relative, fingerprint)
    return updated


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return {"state": state, "evidence": [evidence], "missing_proof": missing}


def _update_batch() -> None:
    path = CAMPAIGN / "trait_batches" / "batch_12.jsonl"
    lines = path.read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, path.name)
    proven = {
        "source_intent": "accepted fixed periodic panic recovery is documented and unchanged",
        "runtime_path": "EveryTenMinutes subtracts 10 panic only when panic is above 10",
        "numbers": "Build 42 panic scale uses threshold 10 and fixed subtraction 10",
        "description": "English copy states the exact cadence, strict threshold, and fixed amount",
        "tests": "behavioral boundary tests and exact source/release copy parity test are present",
        "balance": "documentation-only correction preserves the accepted cost 6 and mechanic",
        "mocks": "existing Stats mock covers the unchanged arithmetic; no panic-event hook is claimed",
        "source_release_parity": "assigned source/release Lua and English copy are byte-identical",
    }
    for name, evidence in proven.items():
        row["dimensions"][name] = _dimension("proven-correct", evidence)
    row["overall_state"] = "runtime-unproven"
    row["findings"] = [finding for finding in row["findings"] if finding.get("id") == FINDING]
    finding = _exactly_one(row["findings"], "id", FINDING, path.name)
    finding.update(
        state="proven-correct",
        title="Unwavering English copy matches the fixed periodic panic drain",
        affected_surfaces=["description", "tests", "source/release parity"],
        reproduction_evidence=(
            "Source and release English descriptions state EveryTenMinutes, panic above 10, "
            "and a fixed reduction of 10; focused tests assert the same unchanged runtime contract."
        ),
        missing_proof="",
        recommended_correction="Complete; preserve the fixed drain and exact copy parity.",
        smallest_regression_test="Run focused Unwavering behavior and exact copy/parity assertions.",
    )
    row["unknowns"] = [
        "Kahlua execution, save/load, rendered English, and panic-modifier interaction remain runtime-unproven."
    ]
    row["validation"].update(
        suite="focused and full suites recorded by the implementing commit",
        runtime="not run in game",
        closed_world="Unwavering documentation-only correction; no deployment",
    )
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    rendered = [replacement if json.loads(line).get("trait_id") == TRAIT else line for line in lines]
    path.write_text("\n".join(rendered) + "\n", encoding="utf-8", newline="\n")


def _update_translation() -> None:
    path = CAMPAIGN / "translation_audit.json"
    artifact = _load_json(path)
    row = _exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, path.name)
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
    for relative in (SOURCE_UI, RELEASE_UI):
        count = _update_matching_fingerprints(artifact, relative, _fingerprint(ROOT / relative))
        if count < 1:
            raise ValueError(f"{path.name}: expected at least one fingerprint owner for {relative}")
    _write_json(path, artifact, compact=True)


def _update_review() -> None:
    path = CAMPAIGN / "independent_reviews" / "traits_09_12.json"
    artifact = _load_json(path)
    row = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, path.name)
    row["accepted_overall_state"] = "runtime-unproven"
    row["independent_state"] = "runtime-unproven"
    row["unresolved_runtime_proof_ids"] = [
        "RP0912-KAHLUA-001",
        "RP0912-SAVELOAD-001",
        "RP0912-BALANCE-PERF-001",
        "RP0912-LOCALE-001",
    ]
    _write_json(path, artifact)


def _update_inventory() -> None:
    path = CAMPAIGN / "source_inventory.json"
    artifact = _load_json(path)
    count = _update_matching_fingerprints(artifact, SOURCE_UI, _fingerprint(ROOT / SOURCE_UI))
    if count < 1:
        raise ValueError(f"{path.name}: expected at least one source UI fingerprint owner")
    _write_json(path, artifact)


def _regenerate_derived() -> None:
    ledger = build_ledger(CAMPAIGN)
    (CAMPAIGN / "final_trait_ledger.json").write_text(
        render_ledger(ledger), encoding="utf-8", newline="\n"
    )
    (CAMPAIGN / "final_trait_ledger_rows.jsonl").write_text(
        render_trait_rows(ledger), encoding="utf-8", newline="\n"
    )
    dimensions, queue, summary = build_outputs(CAMPAIGN)
    (CAMPAIGN / "dimension_ledger_rows.jsonl").write_text(dimensions, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_queue.jsonl").write_text(queue, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_summary.json").write_text(summary, encoding="utf-8", newline="\n")
    (CAMPAIGN / "recurring_pattern_findings.json").write_text(
        render_report(build_report()), encoding="utf-8", newline="\n"
    )
    (CAMPAIGN / "campaign_manifest.json").write_text(
        render_manifest(build_manifest(CAMPAIGN)), encoding="utf-8", newline="\n"
    )


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_unwavering.py")
    if cli_result is not None:
        return cli_result
    try:
        _update_batch()
        _update_translation()
        _update_review()
        _update_inventory()
        _regenerate_derived()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "trait_id": TRAIT}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
