"""Transactionally regenerate only Wood Splitter-owned campaign records."""
from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any, Callable

from campaign_cli import no_arg_command
from build_final_trait_ledger import normalize_dimensions, normalize_state
from build_remediation_queue import (
    build_dimension_rows,
    build_queue,
    render_jsonl,
)


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_woodsplitter"
FINDING_ID = "B12-WOODSPLITTER-001"
PATTERN_ID = "RP-TRANSLATION-LITERAL-PERCENT"
DESC = (
    "+1 to Axe skill. Axe-category weapons deal 50% more damage to trees and have "
    "5% lower swing time, and general axe combat/swing animations are 25% faster. "
    "Eligible for the rare pine-tree key ring. Grants Ax-pert and does not stack with it."
)

OUTPUTS = (
    "trait_batches/batch_12.jsonl",
    "translation_audit.json",
    "independent_reviews/traits_09_12.json",
    "source_inventory.json",
    "change-impact/woodsplitter-axeman-alias-resolution.json",
    "change-impact/woodsplitter-axeman-balance.json",
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "recurring_pattern_findings.json",
    "MASTER_COVERAGE_LEDGER.md",
    "campaign_manifest.json",
)
MANIFEST_REFRESH_PATHS = tuple(path for path in OUTPUTS if path != "campaign_manifest.json") + (
    "tools/regenerate_woodsplitter.py",
    "tests/test_campaign_tools.py",
)
SOURCE_UI = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
RELEASE_UI = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"


def _json_bytes(value: Any, *, compact: bool = False, sort_keys: bool = False) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=None if compact else 2,
        separators=(",", ":") if compact else None,
        sort_keys=sort_keys,
    )
    return (text + "\n").encode("utf-8")


def _load_json(data: bytes) -> Any:
    return json.loads(data.decode("utf-8"))


def _load_jsonl(data: bytes) -> list[dict[str, Any]]:
    return [json.loads(line) for line in data.decode("utf-8").splitlines() if line]


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _exactly_one(rows: list[dict[str, Any]], key: str, value: str, owner: str) -> dict[str, Any]:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner} ownership mismatch: expected one {key}={value}, found {len(matches)}")
    return matches[0]


