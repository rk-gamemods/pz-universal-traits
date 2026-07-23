"""Safety tests for the Weakly Bleeding Wounds campaign generator."""

from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


CAMPAIGN = Path(__file__).resolve().parents[1]
TOOLS = CAMPAIGN / "tools"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location(
    "regenerate_weaklybleedingwounds",
    TOOLS / "regenerate_weaklybleedingwounds.py",
)
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def _all_files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file()
    }


def _jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line
    ]


class WeaklyBleedingWoundsGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(
            CAMPAIGN,
            self.campaign,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        )
        source_root = CAMPAIGN.parents[1]
        for relative in (
            GENERATOR.RUNTIME,
            GENERATOR.RELEASE,
            GENERATOR.SOURCE_UI,
            GENERATOR.RELEASE_UI,
            GENERATOR.SOURCE_DEFINITION,
            GENERATOR.RELEASE_DEFINITION,
            GENERATOR.SOURCE_MET,
            GENERATOR.RELEASE_MET,
            GENERATOR.MOCKS,
            GENERATOR.TESTS,
            GENERATOR.CORE_HOOK,
            GENERATOR.CORE_HOOK_RELEASE,
            GENERATOR.CORE_STAT,
            GENERATOR.CORE_STAT_RELEASE,
            GENERATOR.CORE_TESTS,
            GENERATOR.ACTIVE_AUDIT,
        ):
            source = source_root / relative
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _run(self) -> list[str]:
        return GENERATOR.commit_plan(
            GENERATOR.build_plan(self.root, self.campaign), self.campaign
        )

    def test_plan_owns_only_declared_outputs(self) -> None:
        self.assertEqual(
            set(GENERATOR.build_plan(self.root, self.campaign)),
            set(GENERATOR.OWNED_OUTPUTS),
        )

    def test_base_generator_configuration_is_restored(self) -> None:
        before = {
            name: getattr(GENERATOR.base, name)
            for name in (
                "TRAIT",
                "FINDINGS",
                "_plan_batch",
                "_plan_review",
                "OWNED_OUTPUTS",
            )
        }
        GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(
            {name: getattr(GENERATOR.base, name) for name in before}, before
        )

    def test_non_target_records_remain_unchanged(self) -> None:
        batch_path = self.campaign / "trait_batches" / "batch_12.jsonl"
        review_path = self.campaign / "independent_reviews" / "traits_09_12.json"
        before_batch = [
            row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_review = [
            row
            for row in json.loads(review_path.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]

        self._run()

        self.assertEqual(
            [
                row
                for row in _jsonl(batch_path)
                if row["trait_id"] != GENERATOR.TRAIT
            ],
            before_batch,
        )
        self.assertEqual(
            [
                row
                for row in json.loads(review_path.read_bytes())["per_trait_review"]
                if row["trait_id"] != GENERATOR.TRAIT
            ],
            before_review,
        )

    def test_resolution_closes_all_three_findings_and_preserves_runtime_gaps(self) -> None:
        self._run()
        artifact = json.loads(
            (self.campaign / "independent_reviews" / "traits_09_12.json").read_bytes()
        )
        shared = next(
            item
            for item in artifact["cross_trait_findings"]
            if item["id"] == GENERATOR.FINDINGS[2]
        )
        self.assertEqual(shared["state"], "proven-correct")

        review = next(
            row
            for row in artifact["per_trait_review"]
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(
            {item["id"]: item["state"] for item in review["omissions"]},
            {
                GENERATOR.FINDINGS[0]: "proven-correct",
                GENERATOR.FINDINGS[1]: "proven-correct",
            },
        )
        self.assertEqual(review["repair_resolution"]["open_finding_ids"], [])

        queue = [
            row
            for row in _jsonl(self.campaign / "remediation_queue.jsonl")
            if row.get("trait_id") == GENERATOR.TRAIT
            or row.get("finding_id") == GENERATOR.FINDINGS[2]
        ]
        self.assertEqual(
            [row for row in queue if row.get("subject_type") == "finding"], []
        )
        self.assertEqual(
            {
                row["dimension"]
                for row in queue
                if row.get("trait_id") == GENERATOR.TRAIT
                and row.get("subject_type") == "trait-dimension"
            },
            {
                "definition_parser",
                "reset_save_load",
                "kahlua",
                "localization",
                "balance",
                "performance",
                "packaging",
            },
        )

    def test_second_pass_is_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)

    def test_duplicate_target_record_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_12.jsonl"
        rows = _jsonl(batch)
        target = next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT)
        batch.write_text(
            "".join(
                json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
                for row in rows + [target]
            ),
            encoding="utf-8",
            newline="\n",
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)


if __name__ == "__main__":
    unittest.main()
