"""Isolated safety tests for the Super Immune campaign generator."""
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
    "regenerate_superimmune", TOOLS / "regenerate_superimmune.py"
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
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class SuperImmuneGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        for relative in (GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.TESTS):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _run(self) -> list[str]:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        return GENERATOR.commit_plan(plan, self.campaign)

    def test_exact_allowed_output_set_only(self) -> None:
        before = _all_files(self.campaign)
        changed = self._run()
        after = _all_files(self.campaign)
        actual = {path for path in before | after if before.get(path) != after.get(path)}
        self.assertEqual(actual, set(changed))
        self.assertLessEqual(actual, set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual(set(before), set(after))

    def test_non_superimmune_records_remain_byte_or_structure_unchanged(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        blockers = self.campaign / "release_blocker_queue.json"
        before_batch = {
            row["trait_id"]: row for row in _jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT
        }
        before_review = [
            row for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_blockers = [
            row for row in json.loads(blockers.read_bytes())["identities"]
            if row.get("semantic_identity") != "trait:UT_superimmune"
        ]
        self._run()
        self.assertEqual(
            {row["trait_id"]: row for row in _jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT},
            before_batch,
        )
        self.assertEqual(
            [row for row in json.loads(review.read_bytes())["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT],
            before_review,
        )
        self.assertEqual(json.loads(blockers.read_bytes())["identities"], before_blockers)

    def test_second_pass_is_a_deterministic_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)

    def test_duplicate_exact_identities_are_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        rows = _jsonl(batch)
        target = next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT)
        batch.write_text(
            "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in rows + [target]),
            encoding="utf-8", newline="\n",
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

    def test_duplicate_blocker_identity_is_rejected_without_writes(self) -> None:
        blockers = self.campaign / "release_blocker_queue.json"
        artifact = json.loads(blockers.read_bytes())
        target = {"semantic_identity": "trait:UT_superimmune"}
        artifact["identities"].extend((target, dict(target)))
        blockers.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected at most one"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

    def test_missing_review_identity_is_rejected_without_writes(self) -> None:
        review = self.campaign / "independent_reviews" / "traits_09_12.json"
        artifact = json.loads(review.read_bytes())
        artifact["per_trait_review"] = [
            row for row in artifact["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT
        ]
        review.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

    def test_missing_required_identity_rejects_but_resolved_blocker_absence_is_idempotent(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_11.jsonl"
        batch.write_text(
            "".join(
                json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
                for row in _jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT
            ),
            encoding="utf-8", newline="\n",
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "found 0"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

        shutil.rmtree(self.root)
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        for relative in (GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.TESTS):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)
        blockers = self.campaign / "release_blocker_queue.json"
        artifact = json.loads(blockers.read_bytes())
        artifact["identities"] = [
            row for row in artifact["identities"]
            if row.get("semantic_identity") != "trait:UT_superimmune"
        ]
        blockers.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
        self._run()
        self.assertEqual(self._run(), [])

    def test_injected_promotion_failure_rolls_back_every_output(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        first = GENERATOR.OWNED_OUTPUTS[0]
        second = GENERATOR.OWNED_OUTPUTS[1]
        plan[first] += b" "
        plan[second] += b" "
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
        self.assertFalse(any(path.name.startswith(".regenerate_superimmune-") for path in self.campaign.iterdir()))


if __name__ == "__main__":
    unittest.main()
