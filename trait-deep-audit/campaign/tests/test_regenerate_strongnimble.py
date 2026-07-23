"""Safety tests for the Strong and Nimble campaign generator."""

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
    "regenerate_strongnimble", TOOLS / "regenerate_strongnimble.py"
)
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def _files(root: Path) -> dict[str, bytes]:
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


class StrongAndNimbleGeneratorSafetyTests(unittest.TestCase):
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
            GENERATOR.MOCKS,
            GENERATOR.TESTS,
            GENERATOR.ACTIVE_AUDIT,
            GENERATOR.VERIFIER,
            GENERATOR.VERIFIER_TESTS,
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

    def test_base_configuration_is_restored(self) -> None:
        names = (
            "TRAIT",
            "FINDINGS",
            "DESCRIPTION",
            "RUNTIME",
            "RELEASE",
            "SOURCE_UI",
            "RELEASE_UI",
            "SOURCE_DEFINITION",
            "RELEASE_DEFINITION",
            "MOCKS",
            "TESTS",
            "ACTIVE_AUDIT",
            "RESOLUTION",
            "OWNED_OUTPUTS",
            "_plan_batch",
            "_plan_review",
            "_plan_resolution",
        )
        before = {name: getattr(GENERATOR.base, name) for name in names}
        GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(
            before, {name: getattr(GENERATOR.base, name) for name in names}
        )

    def test_non_target_batch_and_review_rows_are_unchanged(self) -> None:
        batch_path = self.campaign / "trait_batches" / "batch_11.jsonl"
        before_batch = [
            line
            for line in batch_path.read_bytes().splitlines(keepends=True)
            if json.loads(line)["trait_id"] != GENERATOR.TRAIT
        ]
        review_path = self.campaign / "independent_reviews" / "traits_09_12.json"
        before_review = {
            row["trait_id"]: json.dumps(
                row, ensure_ascii=False, separators=(",", ":")
            ).encode("utf-8")
            for row in json.loads(review_path.read_text(encoding="utf-8"))[
                "per_trait_review"
            ]
            if row["trait_id"] != GENERATOR.TRAIT
        }
        self._run()
        after_batch = [
            line
            for line in batch_path.read_bytes().splitlines(keepends=True)
            if json.loads(line)["trait_id"] != GENERATOR.TRAIT
        ]
        after_review = {
            row["trait_id"]: json.dumps(
                row, ensure_ascii=False, separators=(",", ":")
            ).encode("utf-8")
            for row in json.loads(review_path.read_text(encoding="utf-8"))[
                "per_trait_review"
            ]
            if row["trait_id"] != GENERATOR.TRAIT
        }
        self.assertEqual(before_batch, after_batch)
        self.assertEqual(before_review, after_review)

    def test_resolution_closes_static_defects_and_preserves_runtime_gaps(self) -> None:
        self._run()
        row = next(
            row
            for row in _jsonl(
                self.campaign / "trait_batches" / "batch_11.jsonl"
            )
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(row["overall_state"], "runtime-unproven")
        self.assertEqual(
            row["findings"][0]["resolution_state"], "proven-correct"
        )
        self.assertEqual(row["dimensions"]["runtime_path"]["state"], "proven-correct")
        self.assertEqual(row["dimensions"]["java_lua"]["state"], "proven-correct")
        self.assertEqual(
            row["dimensions"]["source_intent"]["state"], "runtime-unproven"
        )
        self.assertEqual(row["dimensions"]["kahlua"]["state"], "runtime-unproven")
        resolution = json.loads(
            (self.campaign / GENERATOR.RESOLUTION).read_text(encoding="utf-8")
        )
        self.assertEqual(
            resolution["resolved_findings"],
            [*GENERATOR.FINDINGS, "IR11-STRONGNIMBLE-001"],
        )
        self.assertEqual(resolution["accepted_intent"]["cost"], 5)
        self.assertEqual(
            resolution["accepted_intent"]["xp_boosts"],
            {"Nimble": 2, "Strength": 1},
        )
        self.assertEqual(
            resolution["accepted_intent"]["pending_semantic_decision"],
            "forced fall after physical rope removal",
        )

    def test_second_pass_is_fixed_point(self) -> None:
        self._run()
        before = _files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(before, _files(self.campaign))

    def test_duplicate_target_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        target = next(
            line
            for line in batch.read_text(encoding="utf-8").splitlines()
            if json.loads(line)["trait_id"] == GENERATOR.TRAIT
        )
        batch.write_text(
            batch.read_text(encoding="utf-8") + target + "\n", encoding="utf-8"
        )
        before = _files(self.campaign)
        with self.assertRaises(ValueError):
            GENERATOR.commit_plan(
                GENERATOR.build_plan(self.root, self.campaign), self.campaign
            )
        self.assertEqual(before, _files(self.campaign))

    def test_duplicate_review_target_is_rejected_without_writes(self) -> None:
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        artifact = json.loads(review.read_text(encoding="utf-8"))
        target = next(
            row
            for row in artifact["per_trait_review"]
            if row["trait_id"] == GENERATOR.TRAIT
        )
        artifact["per_trait_review"].append(target)
        review.write_text(
            json.dumps(artifact, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        before = _files(self.campaign)
        with self.assertRaises(ValueError):
            GENERATOR.commit_plan(
                GENERATOR.build_plan(self.root, self.campaign), self.campaign
            )
        self.assertEqual(before, _files(self.campaign))


if __name__ == "__main__":
    unittest.main()
