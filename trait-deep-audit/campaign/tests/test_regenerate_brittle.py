"""Safety tests for the Brittle campaign generator."""

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
    "regenerate_brittle", TOOLS / "regenerate_brittle.py"
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


class BrittleGeneratorSafetyTests(unittest.TestCase):
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
            GENERATOR.HOOK,
            GENERATOR.HOOK_RELEASE,
            GENERATOR.SOURCE_UI,
            GENERATOR.RELEASE_UI,
            GENERATOR.TESTS,
            GENERATOR.TRAIT_TESTS,
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

    def test_plan_owns_only_the_declared_outputs(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(set(plan), set(GENERATOR.OWNED_OUTPUTS))

    def test_non_target_records_remain_unchanged(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_02.jsonl"
        review = self.campaign / "independent_reviews" / "traits_01_04.json"
        integration = self.campaign / "independent_reviews" / "ut_core_integration.json"
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
        integration_artifact = json.loads(integration.read_bytes())
        before_integration_inventory = [
            row
            for row in integration_artifact["inventory"]
            if row.get("path") != GENERATOR.HOOK
        ]
        before_integration_files = [
            row
            for row in integration_artifact["per_file_review"]
            if row.get("path") != GENERATOR.HOOK
        ]
        before_integration_findings = [
            row
            for row in integration_artifact["verified_prior_findings"]
            if row.get("id") not in GENERATOR.INTEGRATION_FINDINGS
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
        after_integration = json.loads(integration.read_bytes())
        self.assertEqual(
            [row for row in after_integration["inventory"] if row.get("path") != GENERATOR.HOOK],
            before_integration_inventory,
        )
        self.assertEqual(
            [row for row in after_integration["per_file_review"] if row.get("path") != GENERATOR.HOOK],
            before_integration_files,
        )
        self.assertEqual(
            [
                row
                for row in after_integration["verified_prior_findings"]
                if row.get("id") not in GENERATOR.INTEGRATION_FINDINGS
            ],
            before_integration_findings,
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

    def test_resolution_closes_exact_defects_and_keeps_policy_question_open(self) -> None:
        self._run()
        batch = next(
            row
            for row in _jsonl(self.campaign / "trait_batches" / "batch_02.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(
            {finding["id"]: finding["resolution_state"] for finding in batch["findings"]},
            {finding_id: "proven-correct" for finding_id in GENERATOR.FINDINGS},
        )
        review_artifact = json.loads(
            (self.campaign / "independent_reviews" / "traits_01_04.json").read_bytes()
        )
        review = next(
            row for row in review_artifact["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT
        )
        policy = next(
            row for row in review["omissions"] if row["id"] == GENERATOR.POLICY_QUESTION
        )
        self.assertEqual(policy["state"], "runtime-unproven")
        self.assertEqual(policy["resolution_state"], "requires-user-decision")
        blockers = json.loads((self.campaign / "release_blocker_queue.json").read_bytes())[
            "identities"
        ]
        self.assertNotIn(
            GENERATOR.BLOCKER_IDENTITY,
            {row.get("semantic_identity") for row in blockers},
        )

    def test_second_pass_is_a_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)

    def test_duplicate_target_record_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_02.jsonl"
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
                path.name.startswith(".regenerate-brittle-")
                for path in self.campaign.iterdir()
            )
        )


if __name__ == "__main__":
    unittest.main()
