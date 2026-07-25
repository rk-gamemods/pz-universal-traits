"""Build a compact, source-derived review catalog for all UniversalTraits."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from .paths import (
    DEFINITION_PATH,
    FINAL_LEDGER_ROWS_PATH,
    REGISTRY_PATH,
    RELEASE_BLOCKER_PATH,
    REMEDIATION_QUEUE_PATH,
    RUNTIME_TRAIT_ROOT,
    TRANSLATION_PATH,
    UTMODS_ROOT,
)

DEFINITION_RE = re.compile(
    r"^\s*character_trait_definition\s+(?P<trait_id>UniversalTraits:UT_[A-Za-z0-9_]+)"
    r"\s*\{\s*(?P<body>.*?)^\s*\}",
    re.MULTILINE | re.DOTALL,
)
PROPERTY_RE = re.compile(
    r"^\s*(?P<key>[A-Za-z][A-Za-z0-9_]*)\s*=\s*(?P<value>.*?)\s*,\s*$",
    re.MULTILINE,
)
REGISTRATION_RE = re.compile(
    r'CharacterTrait\.register\("(?P<trait_id>UniversalTraits:UT_[A-Za-z0-9_]+)"\)'
)
EVENT_RE = re.compile(r"\bEvents\.([A-Za-z0-9_]+)\.Add\s*\(")
UTCORE_RE = re.compile(r"\b(UTCore(?:_[A-Za-z0-9_]+|\.[A-Za-z0-9_.]+))")

CSV_FIELDS = (
    "trait_id",
    "short_id",
    "name",
    "description",
    "cost",
    "xp_boosts",
    "granted_traits",
    "mutual_exclusions",
    "registered",
    "runtime_file",
    "events",
    "utcore_references",
    "audit_state",
    "audit_batch",
    "open_evidence_records",
    "open_evidence_states",
    "release_blockers",
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load_json(path: Path, default: Any) -> Any:
    if not path.is_file():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{number} is not a JSON object")
        rows.append(value)
    return rows


def _split_semicolon(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in value.split(";") if item.strip()]


def _definition_rows(path: Path) -> tuple[list[dict[str, Any]], list[str]]:
    text = path.read_text(encoding="utf-8")
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    seen: set[str] = set()
    for match in DEFINITION_RE.finditer(text):
        trait_id = match.group("trait_id")
        if trait_id in seen:
            errors.append(f"duplicate trait definition: {trait_id}")
        seen.add(trait_id)
        properties = {
            item.group("key"): item.group("value").strip()
            for item in PROPERTY_RE.finditer(match.group("body"))
        }
        if properties.get("CharacterTrait") != trait_id:
            errors.append(f"{trait_id}: CharacterTrait does not match block identity")
        try:
            cost = int(properties["Cost"])
        except (KeyError, ValueError):
            errors.append(f"{trait_id}: Cost is missing or not an integer")
            cost = None
        rows.append(
            {
                "trait_id": trait_id,
                "cost": cost,
                "ui_name_key": properties.get("UIName"),
                "ui_description_key": properties.get("UIDescription"),
                "xp_boosts": properties.get("XPBoosts", ""),
                "granted_traits": _split_semicolon(properties.get("GrantedTraits")),
                "mutual_exclusions": _split_semicolon(
                    properties.get("MutuallyExclusiveTraits")
                ),
                "disabled_in_multiplayer": properties.get(
                    "DisabledInMultiplayer"
                ),
                "is_profession_trait": properties.get("IsProfessionTrait"),
            }
        )
    if not rows:
        errors.append(f"no trait definitions parsed from {path}")
    return rows, errors


def _runtime_metadata(short_id: str) -> dict[str, Any]:
    path = RUNTIME_TRAIT_ROOT / f"{short_id}.lua"
    if not path.is_file():
        return {
            "runtime_file": "",
            "runtime_sha256": "",
            "events": [],
            "utcore_references": [],
        }
    text = path.read_text(encoding="utf-8")
    return {
        "runtime_file": path.relative_to(UTMODS_ROOT).as_posix(),
        "runtime_sha256": _sha256(path),
        "events": sorted(set(EVENT_RE.findall(text))),
        "utcore_references": sorted(set(UTCORE_RE.findall(text))),
    }


def build_catalog(root: Path = UTMODS_ROOT) -> dict[str, Any]:
    """Compile one review row per source definition without changing trait intent."""
    if root != UTMODS_ROOT:
        definition_path = root / DEFINITION_PATH.relative_to(UTMODS_ROOT)
        registry_path = root / REGISTRY_PATH.relative_to(UTMODS_ROOT)
        translation_path = root / TRANSLATION_PATH.relative_to(UTMODS_ROOT)
        ledger_path = root / FINAL_LEDGER_ROWS_PATH.relative_to(UTMODS_ROOT)
        queue_path = root / REMEDIATION_QUEUE_PATH.relative_to(UTMODS_ROOT)
        blocker_path = root / RELEASE_BLOCKER_PATH.relative_to(UTMODS_ROOT)
    else:
        definition_path = DEFINITION_PATH
        registry_path = REGISTRY_PATH
        translation_path = TRANSLATION_PATH
        ledger_path = FINAL_LEDGER_ROWS_PATH
        queue_path = REMEDIATION_QUEUE_PATH
        blocker_path = RELEASE_BLOCKER_PATH

    definitions, errors = _definition_rows(definition_path)
    translations = _load_json(translation_path, {})
    if not isinstance(translations, dict):
        raise ValueError(f"{translation_path} must contain one JSON object")
    registration_text = registry_path.read_text(encoding="utf-8")
    registrations = REGISTRATION_RE.findall(registration_text)
    duplicate_registrations = sorted(
        item for item, count in Counter(registrations).items() if count > 1
    )
    if duplicate_registrations:
        errors.append(f"duplicate registrations: {duplicate_registrations}")
    registration_set = set(registrations)

    ledger_rows = {
        row["trait_id"]: row for row in _load_jsonl(ledger_path) if row.get("trait_id")
    }
    queue_by_trait: dict[str, list[dict[str, Any]]] = defaultdict(list)
    queue_by_id: dict[str, dict[str, Any]] = {}
    for row in _load_jsonl(queue_path):
        queue_id = row.get("queue_id")
        if isinstance(queue_id, str):
            queue_by_id[queue_id] = row
        trait_id = row.get("trait_id")
        if isinstance(trait_id, str):
            queue_by_trait[trait_id].append(row)

    blocker_by_queue_id: dict[str, set[str]] = defaultdict(set)
    blocker_value = _load_json(blocker_path, {})
    for identity in blocker_value.get("identities", []):
        semantic_identity = identity.get("semantic_identity")
        if not isinstance(semantic_identity, str):
            continue
        for queue_id in identity.get("queue_ids", []):
            if isinstance(queue_id, str):
                blocker_by_queue_id[queue_id].add(semantic_identity)

    rows = []
    definition_ids = {row["trait_id"] for row in definitions}
    for definition in sorted(definitions, key=lambda row: row["trait_id"]):
        trait_id = definition["trait_id"]
        short_id = trait_id.split(":", 1)[1]
        name_key = definition["ui_name_key"]
        description_key = definition["ui_description_key"]
        if not isinstance(name_key, str) or name_key not in translations:
            errors.append(f"{trait_id}: missing UI name translation for {name_key}")
        if not isinstance(description_key, str) or description_key not in translations:
            errors.append(
                f"{trait_id}: missing UI description translation for {description_key}"
            )
        ledger = ledger_rows.get(trait_id, {})
        open_rows = queue_by_trait.get(trait_id, [])
        blocker_identities = sorted(
            {
                identity
                for queue_row in open_rows
                for identity in blocker_by_queue_id.get(
                    str(queue_row.get("queue_id")), set()
                )
            }
        )
        rows.append(
            {
                **definition,
                "short_id": short_id,
                "name": translations.get(name_key, ""),
                "description": translations.get(description_key, ""),
                "registered": trait_id in registration_set,
                **_runtime_metadata(short_id),
                "audit_state": ledger.get("overall_state", ""),
                "audit_batch": ledger.get("batch", ""),
                "open_evidence_records": len(open_rows),
                "open_evidence_states": dict(
                    sorted(Counter(str(row.get("state")) for row in open_rows).items())
                ),
                "release_blockers": blocker_identities,
            }
        )

    for trait_id in sorted(definition_ids - registration_set):
        errors.append(f"definition is not registered: {trait_id}")
    for trait_id in sorted(registration_set - definition_ids):
        errors.append(f"registration has no definition: {trait_id}")
    for trait_id in sorted(definition_ids - set(ledger_rows)):
        errors.append(f"definition has no final-ledger row: {trait_id}")
    for queue_id in sorted(blocker_by_queue_id):
        if queue_id not in queue_by_id:
            errors.append(f"release blocker references missing queue row: {queue_id}")

    return {
        "schema_version": "utmods.trait_catalog.v1",
        "catalog_type": "generated-review-view",
        "authority": {
            "editable_trait_definition": DEFINITION_PATH.relative_to(
                UTMODS_ROOT
            ).as_posix(),
            "editable_english_ui": TRANSLATION_PATH.relative_to(
                UTMODS_ROOT
            ).as_posix(),
            "registration": REGISTRY_PATH.relative_to(UTMODS_ROOT).as_posix(),
            "note": "This catalog is generated. Edit the owning source, then rebuild.",
        },
        "source_sha256": {
            DEFINITION_PATH.relative_to(UTMODS_ROOT).as_posix(): _sha256(
                definition_path
            ),
            REGISTRY_PATH.relative_to(UTMODS_ROOT).as_posix(): _sha256(
                registry_path
            ),
            TRANSLATION_PATH.relative_to(UTMODS_ROOT).as_posix(): _sha256(
                translation_path
            ),
        },
        "counts": {
            "definitions": len(definitions),
            "registrations": len(registration_set),
            "translation_keys": len(translations),
            "audit_rows": len(ledger_rows),
            "rows": len(rows),
            "integrity_errors": len(errors),
        },
        "integrity_errors": sorted(set(errors)),
        "traits": rows,
    }


def render_catalog_json(catalog: dict[str, Any]) -> bytes:
    return (
        json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    ).encode("utf-8")


def _csv_value(value: Any) -> str | int:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, dict):
        return "; ".join(f"{key}={value[key]}" for key in sorted(value))
    if isinstance(value, list):
        return "; ".join(str(item) for item in value)
    if value is None:
        return ""
    return value


def render_catalog_csv(catalog: dict[str, Any]) -> bytes:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS, lineterminator="\n")
    writer.writeheader()
    for row in catalog["traits"]:
        writer.writerow({field: _csv_value(row.get(field)) for field in CSV_FIELDS})
    return stream.getvalue().encode("utf-8")
