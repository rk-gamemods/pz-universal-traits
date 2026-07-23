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
from build_campaign_manifest import (
    CANONICAL_TEXT_SEMANTICS,
    MANIFEST_SCHEMA_VERSION,
    RAW_BYTE_SEMANTICS,
    TEXT_ARTIFACT_SUFFIXES,
    artifact_metadata,
)
from build_final_trait_ledger import normalize_dimensions, normalize_state
from build_remediation_queue import (
    build_dimension_rows,
    build_queue,
    render_jsonl,
    update_release_blocker_queue_sha256,
)
from check_recurring_patterns import build_report as build_recurring_pattern_report
from check_recurring_patterns import render_report as render_recurring_pattern_report


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_woodsplitter"
FINDING_ID = "B12-WOODSPLITTER-001"
PATTERN_ID = "RP-TRANSLATION-LITERAL-PERCENT"
DESC = (
    "+1 Axe. Grants Ax-pert's 50% bonus tree damage and faster axe attacks. "
    "Eligible for the rare pine-tree key ring. Cannot be combined with another source of Ax-pert."
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
    "release_blocker_queue.json",
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
JOURNAL_NAME = ".regenerate_woodsplitter.transaction.json"
TRANSACTION_PREFIX = ".regenerate_woodsplitter."


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


def _canonical_text_bytes(data: bytes) -> bytes:
    """Return the checkout-independent UTF-8 representation used by fingerprints."""
    return data.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


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
    data = _canonical_text_bytes(path.read_bytes())
    text = data.decode("utf-8")
    return {
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "line_endings": {
            "crlf": 0,
            "bare_lf": text.count("\n"),
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


def _path_count(value: Any, relative: str) -> int:
    if isinstance(value, dict):
        return int(value.get("path") == relative) + sum(
            _path_count(child, relative) for child in value.values()
        )
    if isinstance(value, list):
        return sum(_path_count(child, relative) for child in value)
    return 0


def _replace_owned_text(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {key: _replace_owned_text(child, replacements) for key, child in value.items()}
    if isinstance(value, list):
        return [_replace_owned_text(child, replacements) for child in value]
    if isinstance(value, str):
        for old, new in replacements.items():
            value = value.replace(old, new)
    return value


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
        "numbers": "vanilla anchors prove tree damage x1.5 and calculateCombatSpeed consumption of the Axeman 1.0-versus-0.8 chop-speed branch; later modifiers prevent an exact final animation-ratio claim",
        "cadence": "no custom cadence or periodic handler",
        "cooldown": "no cooldown",
        "reset_save_load": "no custom state, migration, or save hook",
        "java_lua": "no custom Java-Lua calls; parser and vanilla consumers are source-anchored",
        "kahlua": "comment-only Lua contains no executable Kahlua behavior",
        "events": "no custom event registration",
        "stacking_interactions": "one set-like Axeman grant; selection exclusions prevent separate stacking",
        "multiplayer": "DisabledInMultiplayer=true; MP support remains a non-goal",
        "display": "English display resolves to Wood Splitter",
        "description": "copy states +1 Axe, 50% bonus tree damage, faster axe attacks, key-ring eligibility, and source exclusivity without an unsupported final timing ratio",
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
        "PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:10317",
        "PZCodebase/Media/media/scripts/generated/characters/character_professions.txt:125",
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
    source_rows = artifact["provenance"]["current_on_disk_sources"]["source"]
    release_rows = artifact["provenance"]["current_on_disk_sources"]["release"]
    source_row = _exactly_one(source_rows, "path", SOURCE_UI, f"{relative} source")
    release_row = _exactly_one(release_rows, "path", RELEASE_UI, f"{relative} release")
    if any(row.get("path") == RELEASE_UI for row in source_rows):
        raise ValueError(f"{relative} cross-owned release path in source records")
    if any(row.get("path") == SOURCE_UI for row in release_rows):
        raise ValueError(f"{relative} cross-owned source path in release records")
    source_row.update({key: value for key, value in _fingerprint(plan.root / SOURCE_UI).items() if key in source_row})
    release_row.update({key: value for key, value in _fingerprint(plan.root / RELEASE_UI).items() if key in release_row})
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
    source_matches = _path_count(inventory, SOURCE_UI)
    release_matches = _path_count(inventory, RELEASE_UI)
    if source_matches != 1 or release_matches != 0:
        raise ValueError(
            f"{relative} ownership mismatch: source={source_matches}, release={release_matches}"
        )
    anchors = inventory["sources"]["anchors"]
    source_anchor = _exactly_one(anchors, "path", SOURCE_UI, relative)
    if any(row.get("path") == RELEASE_UI for row in anchors):
        raise ValueError(f"{relative} cross-owned release path")
    source_anchor.update(
        {key: value for key, value in _fingerprint(plan.root / SOURCE_UI).items() if key in source_anchor}
    )
    plan.write_json(relative, inventory)
    return review


def _update_change_impact(plan: Plan) -> None:
    relative = "change-impact/woodsplitter-axeman-alias-resolution.json"
    artifact = plan.json(relative)
    artifact = _replace_owned_text(
        artifact,
        {
            "Axe attack-time result x0.95": "HandWeapon getSpeedMod Axeman branch is not production-consumed",
            "attack-time x0.95": "no production getSpeedMod consumer",
            "general axe combat speed 1.0 versus 0.8": (
                "calculateCombatSpeed consumes the Axeman getChopTreeSpeed branch; "
                "later modifiers prevent an exact final-ratio claim"
            ),
        },
    )
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
            reason="Copy now states faster axe attacks without an unsupported getSpeedMod or exact final-ratio claim.",
        )
    review = artifact["superseding_review"]
    review["current_source_assessment"] = "statically-validated-runtime-unproven"
    review["coverage"] = [
        "base:axeman alias resolution",
        "profession/direct exclusion",
        "grant retention",
        "profession-switch removal and repopulation",
        "tree damage x1.5",
        "calculateCombatSpeed consumes getChopTreeSpeed for axe attacks",
        "no production getSpeedMod consumer in current B42 Java source",
        "Lumberjack grants base:axeman",
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
    artifact = _replace_owned_text(
        artifact,
        {
            "0.95 axe attack-time multiplier": "unconsumed HandWeapon getSpeedMod Axeman branch",
            (
                "HandWeapon applies an Axeman multiplier of 0.95 inside the axe attack-time "
                "calculation, multiplicatively with the Axe-level timing table."
            ): (
                "HandWeapon defines an Axeman multiplier inside getSpeedMod, but current B42 "
                "Java source has no production caller, so it is not part of the supported contract."
            ),
            "another 0.95 timing multiplier": "an unproven getSpeedMod timing multiplier",
            "the 0.95 attack-time modifier and Axeman tree multipliers remain permanent": (
                "Axeman tree damage and faster axe attacks remain permanent"
            ),
            (
                "Vanilla Axeman is a four-consumer package: 1.5 tree damage, 0.95 axe timing, "
                "ChopTreeSpeed 1.0 versus 0.8, and pine key-ring eligibility."
            ): (
                "The supported Axeman package includes 1.5 tree damage, faster axe attacks through "
                "calculateCombatSpeed, and pine key-ring eligibility; getSpeedMod has no production caller."
            ),
            (
                "Against a controlled non-tree target, record at least 30 matched axe attack cycles "
                "per arm and compare median cycle duration; expected treatment/control ratio is approximately "
                "0.95 when other timing modifiers are held constant."
            ): (
                "Against a controlled non-tree target, record matched axe attack cycles per arm and "
                "confirm only that Axeman produces faster axe attacks; do not require an exact final ratio."
            ),
            (
                "Against a controlled non-tree target, record at least 30 matched axe attack cycles per arm "
                "and compare median cycle duration; expected treatment/control ratio is approximately 0.95 "
                "when other timing inputs are fixed."
            ): (
                "Against a controlled non-tree target, record matched axe attack cycles per arm and confirm "
                "only that Axeman produces faster axe attacks; do not require an exact final ratio."
            ),
        },
    )
    effects = artifact["effect_valuation"]
    unconsumed = _exactly_one(
        effects,
        "effect",
        "unconsumed HandWeapon getSpeedMod Axeman branch",
        relative,
    )
    unconsumed["estimated_point_value"] = {"low": 0.0, "high": 0.0}
    unconsumed["timing"] = "No supported production value is assigned while the method has no caller."
    unconsumed["quantification"] = (
        "The dormant method body is excluded from balance arithmetic and player-facing copy."
    )
    chop_speed = _exactly_one(effects, "effect", "ChopTreeSpeed 1.0 instead of 0.8", relative)
    chop_speed["mechanic"] = (
        "IsoGameCharacter.getChopTreeSpeed returns 1.0 with Axeman and 0.8 otherwise; "
        "calculateCombatSpeed consumes it for axe attacks before later modifiers."
    )
    chop_speed["timing"] = (
        "This supports the qualitative faster-axe-attacks claim, not an exact final animation ratio."
    )
    chop_speed["quantification"] = (
        "The raw branch differs by 1.0 versus 0.8, but later calculateCombatSpeed modifiers "
        "prevent treating 1.0/0.8 as the final player-observed ratio."
    )
    artifact["copy_scope"] = (
        "The 1.0 versus 0.8 getChopTreeSpeed branch is consumed by calculateCombatSpeed "
        "for axe attacks. Later modifiers also contribute, so no exact final animation ratio is claimed."
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
        ledger["source_artifact_sha256"][source_relative] = _sha256(
            _canonical_text_bytes(plan.read(source_relative))
        )
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
    report = build_recurring_pattern_report(
        utmods_root=plan.root,
        pzcodebase_root=plan.root.parent / "PZCodebase",
    )
    plan.write(relative, render_recurring_pattern_report(report).encode("utf-8"))


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
        "\n<!-- UNWAVERING-COPY-CORRECTION -->\n"
        "- UniversalTraits:UT_unwavering copy now matches the fixed EveryTenMinutes drain "
        "of 10 above a strict threshold of 10; Kahlua execution, save/reload, rendered EN, "
        "and interaction/balance observation remain runtime-unproven.\n"
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
    for index, row in enumerate(rows):
        artifact = plan.campaign / row["path"]
        raw = plan.read(row["path"]) if row["path"] in plan.planned else artifact.read_bytes()
        rows[index] = {
            "path": row["path"],
            "kind": row["kind"],
            **artifact_metadata(artifact, raw),
        }
    manifest = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "inventory_type": manifest["inventory_type"],
        "byte_contract": {
            "text": CANONICAL_TEXT_SEMANTICS,
            "text_suffixes": sorted(TEXT_ARTIFACT_SUFFIXES),
            "other": RAW_BYTE_SEMANTICS,
        },
        "required_artifacts": manifest["required_artifacts"],
        "file_count": len(rows),
        "total_bytes": sum(row["bytes"] for row in rows),
        "files": rows,
    }
    plan.write_json(relative, manifest)


def build_plan(root: Path = ROOT) -> Plan:
    plan = Plan(root)
    batch = _update_batch(plan)
    review = _update_source_records(plan)
    _update_change_impact(plan)
    _update_derived(plan, batch, review)
    with tempfile.TemporaryDirectory(prefix=TRANSACTION_PREFIX) as directory:
        queue_path = Path(directory) / "remediation_queue.jsonl"
        release_blocker_path = Path(directory) / "release_blocker_queue.json"
        queue_path.write_bytes(plan.read("remediation_queue.jsonl"))
        release_blocker_path.write_bytes(plan.read("release_blocker_queue.json"))
        update_release_blocker_queue_sha256(queue_path, release_blocker_path)
        plan.planned["release_blocker_queue.json"] = release_blocker_path.read_bytes()
    _update_pattern(plan)
    _update_master(plan)
    _update_manifest(plan)
    return plan


def _confined_transaction_path(campaign: Path, relative: str) -> Path:
    if relative not in OUTPUTS:
        raise ValueError(f"transaction contains unowned path: {relative}")
    path = (campaign / relative).resolve()
    if path.parent != (campaign / relative).parent.resolve():
        raise ValueError(f"transaction target escapes campaign: {relative}")
    return path


def _fsync_file(path: Path) -> None:
    with path.open("r+b") as stream:
        os.fsync(stream.fileno())


def _write_durable(path: Path, data: bytes) -> None:
    handle, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".write", dir=path.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
        _fsync_file(path)
    finally:
        temp.unlink(missing_ok=True)


def recover_transaction(campaign: Path) -> bool:
    """Restore exact preimages from a durable interrupted-transaction journal."""
    journal_path = campaign / JOURNAL_NAME
    if not journal_path.exists():
        return False
    journal = _load_json(journal_path.read_bytes())
    if journal.get("schema") != "regenerate_woodsplitter.transaction.v1":
        raise ValueError("unknown Wood Splitter transaction journal schema")
    entries = journal.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("invalid Wood Splitter transaction journal entries")
    relatives = [entry.get("relative") for entry in entries]
    if len(relatives) != len(set(relatives)):
        raise ValueError("duplicate paths in Wood Splitter transaction journal")

    phase = journal.get("phase")
    if phase not in {"promoting", "cleanup"}:
        raise ValueError("invalid Wood Splitter transaction phase")
    verified: list[tuple[Path, Path, Path, str, str]] = []
    for entry in entries:
        relative = entry.get("relative")
        if not isinstance(relative, str):
            raise ValueError("invalid path in Wood Splitter transaction journal")
        target = _confined_transaction_path(campaign, relative)
        stage = target.parent / f"{TRANSACTION_PREFIX}{target.name}.stage"
        backup = target.parent / f"{TRANSACTION_PREFIX}{target.name}.backup"
        if entry.get("stage") != stage.name or entry.get("backup") != backup.name:
            raise ValueError(f"transaction artifact mismatch: {relative}")
        preimage = entry.get("preimage_sha256")
        planned = entry.get("planned_sha256")
        if not isinstance(preimage, str) or not isinstance(planned, str):
            raise ValueError(f"invalid transaction hashes: {relative}")
        if phase == "promoting":
            if not backup.is_file():
                raise ValueError(f"missing transaction preimage: {relative}")
            if _sha256(backup.read_bytes()) != preimage:
                raise ValueError(f"transaction preimage hash mismatch: {relative}")
        verified.append((target, stage, backup, preimage, planned))

    if phase == "promoting":
        for target, _stage, backup, preimage, _planned in verified:
            _write_durable(target, backup.read_bytes())
            if _sha256(target.read_bytes()) != preimage:
                raise RuntimeError(f"transaction recovery verification failed: {target}")
    else:
        for target, _stage, _backup, _preimage, planned in verified:
            if not target.is_file() or _sha256(target.read_bytes()) != planned:
                raise RuntimeError(f"committed transaction target hash mismatch: {target}")
    for _target, stage, backup, _preimage, _planned in verified:
        stage.unlink(missing_ok=True)
        backup.unlink(missing_ok=True)
    journal_path.unlink()
    return True


def commit_transaction(
    plan: Plan,
    replace: Callable[[str | os.PathLike[str], str | os.PathLike[str]], None] = os.replace,
) -> list[str]:
    """Promote changed outputs using a durable, always-rollback recovery journal."""
    recover_transaction(plan.campaign)
    changed = [relative for relative in OUTPUTS if plan.planned[relative] != plan.original[relative]]
    if not changed:
        return []
    journal_path = plan.campaign / JOURNAL_NAME
    entries: list[dict[str, str]] = []
    try:
        for relative in changed:
            path = _confined_transaction_path(plan.campaign, relative)
            stage = path.parent / f"{TRANSACTION_PREFIX}{path.name}.stage"
            backup = path.parent / f"{TRANSACTION_PREFIX}{path.name}.backup"
            if stage.exists() or backup.exists():
                raise ValueError(f"orphan transaction artifact exists: {relative}")
            _write_durable(stage, plan.planned[relative])
            _write_durable(backup, plan.original[relative])
            entries.append(
                {
                    "relative": relative,
                    "stage": stage.name,
                    "backup": backup.name,
                    "preimage_sha256": _sha256(plan.original[relative]),
                    "planned_sha256": _sha256(plan.planned[relative]),
                }
            )
        _write_durable(
            journal_path,
            _json_bytes(
                {"schema": "regenerate_woodsplitter.transaction.v1", "phase": "promoting", "entries": entries},
                sort_keys=True,
            ),
        )
        for relative in changed:
            path = _confined_transaction_path(plan.campaign, relative)
            stage = path.parent / f"{TRANSACTION_PREFIX}{path.name}.stage"
            replace(stage, path)
            _fsync_file(path)
        _write_durable(
            journal_path,
            _json_bytes(
                {"schema": "regenerate_woodsplitter.transaction.v1", "phase": "cleanup", "entries": entries},
                sort_keys=True,
            ),
        )
        for entry in entries:
            path = _confined_transaction_path(plan.campaign, entry["relative"])
            (path.parent / entry["backup"]).unlink()
        journal_path.unlink()
        return changed
    except BaseException:
        if journal_path.exists():
            recover_transaction(plan.campaign)
        else:
            for entry in entries:
                path = _confined_transaction_path(plan.campaign, entry["relative"])
                (path.parent / entry["stage"]).unlink(missing_ok=True)
                (path.parent / entry["backup"]).unlink(missing_ok=True)
        raise


def main() -> int:
    cli_result = no_arg_command(sys.argv, "Usage: py -3 regenerate_woodsplitter.py")
    if cli_result is not None:
        return cli_result
    try:
        recover_transaction(CAMPAIGN)
        plan = build_plan()
        changed = commit_transaction(plan)
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "trait_id": TRAIT, "changed": changed}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
