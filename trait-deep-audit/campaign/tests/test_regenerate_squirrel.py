"""Focused safety tests for the Squirrel campaign generator."""

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
SPEC = importlib.util.spec_from_file_location("regenerate_squirrel", TOOLS / "regenerate_squirrel.py")
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def files(root: Path) -> dict[str, bytes]:
    return {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class SquirrelGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        for relative in (
            GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.SOURCE_UI, GENERATOR.RELEASE_UI,
            GENERATOR.SOURCE_DEFINITION, GENERATOR.RELEASE_DEFINITION, GENERATOR.SOURCE_REGISTRY,
            GENERATOR.RELEASE_REGISTRY, GENERATOR.MOCKS, GENERATOR.TESTS, GENERATOR.ACTIVE_AUDIT,
        ):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_generator(self) -> list[str]:
        return GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign)

    def test_exact_ownership_and_shared_base_restoration(self) -> None:
        before = {name: getattr(GENERATOR.base, name) for name in ("TRAIT", "FINDINGS", "_plan_batch", "_plan_review", "OWNED_OUTPUTS")}
        self.assertEqual(set(GENERATOR.build_plan(self.root, self.campaign)), set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual({name: getattr(GENERATOR.base, name) for name in before}, before)

    def test_preserves_non_target_batch_and_review_records(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        before_batch = [row for row in jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT]
        before_review = [row for row in json.loads(review.read_bytes())["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT]
        self.run_generator()
        self.assertEqual([row for row in jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT], before_batch)
        self.assertEqual([row for row in json.loads(review.read_bytes())["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT], before_review)

    def test_duplicate_batch_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        rows = jsonl(batch)
        target = next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT)
        batch.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows + [target]), encoding="utf-8")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_duplicate_review_is_rejected_without_writes(self) -> None:
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        artifact = json.loads(review.read_bytes())
        target = next(row for row in artifact["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT)
        artifact["per_trait_review"].append(target)
        review.write_text(json.dumps(artifact), encoding="utf-8")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_fixed_point_and_runtime_proof_preservation(self) -> None:
        self.run_generator()
        first = files(self.campaign)
        self.assertEqual(self.run_generator(), [])
        self.assertEqual(files(self.campaign), first)
        batch = next(row for row in jsonl(self.campaign / "trait_batches" / "batch_11.jsonl") if row["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(batch["overall_state"], "runtime-unproven")
        self.assertEqual([finding["resolution_state"] for finding in batch["findings"]], ["proven-correct", "proven-correct"])
        self.assertEqual(batch["dimensions"]["kahlua"]["state"], "runtime-unproven")
        self.assertEqual(batch["dimensions"]["balance"]["state"], "runtime-unproven")
        self.assertIn("fast-forward", " ".join(batch["unknowns"]))


if __name__ == "__main__":
    unittest.main()
