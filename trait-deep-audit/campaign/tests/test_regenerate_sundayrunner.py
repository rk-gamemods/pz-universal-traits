"""Focused safety tests for the Sunday Runner campaign generator."""

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


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GENERATOR = load("regenerate_sundayrunner")
TAVERN = load("regenerate_tavernbrawler")


def files(root: Path) -> dict[str, bytes]:
    return {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class SundayRunnerGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        required = {
            GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.SOURCE_UI, GENERATOR.RELEASE_UI,
            GENERATOR.SOURCE_DEFINITION, GENERATOR.RELEASE_DEFINITION, GENERATOR.SOURCE_REGISTRY,
            GENERATOR.RELEASE_REGISTRY, GENERATOR.MOCKS, GENERATOR.TESTS, GENERATOR.ACTIVE_AUDIT,
            GENERATOR.PRD,
            TAVERN.RUNTIME, TAVERN.RELEASE, TAVERN.ACTIVE_AUDIT,
        }
        for relative in required:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_generator(self) -> list[str]:
        return GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign)

    def test_exact_owned_output_set_and_configuration_restoration(self) -> None:
        names = ("TRAIT", "FINDINGS", "_plan_batch", "_plan_review", "OWNED_OUTPUTS")
        before = {name: getattr(GENERATOR.base, name) for name in names}
        self.assertEqual(set(GENERATOR.build_plan(self.root, self.campaign)), set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual({name: getattr(GENERATOR.base, name) for name in names}, before)

    def test_committed_outputs_are_cold_first_pass_fixed_point(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        stale = [relative for relative in GENERATOR.OWNED_OUTPUTS
                 if not (self.campaign / relative).is_file()
                 or (self.campaign / relative).read_bytes() != plan[relative]]
        self.assertEqual(stale, [])

    def test_non_target_batch_and_review_records_are_preserved_exactly(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        before_batch = [line for line in batch.read_bytes().splitlines(keepends=True)
                        if json.loads(line).get("trait_id") != GENERATOR.TRAIT]
        before_review = [row for row in json.loads(review.read_bytes())["per_trait_review"]
                         if row["trait_id"] != GENERATOR.TRAIT]
        self.run_generator()
        after_batch = [line for line in batch.read_bytes().splitlines(keepends=True)
                       if json.loads(line).get("trait_id") != GENERATOR.TRAIT]
        after_review = [row for row in json.loads(review.read_bytes())["per_trait_review"]
                        if row["trait_id"] != GENERATOR.TRAIT]
        self.assertEqual(after_batch, before_batch)
        self.assertEqual(after_review, before_review)

    def test_duplicate_target_rows_are_rejected_without_writes(self) -> None:
        for relative, mutate in (
            ("trait_batches/batch_11.jsonl", "batch"),
            ("independent_reviews/traits_09_12.json", "review"),
        ):
            with self.subTest(relative=relative):
                self.tearDown()
                self.setUp()
                path = self.campaign / relative
                if mutate == "batch":
                    rows = jsonl(path)
                    rows.append(next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT))
                    path.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows),
                                    encoding="utf-8", newline="\n")
                else:
                    artifact = json.loads(path.read_bytes())
                    artifact["per_trait_review"].append(
                        next(row for row in artifact["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT))
                    path.write_text(json.dumps(artifact), encoding="utf-8")
                before = files(self.campaign)
                with self.assertRaisesRegex(ValueError, "expected one trait_id"):
                    GENERATOR.build_plan(self.root, self.campaign)
                self.assertEqual(files(self.campaign), before)

    def test_empty_or_missing_sunday_batch_input_is_rejected_without_writes(self) -> None:
        for content in ("", json.dumps({"trait_id": "UniversalTraits:UT_not_sundayrunner"}) + "\n"):
            with self.subTest(content=content):
                self.tearDown()
                self.setUp()
                batch = self.campaign / "trait_batches" / "batch_11.jsonl"
                batch.write_text(content, encoding="utf-8", newline="\n")
                before = files(self.campaign)
                with self.assertRaisesRegex(ValueError, "expected one trait_id"):
                    GENERATOR.build_plan(self.root, self.campaign)
                self.assertEqual(files(self.campaign), before)

    def test_malformed_json_and_jsonl_inputs_are_rejected_without_writes(self) -> None:
        for relative in (
            "trait_batches/batch_11.jsonl",
            "independent_reviews/traits_09_12.json",
        ):
            with self.subTest(relative=relative):
                self.tearDown()
                self.setUp()
                path = self.campaign / relative
                path.write_text("{not-json\n", encoding="utf-8", newline="\n")
                before = files(self.campaign)
                with self.assertRaises(json.JSONDecodeError):
                    GENERATOR.build_plan(self.root, self.campaign)
                self.assertEqual(files(self.campaign), before)

    def test_source_fingerprint_failure_is_rejected_without_writes(self) -> None:
        original = GENERATOR._input_metadata_lf

        def reject_wrong_fingerprint(root: Path, relative: str) -> dict[str, object]:
            metadata = original(root, relative)
            if relative == GENERATOR.RUNTIME:
                raise ValueError("source fingerprint mismatch")
            return metadata

        before = files(self.campaign)
        GENERATOR._input_metadata_lf = reject_wrong_fingerprint
        try:
            with self.assertRaisesRegex(ValueError, "source fingerprint mismatch"):
                GENERATOR.build_plan(self.root, self.campaign)
        finally:
            GENERATOR._input_metadata_lf = original
        self.assertEqual(files(self.campaign), before)

    def test_fixed_point_retains_runtime_gaps(self) -> None:
        self.run_generator()
        self.assertEqual(self.run_generator(), [])
        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        row = next(item for item in ledger["traits"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(row["overall_state"], "runtime-unproven")
        self.assertTrue(any("Kahlua" in value for value in row["unknowns"]))
        dimensions = {item["dimension"] for item in jsonl(self.campaign / "remediation_queue.jsonl")
                      if item.get("trait_id") == GENERATOR.TRAIT and item.get("subject_type") == "trait-dimension"}
        self.assertTrue({"kahlua", "reset_save_load", "balance", "performance", "localization"}.issubset(dimensions))

    def test_injected_promotion_failure_rolls_back_and_restores_configuration(self) -> None:
        names = ("TRAIT", "FINDINGS", "_plan_batch", "_plan_review", "OWNED_OUTPUTS")
        base_before = {name: getattr(GENERATOR.base, name) for name in names}
        metadata_before = GENERATOR.HELPER._metadata
        transaction_before = GENERATOR.transaction.OWNED_OUTPUTS
        plan = GENERATOR.build_plan(self.root, self.campaign)
        plan[GENERATOR.OWNED_OUTPUTS[0]] += b" "
        plan[GENERATOR.OWNED_OUTPUTS[1]] += b" "
        before = files(self.campaign)
        calls = 0

        def fail_second(source: str | Path, destination: str | Path) -> None:
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected promotion failure")
            Path(source).replace(destination)

        with self.assertRaisesRegex(OSError, "injected promotion failure"):
            GENERATOR.commit_plan(plan, self.campaign, replace=fail_second)
        self.assertEqual(files(self.campaign), before)
        self.assertEqual({name: getattr(GENERATOR.base, name) for name in names}, base_before)
        self.assertIs(GENERATOR.HELPER._metadata, metadata_before)
        self.assertIs(GENERATOR.transaction.OWNED_OUTPUTS, transaction_before)

    def test_tavern_after_sunday_cannot_downgrade_sunday(self) -> None:
        self.run_generator()
        before = next(row for row in jsonl(self.campaign / "trait_batches" / "batch_11.jsonl")
                      if row["trait_id"] == GENERATOR.TRAIT)
        TAVERN.commit_plan(TAVERN.build_plan(self.root, self.campaign), self.campaign)
        after = next(row for row in jsonl(self.campaign / "trait_batches" / "batch_11.jsonl")
                     if row["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(after, before)
        self.assertEqual(GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign), [])


if __name__ == "__main__":
    unittest.main()
