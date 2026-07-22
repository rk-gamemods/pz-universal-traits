"""Reconcile accepted Scrounger campaign evidence and regenerate derived artifacts."""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256
from campaign_cli import no_arg_command
from check_recurring_patterns import build_report, render_report


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_scrounger"
FINDINGS = (
    "B10-SCROUNGER-001",
    "B10-SCROUNGER-002",
    "B10-SCROUNGER-003",
)
SOURCE_COMMIT = "9d838fe6975dff360b8a0ea9463d9e0ee9a4d2ad"
DESCRIPTION = (
    "+1 to Plant Scavenging. When opening a container for the first time, "
    "30 percent chance to find an additional item."
)
DERIVED_OUTPUTS = (
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "dimension_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "release_blocker_queue.json",
    "remediation_summary.json",
    "recurring_pattern_findings.json",
    "campaign_manifest.json",
)
TRANSACTION_PREFIX = ".regenerate_scrounger."


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _render_json(value: Any, *, compact: bool = False) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=None if compact else 2,
        separators=(",", ":") if compact else None,
    )
    return (text + "\n").encode("utf-8")


def _exactly_one(rows: list[dict[str, Any]], key: str, value: str, owner: str) -> dict[str, Any]:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner}: expected one {key}={value}, found {len(matches)}")
    return matches[0]


def _dimension(state: str, evidence: str, missing_proof: str = "") -> dict[str, Any]:
    return {"state": state, "evidence": [evidence], "missing_proof": missing_proof}