class Plan:
    """In-memory overlay; no canonical output is touched until commit()."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.campaign = root / "trait-deep-audit" / "campaign"
        self.original = {relative: (self.campaign / relative).read_bytes() for relative in OUTPUTS}
        self.planned = dict(self.original)

    def read(self, relative: str) -> bytes:
        return self.planned[relative]

    def write(self, relative: str, data: bytes) -> None:
        if relative not in self.planned:
            raise ValueError(f"unowned output: {relative}")
        original = self.original[relative]
        if b"\r\n" in original and original.count(b"\n") == original.count(b"\r\n"):
            data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        self.planned[relative] = data

    def json(self, relative: str) -> Any:
        return _load_json(self.read(relative))

    def write_json(self, relative: str, value: Any, *, compact: bool = False, sort_keys: bool = False) -> None:
        self.write(relative, _json_bytes(value, compact=compact, sort_keys=sort_keys))


def _fingerprint(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    text = data.decode("utf-8")
    return {
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "line_endings": {
            "crlf": text.count("\r\n"),
            "bare_lf": text.count("\n") - text.count("\r\n"),
        },
    }


def _update_fingerprints(value: Any, relative: str, current: dict[str, Any]) -> int:
    count = 0
    if isinstance(value, dict):
        if value.get("path") == relative:
            for key, replacement in current.items():
                if key in value:
                    value[key] = replacement
            count += 1
        for child in value.values():
            count += _update_fingerprints(child, relative, current)
    elif isinstance(value, list):
        for child in value:
            count += _update_fingerprints(child, relative, current)
    return count


def _dimension(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return {"state": state, "evidence": [evidence], "missing_proof": missing}


def _update_batch(plan: Plan) -> dict[str, Any]:
    relative = "trait_batches/batch_12.jsonl"
    original_lines = plan.read(relative).decode("utf-8").splitlines()
    rows = [json.loads(line) for line in original_lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    facts = {
        "registration": "namespaced registration remains exact and unique",
        "definition_parser": "definition parses cost, XP boost, grant, exclusion, and MP guard",
        "namespace": "Wood Splitter remains namespaced; unqualified Axeman resolves to base:axeman",
        "cost_xp_grants_exclusions": "cost 4; Axe=1; GrantedTraits=Axeman; MutuallyExclusiveTraits=Axeman",
        "source_intent": "declarative Wood Splitter reuses vanilla Axeman without custom runtime behavior",
        "runtime_path": "comment-only trait Lua; behavior is vanilla Axeman granted by the definition",
        "numbers": "vanilla anchors prove tree damage x1.5, attack time x0.95, and general axe combat speed 1.0 versus 0.8",
        "cadence": "no custom cadence or periodic handler",
        "cooldown": "no cooldown",
        "reset_save_load": "no custom state, migration, or save hook",
        "java_lua": "no custom Java-Lua calls; parser and vanilla consumers are source-anchored",
        "kahlua": "comment-only Lua contains no executable Kahlua behavior",
        "events": "no custom event registration",
        "stacking_interactions": "one set-like Axeman grant; selection exclusions prevent separate stacking",
        "multiplayer": "DisabledInMultiplayer=true; MP support remains a non-goal",
        "display": "English display resolves to Wood Splitter",
        "description": "copy separates tree damage, attack time, general axe speed, key ring, and grant/non-stacking",
        "localization": "EN source/release pair is present and byte-identical; EN-only policy is unchanged",
        "balance": "accepted cost 4 is preserved without revisiting balance",
        "performance": "comment-only Lua adds no runtime work",
        "tests": "fixture covers alias, profession/direct exclusion, grant, profession switching, and repopulation",
        "mocks": "no fabricated tree event or fake tree receiver is used",
        "source_release_parity": "English source and release descriptions are byte-identical",
        "packaging": "42.0 release counterpart is present; deployment is out of scope",
    }
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [
        "UniversalTraits/media/scripts/UT_character_traits.txt:874",
        "UniversalTraits/media/lua/shared/Translate/EN/UI.json:155",
        "UniversalTraits/test/run_tests.lua",
        "PZCodebase/Java/source/zombie/scripting/objects/ResourceLocation.java:27",
        "PZCodebase/Java/source/zombie/iso/objects/IsoTree.java:209",
        "PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java",
        "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:10317",
        "PZCodebase/Lua/shared/Items/SpawnItems.lua",
    ]
    row["dimensions"] = {key: _dimension("proven-correct", text) for key, text in facts.items()}
    row["dimensions"]["runtime_path"] = _dimension("runtime-unproven", facts["runtime_path"], "No in-game new-character run.")
    row["dimensions"]["reset_save_load"] = _dimension("runtime-unproven", facts["reset_save_load"], "Current save/reload unverified in game.")
    row["dimensions"]["localization"] = _dimension("runtime-unproven", facts["localization"], "Rendered English not observed in game.")
    findings = [item for item in row.get("findings", []) if item.get("id") == FINDING_ID]
    if len(findings) != 1:
        raise ValueError(f"{relative} finding ownership mismatch: expected one {FINDING_ID}, found {len(findings)}")
    findings[0].update(
        state="proven-correct",
        title="Retired tree hook replaced by declarative vanilla Axeman reuse",
        affected_surfaces=["historical runtime", "tests", "mocks"],
        reproduction_evidence="Production Lua is comment-only; definition grants base:axeman; negative tests reject retired runtime behavior.",
        missing_proof="",
        recommended_correction="Complete; preserve declarative reuse.",
        smallest_regression_test="Run focused fixture and full UniversalTraits suite.",
    )
    row["unknowns"] = ["In-game selection, save/reload, rendered EN, and key-ring occurrence remain unverified."]
    row["validation"] = {
        "independent": ["accepted producer and reviewer tasks"],
        "static_parse": "validated",
        "suite": "recorded by implementing commit",
        "runtime": "not run in game",
        "closed_world": "Wood Splitter only; EN-only; no deployment",
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    replaced = 0
    rendered_lines = []
    for line in original_lines:
        current = json.loads(line)
        if current.get("trait_id") == TRAIT:
            rendered_lines.append(replacement)
            replaced += 1
        else:
            rendered_lines.append(line)
    if replaced != 1:
        raise ValueError(f"{relative} replacement ownership mismatch: found {replaced}")
    plan.write(relative, ("\n".join(rendered_lines) + "\n").encode("utf-8"))
    return row


def _update_source_records(plan: Plan) -> dict[str, Any]:
    relative = "translation_audit.json"
    artifact = plan.json(relative)
    row = _exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["english"]["description"].update(
        source_value=DESC,
        normal_runtime_translator_value=DESC,
        semantic_claim_state="proven-correct",
    )
    row["terminal_state"] = "runtime-unproven"
    row["terminal_state_reasons"] = ["in-game rendering not observed"]
    for source_relative in (SOURCE_UI, RELEASE_UI):
        matches = _update_fingerprints(artifact, source_relative, _fingerprint(plan.root / source_relative))
        if matches < 1:
            raise ValueError(f"{relative} fingerprint ownership mismatch: {source_relative}")
    plan.write_json(relative, artifact, compact=True)

    relative = "independent_reviews/traits_09_12.json"
    review_artifact = plan.json(relative)
    review = _exactly_one(review_artifact["per_trait_review"], "trait_id", TRAIT, relative)
    review["accepted_overall_state"] = "runtime-unproven"
    review["independent_state"] = "runtime-unproven"
    review["unresolved_runtime_proof_ids"] = [
        "woodsplitter-new-character",
        "woodsplitter-save-reload",
        "woodsplitter-rendered-en",
        "woodsplitter-key-ring",
    ]
    plan.write_json(relative, review_artifact)

    relative = "source_inventory.json"
    inventory = plan.json(relative)
    inventory_matches = 0
    for source_relative in (SOURCE_UI, RELEASE_UI):
        inventory_matches += _update_fingerprints(
            inventory, source_relative, _fingerprint(plan.root / source_relative)
        )
    if inventory_matches < 1:
        raise ValueError(f"{relative} fingerprint ownership mismatch")
    plan.write_json(relative, inventory)
    return review


def _update_change_impact(plan: Plan) -> None:
    relative = "change-impact/woodsplitter-axeman-alias-resolution.json"
    artifact = plan.json(relative)
    surfaces = artifact["surface_dispositions"]
    lua_matches = [item for item in surfaces if str(item.get("path", "")).endswith("UT_woodsplitter.lua")]
    translation_matches = [item for item in surfaces if str(item.get("path", "")).endswith("Translate/EN/UI.json")]
    if len(lua_matches) != 2 or len(translation_matches) != 2:
        raise ValueError(f"{relative} surface ownership mismatch")
    for surface in lua_matches:
        surface.update(
            disposition="unchanged-comment-only-no-runtime",
            reason="Current Lua is comment-only with no state, hook, or OnCreatePlayer migration.",
        )
    for surface in translation_matches:
        surface.update(
            disposition="changed-copy-correction",
            reason="Copy now states general axe combat/swing animation speed.",
        )
    review = artifact["superseding_review"]
    review["current_source_assessment"] = "statically-validated-runtime-unproven"
    review["coverage"] = [
        "base:axeman alias resolution",
        "profession/direct exclusion",
        "grant retention",
        "profession-switch removal and repopulation",
        "tree damage x1.5",
        "attack-time x0.95",
        "general axe combat speed 1.0 versus 0.8",
        "pine key-ring eligibility",
        "grant/non-stacking",
    ]
    review["not_proven"] = [
        "in-game selection and profession switching",
        "save/reload",
        "rendered English",
        "pine-key-ring occurrence",
    ]
    artifact["deferred_generated_owners"] = []
    plan.write_json(relative, artifact)

    relative = "change-impact/woodsplitter-axeman-balance.json"
    artifact = plan.json(relative)
    artifact["copy_scope"] = (
        "The 1.0 versus 0.8 branch is consumed by calculateCombatSpeed for "
        "general axe combat/swing animations, not only tree actions."
    )
    plan.write_json(relative, artifact)


def _ledger_record(batch: dict[str, Any], review: dict[str, Any], translation: dict[str, Any]) -> dict[str, Any]:
    finding_ids = [finding["id"] for finding in batch.get("findings", [])]
    return {
        "trait_id": TRAIT,
        "batch": batch["batch"],
        "overall_state": normalize_state(batch["overall_state"]),
        "dimensions": normalize_dimensions(batch["dimensions"]),
        "finding_ids": finding_ids,
        "unknowns": batch.get("unknowns", []),
        "translation_terminal_state": translation["terminal_state"],
        "independent_review": {
            "artifact": "independent_reviews/traits_09_12.json",
            "review_state": review["independent_state"],
            "omission_finding_ids": [item["id"] for item in review.get("omissions", [])],
            "cross_finding_ids": review.get("cross_finding_ids", []),
            "verified_first_pass_finding_ids": review.get("supported_accepted_finding_ids", []),
            "rejected_first_pass_finding_ids": review.get("rejected_accepted_finding_ids", []),
            "unresolved_runtime_proofs": review.get("unresolved_runtime_proof_ids", []),
        },
    }


def _replace_jsonl_owned(
    data: bytes,
    replacements: list[dict[str, Any]],
    owner: Callable[[dict[str, Any]], bool],
) -> bytes:
    rows = _load_jsonl(data)
    existing = [row for row in rows if owner(row)]
    if len(existing) != len(replacements):
        raise ValueError(f"JSONL ownership mismatch: expected {len(replacements)} rows, found {len(existing)}")
    replacement_by_id = {row["queue_id"]: row for row in replacements}
    if len(replacement_by_id) != len(replacements):
        raise ValueError("replacement queue IDs are not unique")
    existing_ids = {row["queue_id"] for row in existing}
    if existing_ids != set(replacement_by_id):
        raise ValueError(f"JSONL owned ID mismatch: existing={sorted(existing_ids)} expected={sorted(replacement_by_id)}")
    return render_jsonl([replacement_by_id.get(row["queue_id"], row) for row in rows]).encode("utf-8")


def _update_derived(plan: Plan, batch: dict[str, Any], review: dict[str, Any]) -> None:
    translation_artifact = plan.json("translation_audit.json")
    translation = _exactly_one(translation_artifact["per_trait_ledger"], "trait_id", TRAIT, "translation_audit.json")
    record = _ledger_record(batch, review, translation)

    relative = "final_trait_ledger.json"
    ledger = plan.json(relative)
    existing = _exactly_one(ledger["traits"], "trait_id", TRAIT, relative)
    ledger["traits"][ledger["traits"].index(existing)] = record
    for source_relative in (
        "source_inventory.json",
        "translation_audit.json",
        "trait_batches/batch_12.jsonl",
        "independent_reviews/traits_09_12.json",
    ):
        if source_relative not in ledger["source_artifact_sha256"]:
            raise ValueError(f"{relative} missing source hash owner: {source_relative}")
        ledger["source_artifact_sha256"][source_relative] = _sha256(plan.read(source_relative))
    overall_counts = Counter(row["overall_state"] for row in ledger["traits"])
    dimension_counts = Counter(
        detail["state"] for row in ledger["traits"] for detail in row["dimensions"].values()
    )
    ledger["counts"]["overall_states"] = {
        state: overall_counts[state] for state in ledger["counts"]["overall_states"]
    }
    ledger["counts"]["dimension_states"] = {
        state: dimension_counts[state] for state in ledger["counts"]["dimension_states"]
    }
    ledger["counts"]["independent_review_states"] = dict(
        sorted(Counter(row["independent_review"]["review_state"] for row in ledger["traits"]).items())
    )
    plan.write_json(relative, ledger)

    relative = "final_trait_ledger_rows.jsonl"
    rows = _load_jsonl(plan.read(relative))
    old = _exactly_one(rows, "trait_id", TRAIT, relative)
    rows[rows.index(old)] = record
    plan.write(relative, render_jsonl(rows).encode("utf-8"))

    wood_dimensions = build_dimension_rows({"traits": [record]})
    relative = "dimension_ledger_rows.jsonl"
    plan.write(
        relative,
        _replace_jsonl_owned(plan.read(relative), wood_dimensions, lambda row: row.get("trait_id") == TRAIT),
    )

    finding = _exactly_one(batch["findings"], "id", FINDING_ID, "batch Wood Splitter findings")
    finding_row = {
        "queue_id": f"finding:{FINDING_ID}",
        "finding_id": FINDING_ID,
        "trait_id": TRAIT,
        "stage": "runtime-contract",
        "state": "confirmed-defect",
        "severity": str(finding.get("severity", "not-applicable")).lower(),
        "confidence": finding.get("confidence"),
        "title": finding.get("title"),
        "anchors": finding.get("anchors", []),
        "affected_surfaces": finding.get("affected_surfaces", []),
        "reproduction_evidence": finding.get("reproduction_evidence", []),
        "missing_proof": finding.get("missing_proof", []),
        "recommended_correction": finding.get("recommended_correction"),
        "smallest_regression_test": finding.get("smallest_regression_test"),
        "source_artifact": "trait_batches/batch_12.jsonl",
    }
    wood_queue = build_queue(wood_dimensions, [finding_row])
    relative = "remediation_queue.jsonl"
    plan.write(
        relative,
        _replace_jsonl_owned(plan.read(relative), wood_queue, lambda row: row.get("trait_id") == TRAIT),
    )

    dimensions = _load_jsonl(plan.read("dimension_ledger_rows.jsonl"))
    queue = _load_jsonl(plan.read("remediation_queue.jsonl"))
    summary = plan.json("remediation_summary.json")
    summary["counts"].update(
        traits=ledger["counts"]["traits"],
        dimension_records=len(dimensions),
        open_queue_records=len(queue),
        dimension_states=dict(sorted(Counter(row["state"] for row in dimensions).items())),
        queue_states=dict(sorted(Counter(row["state"] for row in queue).items())),
        queue_stages=dict(sorted(Counter(row["stage"] for row in queue).items())),
        queue_subject_types=dict(sorted(Counter(row["subject_type"] for row in queue).items())),
    )
    plan.write_json("remediation_summary.json", summary, sort_keys=True)


def _update_pattern(plan: Plan) -> None:
    relative = "recurring_pattern_findings.json"
    artifact = plan.json(relative)
    finding = _exactly_one(artifact["findings"], "id", PATTERN_ID, relative)
    finding.clear()
    finding.update(
        id=PATTERN_ID,
        state="confirmed-defect",
        severity="high",
        confidence="high",
        title="Translator preprocessing mutates literal percent signs in English descriptions",
        anchors=["UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI.json (keys: UI_UT_woodsplitterDesc)"],
        affected_surfaces=["description", "localization", "runtime"],
        reproduction_evidence="Applying the current two-step Translator replacement changes 1 no-argument descriptions.",
        missing_proof="",
        recommended_correction="Encode literal percent signs using the Translator-safe representation verified for this game build.",
        smallest_regression_test="Load every flagged key through the current Translator path without format arguments and compare the rendered text byte-for-byte with intended copy.",
    )
    artifact["summary"]["findings"] = len(artifact["findings"])
    artifact["summary"]["literal_percent_keys"] = 1
    plan.write_json(relative, artifact)


def _update_master(plan: Plan) -> None:
    relative = "MASTER_COVERAGE_LEDGER.md"
    text = plan.read(relative).decode("utf-8")
    marker = "<!-- WOODSPLITTER-CORRECTION -->"
    if text.count(marker) != 1:
        raise ValueError(f"{relative} ownership mismatch: expected one marker")
    note = (
        marker
        + "\n- UniversalTraits:UT_woodsplitter is statically validated; in-game selection, "
        "save/reload, rendered EN, and key-ring occurrence remain runtime-unproven.\n"
    )
    plan.write(relative, (text.split(marker)[0].rstrip() + "\n\n" + note).encode("utf-8"))


def _update_manifest(plan: Plan) -> None:
    relative = "campaign_manifest.json"
    manifest = plan.json(relative)
    rows = manifest["files"]
    paths = [row["path"] for row in rows]
    if len(paths) != len(set(paths)):
        raise ValueError(f"{relative} has duplicate paths")
    for refresh in MANIFEST_REFRESH_PATHS:
        matches = [row for row in rows if row["path"] == refresh]
        if len(matches) != 1:
            raise ValueError(f"{relative} ownership mismatch for {refresh}: found {len(matches)}")
        data = plan.read(refresh) if refresh in plan.planned else (plan.campaign / refresh).read_bytes()
        matches[0]["bytes"] = len(data)
        matches[0]["sha256"] = _sha256(data)
    manifest["file_count"] = len(rows)
    manifest["total_bytes"] = sum(row["bytes"] for row in rows)
    plan.write_json(relative, manifest)


def build_plan(root: Path = ROOT) -> Plan:
    plan = Plan(root)
    batch = _update_batch(plan)
    review = _update_source_records(plan)
    _update_change_impact(plan)
    _update_derived(plan, batch, review)
    _update_pattern(plan)
    _update_master(plan)
    _update_manifest(plan)
    return plan


def commit_transaction(
    plan: Plan,
    replace: Callable[[str | os.PathLike[str], str | os.PathLike[str]], None] = os.replace,
) -> list[str]:
    """Promote all changed outputs, rolling every promoted file back on failure."""
    changed = [relative for relative in OUTPUTS if plan.planned[relative] != plan.original[relative]]
    if not changed:
        return []
    staged: dict[str, Path] = {}
    backups: dict[str, Path] = {}
    promoted: list[str] = []
    preserve_backups = False
    try:
        for relative in changed:
            path = plan.campaign / relative
            handle, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".stage", dir=path.parent)
            temp = Path(temp_name)
            staged[relative] = temp
            with os.fdopen(handle, "wb") as stream:
                stream.write(plan.planned[relative])
                stream.flush()
                os.fsync(stream.fileno())
        for relative in changed:
            path = plan.campaign / relative
            backup = staged[relative].with_suffix(".backup")
            replace(path, backup)
            backups[relative] = backup
            try:
                replace(staged[relative], path)
            except BaseException:
                replace(backup, path)
                backups.pop(relative, None)
                raise
            promoted.append(relative)
        for backup in backups.values():
            backup.unlink(missing_ok=True)
        return changed
    except BaseException:
        rollback_errors = []
        for relative in reversed(promoted):
            path = plan.campaign / relative
            backup = backups.get(relative)
            if backup is None:
                continue
            try:
                path.unlink(missing_ok=True)
                replace(backup, path)
            except BaseException as error:  # pragma: no cover - catastrophic filesystem failure
                rollback_errors.append(f"{relative}: {error}")
        if rollback_errors:
            preserve_backups = True
            raise RuntimeError("transaction rollback incomplete: " + "; ".join(rollback_errors))
        raise
    finally:
        cleanup_paths = list(staged.values())
        if not preserve_backups:
            cleanup_paths.extend(backups.values())
        for path in cleanup_paths:
            path.unlink(missing_ok=True)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_woodsplitter.py")
    if cli_result is not None:
        return cli_result
    try:
        plan = build_plan()
        changed = commit_transaction(plan)
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "trait_id": TRAIT, "changed": changed}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
