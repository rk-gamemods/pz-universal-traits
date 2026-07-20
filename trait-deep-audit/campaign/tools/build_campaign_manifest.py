"""Build the deterministic content manifest for the completed audit campaign."""

from __future__ import annotations

import hashlib
import json
import sys
from collections.abc import Iterable, Sequence
from pathlib import Path

from campaign_cli import no_arg_command


CAMPAIGN_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = CAMPAIGN_ROOT / "campaign_manifest.json"
MANIFEST_SCHEMA_VERSION = "1.1.0"
TEXT_ARTIFACT_SUFFIXES = frozenset({".json", ".jsonl", ".md", ".py"})
CANONICAL_TEXT_SEMANTICS = "utf-8-lf"
RAW_BYTE_SEMANTICS = "raw"
REQUIRED_ARTIFACTS = (
    "MASTER_COVERAGE_LEDGER.md",
    "dimension_ledger_rows.jsonl",
    "final_trait_ledger.json",
    "final_trait_ledger_rows.jsonl",
    "remediation_queue.jsonl",
    "remediation_summary.json",
    "recurring_pattern_findings.json",
    "source_inventory.json",
    "translation_audit.json",
    *(f"trait_batches/batch_{number:02d}.jsonl" for number in range(1, 13)),
    "independent_reviews/traits_01_04.json",
    "independent_reviews/traits_05_08.json",
    "independent_reviews/traits_09_12.json",
    "independent_reviews/ut_core_integration.json",
    "independent_reviews/toolchain_semantic_impact.json",
    "independent_reviews/documentation_localization_skills.json",
)


def file_kind(relative_path: str) -> str:
    """Return a stable, coarse artifact class for one campaign file."""
    path = Path(relative_path)
    if path.parts[0] == "trait_batches":
        return "trait-batch"
    if path.parts[0] == "independent_reviews":
        return "independent-review"
    if path.parts[0] == "tools":
        return "deterministic-tool"
    if path.parts[0] == "tests":
        return "regression-test"
    if relative_path == "MASTER_COVERAGE_LEDGER.md":
        return "master-ledger"
    if relative_path.startswith("final_trait_ledger"):
        return "normalized-ledger"
    if relative_path == "dimension_ledger_rows.jsonl":
        return "normalized-dimension-ledger"
    if relative_path.startswith("remediation_"):
        return "remediation-queue"
    if relative_path == "source_inventory.json":
        return "source-inventory"
    if relative_path == "translation_audit.json":
        return "translation-audit"
    if relative_path == "recurring_pattern_findings.json":
        return "recurring-pattern-report"
    return "campaign-artifact"


def campaign_files(root: Path) -> list[Path]:
    """Return all stable campaign files except the self-referential manifest."""
    files = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if path == root / OUTPUT_PATH.name:
            continue
        if "__pycache__" in relative.parts or path.suffix == ".pyc":
            continue
        files.append(path)
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def artifact_byte_semantics(path: Path) -> str:
    """Return the explicit byte contract used for one artifact type."""
    return CANONICAL_TEXT_SEMANTICS if path.suffix.lower() in TEXT_ARTIFACT_SUFFIXES else RAW_BYTE_SEMANTICS


def canonical_artifact_bytes(path: Path, content: bytes | None = None) -> bytes:
    """Return bytes hashed by the manifest, independent of text checkout EOLs."""
    raw = path.read_bytes() if content is None else content
    if artifact_byte_semantics(path) == RAW_BYTE_SEMANTICS:
        return raw
    return raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def artifact_metadata(path: Path, content: bytes | None = None) -> dict[str, object]:
    """Return the versioned manifest metadata for one text or raw artifact."""
    canonical = canonical_artifact_bytes(path, content)
    return {
        "byte_semantics": artifact_byte_semantics(path),
        "bytes": len(canonical),
        "sha256": hashlib.sha256(canonical).hexdigest().upper(),
    }


def build_manifest(
    root: Path = CAMPAIGN_ROOT,
    required_artifacts: Iterable[str] = REQUIRED_ARTIFACTS,
) -> dict[str, object]:
    """Build the manifest and fail if any required campaign artifact is absent."""
    required = tuple(sorted(required_artifacts))
    missing = [path for path in required if not (root / Path(path)).is_file()]
    if missing:
        raise FileNotFoundError(f"missing required campaign artifacts: {', '.join(missing)}")

    rows = []
    for path in campaign_files(root):
        relative = path.relative_to(root).as_posix()
        rows.append(
            {
                "path": relative,
                "kind": file_kind(relative),
                **artifact_metadata(path),
            }
        )

    return {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "inventory_type": "closed-world campaign content manifest",
        "byte_contract": {
            "text": CANONICAL_TEXT_SEMANTICS,
            "text_suffixes": sorted(TEXT_ARTIFACT_SUFFIXES),
            "other": RAW_BYTE_SEMANTICS,
        },
        "required_artifacts": list(required),
        "file_count": len(rows),
        "total_bytes": sum(row["bytes"] for row in rows),
        "files": rows,
    }


def render_manifest(manifest: dict[str, object]) -> str:
    """Render canonical UTF-8 JSON with a terminal newline."""
    return json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"


def main(argv: Sequence[str] = sys.argv) -> int:
    cli_result = no_arg_command(
        argv,
        "Usage: py -3 build_campaign_manifest.py",
    )
    if cli_result is not None:
        return cli_result
    try:
        rendered = render_manifest(build_manifest())
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    OUTPUT_PATH.write_text(rendered, encoding="utf-8", newline="\n")
    print(
        json.dumps(
            {
                "ok": True,
                "files": json.loads(rendered)["file_count"],
                "output": str(OUTPUT_PATH),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