def _update_batch(plan: dict[str, bytes]) -> None:
    relative = "trait_batches/batch_10.jsonl"
    path = CAMPAIGN / relative
    lines = path.read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line]
    row = _exactly_one(rows, "trait_id", TRAIT, relative)
    row["overall_state"] = "coverage-gap"
    row["dimensions"] = {
        "registration": _dimension("proven-correct", "One namespaced Scrounger registration exists and matches the definition/runtime ID."),
        "definition_parser": _dimension("proven-correct", "The isolated balanced Scrounger definition block parses with one immediate opening brace."),
        "namespace": _dimension("proven-correct", "Registration, CharacterTrait, runtime TRAIT_ID, and UI keys consistently identify Scrounger."),
        "cost_xp_grants_exclusions": _dimension(
            "coverage-gap",
            "The isolated definition proves exactly Cost = 3 and XPBoosts = PlantScavenging=1, with no Scrounger exclusions; these values are current configuration, not accepted product intent.",
            "User decision evidence is still required before treating Cost 3, PlantScavenging=1, or the absence of exclusions as accepted design intent.",
        ),
        "source_intent": _dimension("proven-correct", "Current runtime and English copy agree on one permanent 30 percent roll per world container and duplication of one existing item."),
        "runtime_path": _dimension("proven-correct", "The end-phase inventory refresh callback resolves the page player, traverses Lua backpacks, and processes eligible world containers."),
        "numbers": _dimension("proven-correct", "Regression coverage proves the 30 percent boundary, exactly one duplicated zero-based Java-list item, and the current +1 PlantScavenging definition value."),
        "cadence": _dimension("proven-correct", "Only the inventory refresh end phase may inspect and roll; begin, beforeFloor, and buttonsAdded are rejected."),
        "cooldown": _dimension("proven-correct", "There is no timed cooldown; a permanent container modData flag enforces one inspection roll."),
        "reset_save_load": _dimension(
            "runtime-unproven",
            "Source and regression tests prove the persistent UT_scroungerRolled gate and no reset path.",
            "No in-game save, full exit, and reload proof was accepted; verify persistence in the current game runtime.",
        ),
        "java_lua": _dimension("proven-correct", "The callback treats backpacks as a 1-based Lua array and item collections as zero-based Java lists, and uses the verified global container-sync call."),
        "kahlua": _dimension("proven-correct", "Focused standard-Lua regression coverage exercises the corrected callback contracts without unsupported method guards or collection calls."),
        "lifecycle": _dimension("proven-correct", "Trait-local event registration is idempotent across repeated module loads and the callback gates player and trait presence."),
        "stacking_interactions": _dimension("proven-correct", "The permanent world-container flag deterministically prevents a second Scrounger roll on the same container."),
        "multiplayer": _dimension("not-applicable", "Multiplayer support is outside UTMods product scope; no multiplayer behavior or proof is claimed."),
        "display": _dimension("proven-correct", "The current English display name is Scrounger and source/release copies are byte-identical."),
        "description": _dimension("proven-correct", "The current English copy states +1 Plant Scavenging and the 30 percent first-open additional-item behavior, with exact source/release parity."),
        "localization_absent_locales": _dimension("proven-correct", "English is the product translation surface in scope for this accepted Scrounger reconciliation; no additional locale claim is made."),
        "balance": _dimension("proven-correct", "The audited artifact accurately records the unchanged current mechanic and numbers without accepting Cost, XP, or exclusions as intended balance."),
        "performance": _dimension("proven-correct", "The callback gates to the end phase, exits for ineligible players/containers, and permanently avoids repeat rolls per container."),
        "tests": _dimension("proven-correct", f"Commit {SOURCE_COMMIT} contains the exact isolated Scrounger definition regression; direct suite 7/7 and full UniversalTraits suite 427/427 passed."),
        "mocks": _dimension("proven-correct", "Focused fixtures encode the two-argument event, four phases, Lua-array backpacks, zero-based Java items, player/trait gates, and idempotent registration."),
        "source_release_parity": _dimension("proven-correct", "Current runtime, definition, and English source/release files are byte-identical for the accepted Scrounger surfaces."),
        "packaging": _dimension("proven-correct", "The current release package contains byte-identical Scrounger runtime, definition, and English evidence; deployment/live state is not claimed."),
    }

    finding_updates = {
        "B10-SCROUNGER-001": {
            "state": "proven-correct",
            "resolution_state": "proven-correct",
            "title": "Scrounger inventory refresh callback follows the accepted engine contract",
            "affected_surfaces": ["runtime", "Java-Lua", "Kahlua", "tests", "mocks"],
            "reproduction_evidence": "Focused tests fire exactly (inventoryPage,state), traverse a plain Lua backpacks array, resolve the page player, gate all non-end phases, and exercise zero-based Java items.",
            "missing_proof": "",
            "recommended_correction": "Complete; preserve the corrected callback and focused regression coverage.",
            "smallest_regression_test": "Run UniversalTraits/test/test_scrounger_runtime.lua and retain the exact event/collection contract cases.",
        },
        "B10-SCROUNGER-002": {
            "state": "proven-correct",
            "resolution_state": "proven-correct",
            "title": "Scrounger source and release package use the same supported container-sync path",
            "affected_surfaces": ["source-release parity", "packaging", "runtime"],
            "reproduction_evidence": "The focused suite byte-compares runtime source/release files and exercises sendAddItemToContainer(inv,newItem) after exactly one successful duplication.",
            "missing_proof": "",
            "recommended_correction": "Complete; preserve exact source/release runtime parity.",
            "smallest_regression_test": "Run the focused Scrounger source/release parity and successful-duplication assertions.",
        },
        "B10-SCROUNGER-003": {
            "state": "proven-correct",
            "resolution_state": "proven-correct",
            "title": "Scrounger English copy discloses the current Plant Scavenging level",
            "affected_surfaces": ["description", "display", "source-release parity"],
            "reproduction_evidence": "The isolated definition proves exactly XPBoosts = PlantScavenging=1 and current English source/release copies state +1 Plant Scavenging.",
            "missing_proof": "",
            "recommended_correction": "Complete as a current-definition disclosure; do not treat the XP value as accepted product intent.",
            "smallest_regression_test": "Run the focused isolated-definition and exact English source/release assertions.",
        },
    }
    if {finding.get("id") for finding in row["findings"]} != set(FINDINGS):
        raise ValueError("batch_10 Scrounger finding IDs are ambiguous")
    for finding in row["findings"]:
        finding.update(finding_updates[finding["id"]])
    row["unknowns"] = [
        "In-game save/full-exit/reload persistence remains runtime-unproven.",
        "Cost 3, PlantScavenging=1, and the absence of exclusions remain user-decision evidence rather than accepted product intent.",
    ]
    row["validation"] = {
        "evidence_mode": "accepted current source/release evidence and isolated Scrounger regression; no Munch/index use",
        "source_commit": SOURCE_COMMIT,
        "direct_suite": "UniversalTraits/test/test_scrounger_runtime.lua: 7 passed, 0 failed",
        "full_suite": "UniversalTraits/test/run_tests.lua: 427 passed, 0 failed",
        "runtime": "not run in game; save/load remains runtime-unproven",
        "non_goals": ["multiplayer", "save migration", "deployment"],
        "scope": "Scrounger only",
    }
    replacement = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    rendered = [replacement if json.loads(line).get("trait_id") == TRAIT else line for line in lines]
    plan[relative] = ("\n".join(rendered) + "\n").encode("utf-8")


