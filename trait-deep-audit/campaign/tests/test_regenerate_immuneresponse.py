"""Safety tests for the Immune Response campaign generator."""

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
    "regenerate_immuneresponse", TOOLS / "regenerate_immuneresponse.py"
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


class ImmuneResponseGeneratorSafetyTests(unittest.TestCase):
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
            GENERATOR.TESTS,
        ):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _run(self) -> list[str]:
        return GENERATOR.commit_plan(
            GENERATOR.build_plan(self.root, self.campaign), self.campaign
        )

    def test_exact_allowed_output_set_only(self) -> None:
        before = _all_files(self.campaign)
        changed = self._run()
        after = _all_files(self.campaign)
        actual = {path for path in before | after if before.get(path) != after.get(path)}
        self.assertEqual(actual, set(changed))
        self.assertLessEqual(actual, set(GENERATOR.OWNED_OUTPUTS))

    def test_non_target_records_remain_unchanged(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_05.jsonl"
        review = self.campaign / "independent_reviews" / "traits_05_08.json"
        blockers = self.campaign / "release_blocker_queue.json"
        translations = self.campaign / "translation_audit.json"
        before_batch = {
            row["trait_id"]: row
            for row in _jsonl(batch)
            if row["trait_id"] != GENERATOR.TRAIT
        }
        before_review = [
            row
            for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_blockers = [
            row
            for row in json.loads(blockers.read_bytes())["identities"]
            if row.get("semantic_identity") != GENERATOR.BLOCKER_IDENTITY
        ]
        before_translations = [
            row
            for row in json.loads(translations.read_bytes())["per_trait_ledger"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        self._run()
        self.assertEqual(
            {
                row["trait_id"]: row
                for row in _jsonl(batch)
                if row["trait_id"] != GENERATOR.TRAIT
            },
            before_batch,
        )
        self.assertEqual(
            [
                row
                for row in json.loads(review.read_bytes())["per_trait_review"]
                if row["trait_id"] != GENERATOR.TRAIT
            ],
            before_review,
        )
        self.assertEqual(json.loads(blockers.read_bytes())["identities"], before_blockers)
        self.assertEqual(
            [
                row
                for row in json.loads(translations.read_bytes())["per_trait_ledger"]
                if row["trait_id"] != GENERATOR.TRAIT
            ],
            before_translations,
        )

    def test_resolution_removes_only_the_exact_blocker(self) -> None:
        self._run()
        blockers = json.loads(
            (self.campaign / "release_blocker_queue.json").read_bytes()
        )["identities"]
        self.assertNotIn(
            GENERATOR.BLOCKER_IDENTITY,
            {row.get("semantic_identity") for row in blockers},
        )
        target = next(
            row
            for row in _jsonl(self.campaign / "trait_batches" / "batch_05.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        finding = next(
            row for row in target["findings"] if row["id"] == GENERATOR.FINDING
        )
        self.assertEqual(finding["resolution_state"], "proven-correct")

    def test_second_pass_is_a_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)

    def test_duplicate_target_record_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_05.jsonl"
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

    def test_duplicate_blocker_identity_is_rejected_without_writes(self) -> None:
        path = self.campaign / "release_blocker_queue.json"
        artifact = json.loads(path.read_bytes())
        target = {"semantic_identity": GENERATOR.BLOCKER_IDENTITY}
        artifact["identities"].extend((target, dict(target)))
        path.write_text(
            json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n"
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected at most one"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

    def test_injected_promotion_failure_rolls_back_every_output(self) -> None:
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
                path.name.startswith(".regenerate-immuneresponse-")
                for path in self.campaign.iterdir()
            )
        )


if __name__ == "__main__":
    unittest.main()
