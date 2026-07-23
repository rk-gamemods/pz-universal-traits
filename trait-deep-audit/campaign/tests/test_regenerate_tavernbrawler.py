"""Focused safety tests for the Tavern Brawler campaign generator."""

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
SPEC = importlib.util.spec_from_file_location("regenerate_tavernbrawler", TOOLS / "regenerate_tavernbrawler.py")
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def files(root: Path) -> dict[str, bytes]:
    return {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class TavernBrawlerGeneratorSafetyTests(unittest.TestCase):
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
        names = ("TRAIT", "FINDINGS", "_plan_batch", "_plan_review", "OWNED_OUTPUTS")
        before = {name: getattr(GENERATOR.base, name) for name in names}
        self.assertEqual(set(GENERATOR.build_plan(self.root, self.campaign)), set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual({name: getattr(GENERATOR.base, name) for name in names}, before)

    def test_non_target_batch_and_review_records_are_preserved(self) -> None:
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
        rows.append(next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT))
        batch.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows), encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_duplicate_review_is_rejected_without_writes(self) -> None:
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        artifact = json.loads(review.read_bytes())
        artifact["per_trait_review"].append(next(row for row in artifact["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT))
        review.write_text(json.dumps(artifact), encoding="utf-8")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_fixed_point_and_retained_runtime_proof(self) -> None:
        self.run_generator()
        first = files(self.campaign)
        self.assertEqual(self.run_generator(), [])
        self.assertEqual(files(self.campaign), first)
        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        row = next(item for item in ledger["traits"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(row["overall_state"], "runtime-unproven")
        self.assertTrue(any("Kahlua" in value for value in row["unknowns"]))
        dimensions = {item["dimension"] for item in jsonl(self.campaign / "remediation_queue.jsonl") if item.get("trait_id") == GENERATOR.TRAIT and item.get("subject_type") == "trait-dimension"}
        self.assertTrue({"kahlua", "reset_save_load", "balance", "performance", "packaging"}.issubset(dimensions))


if __name__ == "__main__":
    unittest.main()