def _update_translation(plan: dict[str, bytes]) -> None:
    relative = "translation_audit.json"
    artifact = _load_json(CAMPAIGN / relative)
    row = _exactly_one(artifact["per_trait_ledger"], "trait_id", TRAIT, relative)
    row["terminal_state"] = "proven-correct"
    row["terminal_state_reasons"] = []
    row["definition"]["line"] = 688
    row["english"]["description"].update(
        source_value=DESCRIPTION,
        normal_runtime_translator_value=DESCRIPTION,
        translator_percent_mutates=False,
        dev_rejected_confusables=[],
        static_display_state="proven-correct",
        semantic_claim_state="proven-correct",
    )
    plan[relative] = _render_json(artifact, compact=True)


def _update_review(plan: dict[str, bytes]) -> None:
    relative = "independent_reviews/traits_09_12.json"
    artifact = _load_json(CAMPAIGN / relative)
    row = _exactly_one(artifact["per_trait_review"], "trait_id", TRAIT, relative)
    row["accepted_overall_state"] = "coverage-gap"
    row["independent_state"] = "coverage-gap"
    row["unresolved_runtime_proof_ids"] = ["RP0912-SAVELOAD-001"]
    plan[relative] = _render_json(artifact)


def _update_release_blockers(plan: dict[str, bytes]) -> None:
    relative = "release_blocker_queue.json"
    artifact = _load_json(CAMPAIGN / relative)
    identities = artifact.get("identities")
    if not isinstance(identities, list):
        raise ValueError(f"{relative}: identities must be a list")
    target_ids = {"trait:UT_scrounger-runtime", "package:UT_scrounger"}
    matches = [row for row in identities if row.get("semantic_identity") in target_ids]
    matched_ids = {row.get("semantic_identity") for row in matches}
    if matches and (matched_ids != target_ids or len(matches) != 2):
        raise ValueError(f"{relative}: Scrounger blocker identities are partial or ambiguous")
    artifact["identities"] = [
        row for row in identities if row.get("semantic_identity") not in target_ids
    ]
    plan[relative] = _render_json(artifact)


def _materialize_inputs(plan: dict[str, bytes], overlay: Path) -> None:
    if not overlay.exists():
        shutil.copytree(CAMPAIGN, overlay)
    for relative, data in plan.items():
        destination = overlay / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)


def _regenerate_derived(plan: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory(prefix=TRANSACTION_PREFIX) as directory:
        overlay = Path(directory) / "campaign"
        _materialize_inputs(plan, overlay)
        ledger = build_ledger(overlay)
        dimensions, queue, summary = build_outputs(overlay, ledger)
        plan.update(
            {
                "final_trait_ledger.json": render_ledger(ledger).encode("utf-8"),
                "final_trait_ledger_rows.jsonl": render_trait_rows(ledger).encode("utf-8"),
                "dimension_ledger_rows.jsonl": dimensions.encode("utf-8"),
                "remediation_queue.jsonl": queue.encode("utf-8"),
                "remediation_summary.json": summary.encode("utf-8"),
            }
        )
        _materialize_inputs(plan, overlay)
        blocker_path = overlay / "release_blocker_queue.json"
        update_release_blocker_queue_sha256(overlay / "remediation_queue.jsonl", blocker_path)
        plan["release_blocker_queue.json"] = blocker_path.read_bytes()
        plan["recurring_pattern_findings.json"] = render_report(build_report()).encode("utf-8")
        _materialize_inputs(plan, overlay)
        plan["campaign_manifest.json"] = render_manifest(build_manifest(overlay)).encode("utf-8")


def _commit_plan(plan: dict[str, bytes]) -> None:
    for relative, data in plan.items():
        destination = CAMPAIGN / relative
        if destination.read_bytes() != data:
            destination.write_bytes(data)


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_scrounger.py")
    if cli_result is not None:
        return cli_result
    try:
        plan: dict[str, bytes] = {}
        _update_batch(plan)
        _update_translation(plan)
        _update_review(plan)
        _update_release_blockers(plan)
        _regenerate_derived(plan)
        _commit_plan(plan)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "trait_id": TRAIT}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
