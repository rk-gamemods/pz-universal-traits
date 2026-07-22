"""Safety tests for the Staunch campaign generator."""

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
    "regenerate_staunch", TOOLS / "regenerate_staunch.py"
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


class StaunchGeneratorSafetyTests(unittest.TestCase):
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
            GENERATOR.CORE_STAT,
            GENERATOR.CORE_STAT_RELEASE,
            GENERATOR.CORE_HOOK,
            GENERATOR.CORE_HOOK_RELEASE,
            GENERATOR.CORE_MOCKS,
            GENERATOR.CORE_TESTS,
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
        batch_path = self.campaign / "trait_batches" / "batch_11.jsonl"
        review_path = self.campaign / "independent_reviews" / "traits_09_12.json"
        before_batch = [
            row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT
        ]
        review = json.loads(review_path.read_bytes())
        before_review = [
            row
            for row in review["per_trait_review"]
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
        after_review = json.loads(review_path.read_bytes())
        self.assertEqual(
            [
                row
                for row in after_review["per_trait_review"]
                if row["trait_id"] != GENERATOR.TRAIT
            ],
            before_review,
        )

    def test_resolution_closes_defect_and_preserves_runtime_gaps(self) -> None:
        self._run()
        batch = next(
            row
            for row in _jsonl(self.campaign / "trait_batches" / "batch_11.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(
            tuple(batch["dimensions"]), GENERATOR.HELPER.CANONICAL_DIMENSIONS
        )
        finding = next(
            item for item in batch["findings"] if item["id"] == GENERATOR.FINDINGS[0]
        )
        self.assertEqual(finding["resolution_state"], "proven-correct")

        queue = [
            row
            for row in _jsonl(self.campaign / "remediation_queue.jsonl")
            if row.get("trait_id") == GENERATOR.TRAIT
        ]
        self.assertEqual(
            [row for row in queue if row.get("subject_type") == "finding"], []
        )
        self.assertEqual(
            {
                row["dimension"]
                for row in queue
                if row.get("subject_type") == "trait-dimension"
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
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
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

    def test_injected_promotion_failure_rolls_back_all_outputs(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        plan[GENERATOR.OWNED_OUTPUTS[0]] += b" "
        plan[GENERATOR.OWNED_OUTPUTS[1]] += b" "
        before = _all_files(self.campaign)
        calls = 0

        def fail_second(source: str | Path, destination: str | Path) -> None:
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected promotion failure")
            Path(source).replace(destination)

        with self.assertRaisesRegex(OSError, "injected promotion failure"):
            GENERATOR.commit_plan(plan, self.campaign, replace=fail_second)
        self.assertEqual(_all_files(self.campaign), before)
        self.assertFalse(
            any(
                path.name.startswith(".regenerate-scardycat-")
                for path in self.campaign.iterdir()
            )
        )


if __name__ == "__main__":
    unittest.main()
