"""Safety tests for the Glass Body campaign generator."""

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
    "regenerate_glassbody", TOOLS / "regenerate_glassbody.py"
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


class GlassBodyGeneratorSafetyTests(unittest.TestCase):
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
        self.assertEqual(set(GENERATOR.build_plan(self.root, self.campaign)), set(GENERATOR.OWNED_OUTPUTS))

    def test_non_target_records_remain_unchanged(self) -> None:
        batch_path = self.campaign / "trait_batches" / "batch_04.jsonl"
        review_path = self.campaign / "independent_reviews" / "traits_01_04.json"
        integration_path = self.campaign / "independent_reviews" / "ut_core_integration.json"
        blocker_path = self.campaign / "release_blocker_queue.json"
        translation_path = self.campaign / "translation_audit.json"

        before_batch = [row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT]
        review = json.loads(review_path.read_bytes())
        before_review = [row for row in review["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT]
        before_cross = [row for row in review["cross_trait_findings"] if row["id"] != GENERATOR.CROSS_FINDING]
        integration = json.loads(integration_path.read_bytes())
        before_inventory = [row for row in integration["inventory"] if row.get("path") != GENERATOR.HOOK]
        before_files = [row for row in integration["per_file_review"] if row.get("path") != GENERATOR.HOOK]
        before_findings = {
            key: [row for row in integration.get(key, []) if row.get("id") not in GENERATOR.INTEGRATION_FINDINGS]
            for key in ("verified_prior_findings", "rejected_prior_findings", "omissions")
        }
        before_blockers = [
            row for row in json.loads(blocker_path.read_bytes())["identities"]
            if row.get("semantic_identity") != GENERATOR.BLOCKER_IDENTITY
        ]
        before_translations = [
            row for row in json.loads(translation_path.read_bytes())["per_trait_ledger"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]

        self._run()

        self.assertEqual(
            [row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT], before_batch
        )
        after_review = json.loads(review_path.read_bytes())
        self.assertEqual(
            [row for row in after_review["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT],
            before_review,
        )
        self.assertEqual(
            [row for row in after_review["cross_trait_findings"] if row["id"] != GENERATOR.CROSS_FINDING],
            before_cross,
        )
        after_integration = json.loads(integration_path.read_bytes())
        self.assertEqual(
            [row for row in after_integration["inventory"] if row.get("path") != GENERATOR.HOOK],
            before_inventory,
        )
        self.assertEqual(
            [row for row in after_integration["per_file_review"] if row.get("path") != GENERATOR.HOOK],
            before_files,
        )
        for key, expected in before_findings.items():
            self.assertEqual(
                [row for row in after_integration.get(key, []) if row.get("id") not in GENERATOR.INTEGRATION_FINDINGS],
                expected,
            )
        self.assertEqual(json.loads(blocker_path.read_bytes())["identities"], before_blockers)
        self.assertEqual(
            [row for row in json.loads(translation_path.read_bytes())["per_trait_ledger"] if row["trait_id"] != GENERATOR.TRAIT],
            before_translations,
        )

    def test_resolution_closes_exact_defects_and_removes_blocker(self) -> None:
        self._run()
        batch = next(
            row for row in _jsonl(self.campaign / "trait_batches" / "batch_04.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        finding = next(row for row in batch["findings"] if row["id"] == GENERATOR.FINDING)
        self.assertEqual(finding["resolution_state"], "proven-correct")
        review = json.loads(
            (self.campaign / "independent_reviews" / "traits_01_04.json").read_bytes()
        )
        trait = next(row for row in review["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT)
        omission = next(row for row in trait["omissions"] if row["id"] == GENERATOR.OMISSION)
        cross = next(row for row in review["cross_trait_findings"] if row["id"] == GENERATOR.CROSS_FINDING)
        self.assertEqual(omission["state"], "proven-correct")
        self.assertEqual(cross["state"], "proven-correct")
        blockers = json.loads((self.campaign / "release_blocker_queue.json").read_bytes())["identities"]
        self.assertNotIn(
            GENERATOR.BLOCKER_IDENTITY,
            {row.get("semantic_identity") for row in blockers},
        )
        queue = [
            row for row in _jsonl(self.campaign / "remediation_queue.jsonl")
            if row.get("trait_id") == GENERATOR.TRAIT
        ]
        self.assertEqual(
            {row["dimension"] for row in queue},
            {"reset_save_load", "kahlua", "localization", "balance", "performance", "packaging"},
        )
        self.assertNotIn("confirmed-defect", {row["state"] for row in queue})

    def test_second_pass_is_a_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)

    def test_duplicate_target_record_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
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
        path.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
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
            any(path.name.startswith(".regenerate-glassbody-") for path in self.campaign.iterdir())
        )


if __name__ == "__main__":
    unittest.main()
