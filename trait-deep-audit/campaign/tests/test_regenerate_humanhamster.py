"""Focused safety tests for the Human Hamster campaign generator."""

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


GENERATOR = load("regenerate_humanhamster")


def files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file()
    }


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class HumanHamsterGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(
            CAMPAIGN,
            self.campaign,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        )
        source_root = CAMPAIGN.parents[1]
        required = {
            GENERATOR.RUNTIME,
            GENERATOR.RELEASE,
            GENERATOR.SOURCE_UI,
            GENERATOR.RELEASE_UI,
            GENERATOR.SOURCE_DEFINITION,
            GENERATOR.RELEASE_DEFINITION,
            GENERATOR.SOURCE_REGISTRY,
            GENERATOR.RELEASE_REGISTRY,
            GENERATOR.MOCKS,
            GENERATOR.TESTS,
            GENERATOR.ACTIVE_AUDIT,
        }
        for relative in required:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_generator(self) -> list[str]:
        return GENERATOR.commit_plan(
            GENERATOR.build_plan(self.root, self.campaign),
            self.campaign,
        )

    def test_exact_owned_output_set_and_configuration_restoration(self) -> None:
        names = ("TRAIT", "FINDINGS", "_plan_batch", "_plan_review", "OWNED_OUTPUTS")
        before = {name: getattr(GENERATOR.base, name) for name in names}
        self.assertEqual(
            set(GENERATOR.build_plan(self.root, self.campaign)),
            set(GENERATOR.OWNED_OUTPUTS),
        )
        self.assertEqual({name: getattr(GENERATOR.base, name) for name in names}, before)

    def test_non_target_batch_and_review_records_are_preserved_exactly(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_05.jsonl"
        review = self.campaign / "independent_reviews" / "traits_05_08.json"
        before_batch = [
            line
            for line in batch.read_bytes().splitlines(keepends=True)
            if json.loads(line).get("trait_id") != GENERATOR.TRAIT
        ]
        before_review = [
            row
            for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        self.run_generator()
        after_batch = [
            line
            for line in batch.read_bytes().splitlines(keepends=True)
            if json.loads(line).get("trait_id") != GENERATOR.TRAIT
        ]
        after_review = [
            row
            for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        self.assertEqual(after_batch, before_batch)
        self.assertEqual(after_review, before_review)

    def test_duplicate_target_rows_are_rejected_without_writes(self) -> None:
        for relative, kind in (
            ("trait_batches/batch_05.jsonl", "batch"),
            ("independent_reviews/traits_05_08.json", "review"),
        ):
            with self.subTest(relative=relative):
                self.tearDown()
                self.setUp()
                path = self.campaign / relative
                if kind == "batch":
                    rows = jsonl(path)
                    rows.append(next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT))
                    path.write_text(
                        "".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows),
                        encoding="utf-8",
                        newline="\n",
                    )
                else:
                    artifact = json.loads(path.read_bytes())
                    artifact["per_trait_review"].append(
                        next(
                            row
                            for row in artifact["per_trait_review"]
                            if row["trait_id"] == GENERATOR.TRAIT
                        )
                    )
                    path.write_text(json.dumps(artifact), encoding="utf-8")
                before = files(self.campaign)
                with self.assertRaisesRegex(ValueError, "expected one trait_id"):
                    GENERATOR.build_plan(self.root, self.campaign)
                self.assertEqual(files(self.campaign), before)

    def test_missing_target_batch_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_05.jsonl"
        batch.write_text(
            json.dumps({"trait_id": "UniversalTraits:UT_not_humanhamster"}) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_malformed_batch_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_05.jsonl"
        batch.write_text("{not-json\n", encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaises(json.JSONDecodeError):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_fixed_point_closes_exact_findings_and_retains_runtime_rows(self) -> None:
        self.run_generator()
        self.assertEqual(self.run_generator(), [])
        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        row = next(item for item in ledger["traits"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(row["overall_state"], "runtime-unproven")
        self.assertEqual(row["finding_ids"], list(GENERATOR.FINDINGS))
        queue = [
            item
            for item in jsonl(self.campaign / "remediation_queue.jsonl")
            if item.get("trait_id") == GENERATOR.TRAIT
        ]
        open_findings = {
            item["finding_id"]
            for item in queue
            if item.get("subject_type") == "finding" and item.get("status") == "open"
        }
        self.assertTrue(set(GENERATOR.FINDINGS).isdisjoint(open_findings))
        resolution = json.loads((self.campaign / GENERATOR.RESOLUTION).read_bytes())
        self.assertEqual(resolution["resolved_findings"], list(GENERATOR.FINDINGS))
        open_dimensions = {
            item["dimension"]
            for item in queue
            if item.get("subject_type") == "trait-dimension" and item.get("status") == "open"
        }
        self.assertTrue(
            {"cadence", "reset_save_load", "kahlua", "balance", "performance", "localization"}.issubset(
                open_dimensions
            )
        )

    def test_shared_finding_excludes_human_hamster_everywhere(self) -> None:
        self.run_generator()
        self.assertEqual(self.run_generator(), [])
        review = json.loads(
            (self.campaign / "independent_reviews" / "traits_05_08.json").read_bytes()
        )
        human_hamster = next(
            row for row in review["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(human_hamster["review_state"], "accepted")
        self.assertNotIn(
            GENERATOR.SHARED_FINDING,
            human_hamster["cross_trait_finding_ids"],
        )
        shared = next(
            row
            for row in review["cross_trait_findings"]
            if row["id"] == GENERATOR.SHARED_FINDING
        )
        self.assertEqual(
            shared["affected_traits"],
            list(GENERATOR.REMAINING_SHARED_TRAITS),
        )
        self.assertNotIn(GENERATOR.TRAIT, json.dumps(shared, sort_keys=True))
        self.assertIn("six affected traits", shared["reproduction_evidence"])
        self.assertIn("six remaining source IDs", shared["smallest_regression_test"])
        remaining_rows = {
            row["trait_id"]: row
            for row in review["per_trait_review"]
            if row["trait_id"] in GENERATOR.REMAINING_SHARED_TRAITS
        }
        self.assertEqual(
            tuple(remaining_rows),
            GENERATOR.REMAINING_SHARED_TRAITS,
        )
        for row in remaining_rows.values():
            self.assertIn(GENERATOR.SHARED_FINDING, row["cross_trait_finding_ids"])
            self.assertEqual(row["review_state"], "needs-correction")

        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        ledger_row = next(
            row for row in ledger["traits"] if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(ledger_row["independent_review"]["review_state"], "accepted")
        self.assertNotIn(
            GENERATOR.SHARED_FINDING,
            ledger_row["independent_review"]["cross_finding_ids"],
        )

        queue = jsonl(self.campaign / "remediation_queue.jsonl")
        shared_queue = next(
            row
            for row in queue
            if row.get("finding_id") == GENERATOR.SHARED_FINDING
        )
        self.assertEqual(shared_queue["status"], "open")
        self.assertNotIn(GENERATOR.TRAIT, json.dumps(shared_queue, sort_keys=True))
        self.assertIn("six affected traits", shared_queue["reproduction_evidence"])
        self.assertIn(
            "six remaining source IDs",
            shared_queue["smallest_regression_test"],
        )

    def test_exact_membership_and_unique_queue_ids(self) -> None:
        self.run_generator()
        batch_rows = jsonl(self.campaign / "trait_batches" / "batch_05.jsonl")
        self.assertEqual(
            sum(row.get("trait_id") == GENERATOR.TRAIT for row in batch_rows),
            1,
        )
        queue = jsonl(self.campaign / "remediation_queue.jsonl")
        queue_ids = [row["queue_id"] for row in queue]
        self.assertEqual(len(queue_ids), len(set(queue_ids)))

    def test_human_hamster_state_vocabulary_is_canonical(self) -> None:
        self.run_generator()
        allowed_states = {
            "proven-correct",
            "confirmed-defect",
            "coverage-gap",
            "runtime-unproven",
            "not-applicable",
        }
        batch_row = next(
            row
            for row in jsonl(self.campaign / "trait_batches" / "batch_05.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertTrue(
            {dimension["state"] for dimension in batch_row["dimensions"].values()}.issubset(
                allowed_states
            )
        )
        self.assertIn(batch_row["overall_state"], allowed_states)

    def test_injected_promotion_failure_rolls_back(self) -> None:
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


if __name__ == "__main__":
    unittest.main()
