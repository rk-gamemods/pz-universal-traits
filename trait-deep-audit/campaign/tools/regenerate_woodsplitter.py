"""Regenerate the accepted Wood Splitter correction and campaign cascade."""
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path
from typing import Any
from campaign_cli import no_arg_command
from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs
from check_recurring_patterns import build_report, render_report

ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_woodsplitter"
DESC = ("+1 to Axe skill. Axe-category weapons deal 50% more damage to trees and have "
        "5% lower swing time, and general axe combat/swing animations are 25% faster. "
        "Eligible for the rare pine-tree key ring. Grants Ax-pert and does not stack with it.")

def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))

def write(path: Path, value: Any, compact: bool = False) -> None:
    text = json.dumps(value, ensure_ascii=False, indent=None if compact else 2,
                      separators=(",", ":") if compact else None)
    path.write_text(text + "\n", encoding="utf-8", newline="\n")

def fp(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    text = data.decode("utf-8")
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "line_endings": {"crlf": text.count("\r\n"),
                             "bare_lf": text.count("\n") - text.count("\r\n")}}

def update_fps(value: Any, relative: str, current: dict[str, Any]) -> int:
    count = 0
    if isinstance(value, dict):
        if value.get("path") == relative:
            for key in current:
                if key in value:
                    value[key] = current[key]
            count += 1
        for child in value.values():
            count += update_fps(child, relative, current)
    elif isinstance(value, list):
        for child in value:
            count += update_fps(child, relative, current)
    return count

def dim(state: str, evidence: str, missing: str = "") -> dict[str, Any]:
    return {"state": state, "evidence": [evidence], "missing_proof": missing}

def update_batch() -> None:
    path = CAMPAIGN / "trait_batches" / "batch_12.jsonl"
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    row = next(item for item in rows if item["trait_id"] == TRAIT)
    facts = {
      "registration": "namespaced registration remains exact and unique",
      "definition_parser": "definition parses cost, XP boost, grant, exclusion, and MP guard",
      "namespace": "Wood Splitter remains namespaced; unqualified Axeman resolves to base:axeman",
      "cost_xp_grants_exclusions": "cost 4; Axe=1; GrantedTraits=Axeman; MutuallyExclusiveTraits=Axeman",
      "source_intent": "declarative Wood Splitter reuses vanilla Axeman without custom runtime behavior",
      "runtime_path": "comment-only trait Lua; behavior is vanilla Axeman granted by the definition",
      "numbers": "vanilla anchors prove tree damage x1.5, attack time x0.95, and general axe combat speed 1.0 versus 0.8",
      "cadence": "no custom cadence or periodic handler", "cooldown": "no cooldown",
      "reset_save_load": "no custom state, migration, or save hook",
      "java_lua": "no custom Java-Lua calls; parser and vanilla consumers are source-anchored",
      "kahlua": "comment-only Lua contains no executable Kahlua behavior", "events": "no custom event registration",
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
      "packaging": "42.0 release counterpart is present; deployment is out of scope"}
    row["overall_state"] = "runtime-unproven"
    row["evidence_anchors"] = [
      "UniversalTraits/media/scripts/UT_character_traits.txt:874",
      "UniversalTraits/media/lua/shared/Translate/EN/UI.json:155",
      "UniversalTraits/test/run_tests.lua",
      "PZCodebase/Java/source/zombie/scripting/objects/ResourceLocation.java:27",
      "PZCodebase/Java/source/zombie/iso/objects/IsoTree.java:209",
      "PZCodebase/Java/source/zombie/inventory/types/HandWeapon.java",
      "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:10317",
      "PZCodebase/Lua/shared/Items/SpawnItems.lua"]
    row["dimensions"] = {key: dim("proven-correct", text) for key, text in facts.items()}
    row["dimensions"]["runtime_path"] = dim("runtime-unproven", facts["runtime_path"], "No in-game new-character run.")
    row["dimensions"]["reset_save_load"] = dim("runtime-unproven", facts["reset_save_load"], "Current save/reload unverified in game.")
    row["dimensions"]["localization"] = dim("runtime-unproven", facts["localization"], "Rendered English not observed in game.")
    finding = row["findings"][0]
    finding.update({"state": "proven-correct",
      "title": "Retired tree hook replaced by declarative vanilla Axeman reuse",
      "affected_surfaces": ["historical runtime", "tests", "mocks"],
      "reproduction_evidence": "Production Lua is comment-only; definition grants base:axeman; negative tests reject retired runtime behavior.",
      "missing_proof": "", "recommended_correction": "Complete; preserve declarative reuse.",
      "smallest_regression_test": "Run focused fixture and full UniversalTraits suite."})
    row["unknowns"] = ["In-game selection, save/reload, rendered EN, and key-ring occurrence remain unverified."]
    row["validation"] = {"independent": ["accepted producer and reviewer tasks"], "static_parse": "validated",
      "suite": "recorded by implementing commit", "runtime": "not run in game",
      "closed_world": "Wood Splitter only; EN-only; no deployment"}
    path.write_text("".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n" for item in rows),
                    encoding="utf-8", newline="\n")

