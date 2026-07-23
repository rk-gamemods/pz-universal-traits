"""Focused hostile tests for the Gourmand campaign generator."""

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


GENERATOR = load("regenerate_gourmand")


def files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file()
    }


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class GourmandGeneratorSafetyTests(unittest.TestCase):
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
            GENERATOR.HOOK,
            GENERATOR.HOOK_RELEASE,
            GENERATOR.SOURCE_UI,
            GENERATOR.RELEASE_UI,
            GENERATOR.SOURCE_DEFINITION,
            GENERATOR.RELEASE_DEFINITION,
            GENERATOR.SOURCE_REGISTRY,
            GENERATOR.RELEASE_REGISTRY,
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
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
        review = self.campaign / "independent_reviews" / "traits_01_04.json"
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

    def test_duplicate_or_missing_target_rows_are_rejected_without_writes(self) -> None:
        for relative, kind in (
            ("trait_batches/batch_04.jsonl", "batch"),
            ("independent_reviews/traits_01_04.json", "review"),
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

        self.tearDown()
        self.setUp()
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
        batch.write_text(
            json.dumps({"trait_id": "UniversalTraits:UT_not_gourmand"}) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_malformed_batch_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
        batch.write_text("{not-json\n", encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaises(json.JSONDecodeError):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_item_mutation_membership_drift_is_rejected_without_writes(self) -> None:
        review = self.campaign / "independent_reviews" / "traits_01_04.json"
        artifact = json.loads(review.read_bytes())
        finding = next(
            row
            for row in artifact["cross_trait_findings"]
            if row["id"] == GENERATOR.ITEM_MUTATION_FINDING
        )
        finding["affected_surfaces"].append("UniversalTraits:UT_unrelated")
        review.write_text(json.dumps(artifact), encoding="utf-8")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "exact membership drifted"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_fixed_point_closes_only_static_findings_and_retains_live_proof(self) -> None:
        self.run_generator()
        self.assertEqual(self.run_generator(), [])
        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        row = next(item for item in ledger["traits"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(row["overall_state"], "runtime-unproven")
        queue = [
            item
            for item in jsonl(self.campaign / "remediation_queue.jsonl")
            if item.get("trait_id") == GENERATOR.TRAIT
        ]
        findings = {
            item["finding_id"]: item["status"]
            for item in queue
            if item.get("subject_type") == "finding"
        }
        self.assertNotEqual(findings.get(GENERATOR.RUNTIME_FINDING), "closed")
        self.assertNotEqual(findings.get(GENERATOR.RESET_FINDING), "open")
        open_dimensions = {
            item["dimension"]
            for item in queue
            if item.get("subject_type") == "trait-dimension" and item.get("status") == "open"
        }
        self.assertTrue(
            {
                "definition_parser",
                "reset_save_load",
                "kahlua",
                "localization",
                "balance",
                "performance",
                "packaging",
            }.issubset(open_dimensions)
        )

    def test_exact_cross_finding_projection_preserves_gordanite(self) -> None:
        self.run_generator()
        review = json.loads(
            (self.campaign / "independent_reviews" / "traits_01_04.json").read_bytes()
        )
        finding = next(
            row
            for row in review["cross_trait_findings"]
            if row["id"] == GENERATOR.ITEM_MUTATION_FINDING
        )
        self.assertNotIn(GENERATOR.TRAIT, finding["affected_surfaces"])
        self.assertIn("UniversalTraits:UT_gordanite", finding["affected_surfaces"])
        self.assertEqual(
            finding["partial_resolutions"][GENERATOR.TRAIT],
            "implemented-and-statically-validated at 984ec687 with exact current-eater consumption deltas",
        )

    def test_exact_membership_unique_ids_and_allowed_states(self) -> None:
        self.run_generator()
        batch_rows = jsonl(self.campaign / "trait_batches" / "batch_04.jsonl")
        self.assertEqual(sum(row.get("trait_id") == GENERATOR.TRAIT for row in batch_rows), 1)
        batch = next(row for row in batch_rows if row["trait_id"] == GENERATOR.TRAIT)
        allowed = {
            "proven-correct",
            "confirmed-defect",
            "coverage-gap",
            "runtime-unproven",
            "not-applicable",
        }
        self.assertTrue({item["state"] for item in batch["dimensions"].values()}.issubset(allowed))
        self.assertIn(batch["overall_state"], allowed)
        queue = jsonl(self.campaign / "remediation_queue.jsonl")
        queue_ids = [row["queue_id"] for row in queue]
        self.assertEqual(len(queue_ids), len(set(queue_ids)))
        self.assertNotIn(
            "\N{EM DASH}".encode("utf-8"),
            (self.campaign / "translation_audit.json").read_bytes(),
        )

    def test_resolution_preserves_honest_intent_and_runtime_boundary(self) -> None:
        self.run_generator()
        resolution = json.loads((self.campaign / GENERATOR.RESOLUTION).read_bytes())
        self.assertEqual(resolution["accepted_intent"]["bonus_fraction"], 0.5)
        self.assertEqual(
            resolution["accepted_intent"]["basis"],
            "actual native consumption delta",
        )
        self.assertFalse(resolution["runtime_contract"]["food_mutation"])
        self.assertFalse(resolution["runtime_contract"]["persistent_baseline"])
        self.assertTrue(resolution["runtime_contract"]["duplicate_load_safe"])
        retained = set(resolution["retained_runtime_proof"])
        self.assertIn("actual B42 Kahlua action execution", retained)
        self.assertIn("package/live deployment", retained)
        self.assertIn("missing root poster.png", retained)

    def test_noncanonical_plan_is_rejected_and_promotion_failure_rolls_back(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        escaped = dict(plan)
        escaped["unrelated.json"] = b"{}\n"
        with self.assertRaisesRegex(ValueError, "non-canonical Gourmand output set"):
            GENERATOR.commit_plan(escaped, self.campaign)

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