def update_upstream() -> None:
    path = CAMPAIGN / "translation_audit.json"
    artifact = load(path)
    row = next(item for item in artifact["per_trait_ledger"] if item["trait_id"] == TRAIT)
    desc = row["english"]["description"]
    desc.update({"source_value": DESC, "normal_runtime_translator_value": DESC,
                 "semantic_claim_state": "proven-correct"})
    row["terminal_state"], row["terminal_state_reasons"] = "runtime-unproven", ["in-game rendering not observed"]
    for relative in ("UniversalTraits/media/lua/shared/Translate/EN/UI.json",
                     "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"):
        if update_fps(artifact, relative, fp(ROOT / relative)) < 1:
            raise ValueError("translation fingerprint owner mismatch: " + relative)
    write(path, artifact, True)

    path = CAMPAIGN / "independent_reviews" / "traits_09_12.json"
    artifact = load(path)
    row = next(item for item in artifact["per_trait_review"] if item["trait_id"] == TRAIT)
    row["accepted_overall_state"] = row["independent_state"] = "runtime-unproven"
    row["unresolved_runtime_proof_ids"] = ["woodsplitter-new-character", "woodsplitter-save-reload",
                                           "woodsplitter-rendered-en", "woodsplitter-key-ring"]
    write(path, artifact)

    path = CAMPAIGN / "source_inventory.json"
    artifact = load(path)
    changed = 0
    for relative in ("UniversalTraits/media/lua/shared/Translate/EN/UI.json",
                     "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"):
        changed += update_fps(artifact, relative, fp(ROOT / relative))
    if changed:
        write(path, artifact)

def update_change_impact() -> None:
    path = CAMPAIGN / "change-impact" / "woodsplitter-axeman-alias-resolution.json"
    artifact = load(path)
    for surface in artifact["surface_dispositions"]:
        if surface["path"].endswith("UT_woodsplitter.lua"):
            surface.update(disposition="unchanged-comment-only-no-runtime",
                           reason="Current Lua is comment-only with no state, hook, or OnCreatePlayer migration.")
        elif surface["path"].endswith("Translate/EN/UI.json"):
            surface.update(disposition="changed-copy-correction",
                           reason="Copy now states general axe combat/swing animation speed.")
    review = artifact["superseding_review"]
    review["current_source_assessment"] = "statically-validated-runtime-unproven"
    review["coverage"] = ["base:axeman alias resolution", "profession/direct exclusion", "grant retention",
      "profession-switch removal and repopulation", "tree damage x1.5", "attack-time x0.95",
      "general axe combat speed 1.0 versus 0.8", "pine key-ring eligibility", "grant/non-stacking"]
    review["not_proven"] = ["in-game selection and profession switching", "save/reload",
                            "rendered English", "pine-key-ring occurrence"]
    artifact["deferred_generated_owners"] = []
    write(path, artifact)
    path = CAMPAIGN / "change-impact" / "woodsplitter-axeman-balance.json"
    artifact = load(path)
    artifact["copy_scope"] = ("The 1.0 versus 0.8 branch is consumed by calculateCombatSpeed for "
                              "general axe combat/swing animations, not only tree actions.")
    write(path, artifact)

def rebuild() -> None:
    ledger = build_ledger()
    (CAMPAIGN / "final_trait_ledger.json").write_text(render_ledger(ledger), encoding="utf-8", newline="\n")
    (CAMPAIGN / "final_trait_ledger_rows.jsonl").write_text(render_trait_rows(ledger), encoding="utf-8", newline="\n")
    (CAMPAIGN / "recurring_pattern_findings.json").write_text(
        render_report(build_report()), encoding="utf-8", newline="\n")
    dimensions, queue, summary = build_outputs()
    (CAMPAIGN / "dimension_ledger_rows.jsonl").write_text(dimensions, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_queue.jsonl").write_text(queue, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_summary.json").write_text(summary, encoding="utf-8", newline="\n")
    path = CAMPAIGN / "MASTER_COVERAGE_LEDGER.md"
    text = path.read_text(encoding="utf-8")
    marker = "<!-- WOODSPLITTER-CORRECTION -->"
    note = marker + "\n- UniversalTraits:UT_woodsplitter is statically validated; in-game selection, save/reload, rendered EN, and key-ring occurrence remain runtime-unproven.\n"
    text = text.split(marker)[0].rstrip() + "\n\n" + note if marker in text else text.rstrip() + "\n\n" + note
    path.write_text(text, encoding="utf-8", newline="\n")
    (CAMPAIGN / "campaign_manifest.json").write_text(render_manifest(build_manifest()), encoding="utf-8", newline="\n")

def main() -> int:
    result = no_arg_command(sys.argv, "Usage: py -3 regenerate_woodsplitter.py")
    if result is not None:
        return result
    update_batch(); update_upstream(); update_change_impact(); rebuild()
    print(json.dumps({"ok": True, "trait_id": TRAIT}, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
