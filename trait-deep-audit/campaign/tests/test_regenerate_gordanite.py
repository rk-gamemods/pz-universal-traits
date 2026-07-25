"""Focused safety tests for the Gordanite campaign generator."""

from __future__ import annotations

import hashlib
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
SPEC = importlib.util.spec_from_file_location("regenerate_gordanite", TOOLS / "regenerate_gordanite.py")
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"
    }


def jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class GordaniteGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        required = {
            GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.HOOK, GENERATOR.HOOK_RELEASE,
            GENERATOR.SOURCE_UI, GENERATOR.RELEASE_UI, GENERATOR.SOURCE_DEFINITION,
            GENERATOR.RELEASE_DEFINITION, GENERATOR.SOURCE_REGISTRY,
            GENERATOR.RELEASE_REGISTRY, GENERATOR.MOCKS, GENERATOR.TESTS,
            GENERATOR.ACTIVE_AUDIT,
        }
        for relative in required:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_generator(self) -> list[str]:
        return GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign)

    def test_exact_owned_outputs_and_non_target_records_are_preserved(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
        review = self.campaign / "independent_reviews" / "traits_01_04.json"
        before_batch = [line for line in batch.read_bytes().splitlines(keepends=True) if json.loads(line)["trait_id"] != GENERATOR.TRAIT]
        before_review = [
            row for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_files = files(self.campaign)
        changed = self.run_generator()
        after_files = files(self.campaign)
        actual = {path for path in before_files | after_files if before_files.get(path) != after_files.get(path)}
        self.assertEqual(actual, set(changed))
        self.assertLessEqual(actual, set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual(before_batch, [line for line in batch.read_bytes().splitlines(keepends=True) if json.loads(line)["trait_id"] != GENERATOR.TRAIT])
        self.assertEqual(before_review, [
            row for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ])

    def test_fixed_point_closes_static_findings_and_retains_runtime(self) -> None:
        self.run_generator()
        self.assertEqual(self.run_generator(), [])
        batch = next(row for row in jsonl(self.campaign / "trait_batches" / "batch_04.jsonl") if row["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(batch["overall_state"], "runtime-unproven")
        finding = next(item for item in batch["findings"] if item["id"] == GENERATOR.RUNTIME_FINDING)
        self.assertEqual(finding["resolution_state"], "runtime-unproven")
        review = json.loads((self.campaign / "independent_reviews" / "traits_01_04.json").read_bytes())
        row = next(item for item in review["per_trait_review"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(row["review_state"], "accepted")
        self.assertEqual(
            {item["id"] for item in row["omissions"] if item["state"] == "proven-correct"},
            set(GENERATOR.CLOSED_FINDINGS),
        )
        self.assertEqual(row["superseding_review"]["review_chronology"][0]["disposition"], "changes-requested")
        cross = next(item for item in review["cross_trait_findings"] if item["id"] == GENERATOR.FOOD_CROSS_FINDING)
        self.assertEqual(cross["state"], "proven-correct")
        self.assertEqual(cross["affected_surfaces"], [])

    def test_clean_committed_snapshot_is_a_first_pass_fixed_point(self) -> None:
        self.assertEqual(self.run_generator(), [])

        queue = jsonl(self.campaign / "remediation_queue.jsonl")
        ledger = json.loads((self.campaign / "final_trait_ledger.json").read_bytes())
        self.assertEqual(
            len([row for row in queue if row["trait_id"] == GENERATOR.TRAIT]),
            7,
        )
        self.assertEqual(len(ledger["independent_review_findings"]), 117)

        review = json.loads(
            (self.campaign / "independent_reviews" / "traits_01_04.json").read_bytes()
        )
        cross = next(
            row
            for row in review["cross_trait_findings"]
            if row["id"] == GENERATOR.FOOD_CROSS_FINDING
        )
        self.assertEqual(cross["state"], "proven-correct")
        self.assertEqual(cross["affected_surfaces"], [])

        blocker_queue = json.loads(
            (self.campaign / "release_blocker_queue.json").read_bytes()
        )
        blocker = next(
            row
            for row in blocker_queue["identities"]
            if row["semantic_identity"] == GENERATOR.SHARED_BLOCKER
        )
        self.assertEqual(
            blocker["queue_ids"],
            [
                "finding:IR0104-ALLERGIC-HOOK-STACK",
                "finding:IR0104-ANTIVAXXER-HOOK-STACK",
                "finding:IR0104-ADDICTEDTOCAFFEINE-HOOK-STACK",
                "dimension:UniversalTraits:UT_pillsallergy:events",
            ],
        )

        relative = "tests/test_regenerate_gordanite.py"
        test_bytes = (self.campaign / relative).read_bytes().replace(b"\r\n", b"\n")
        manifest = json.loads(
            (self.campaign / "campaign_manifest.json").read_bytes()
        )
        manifest_row = next(row for row in manifest["files"] if row["path"] == relative)
        self.assertEqual(manifest_row["byte_semantics"], "utf-8-lf")
        self.assertEqual(manifest_row["bytes"], len(test_bytes))
        self.assertEqual(
            manifest_row["sha256"],
            hashlib.sha256(test_bytes).hexdigest().upper(),
        )

    def test_rejected_commit_never_appears_in_accepted_fields(self) -> None:
        self.run_generator()
        rejected = GENERATOR.INITIAL_RUNTIME_COMMIT
        accepted = GENERATOR.ACCEPTED_RUNTIME_COMMIT
        resolution = json.loads((self.campaign / GENERATOR.RESOLUTION).read_bytes())
        chronology = resolution["review_iterations"]
        self.assertEqual(
            [(item["snapshot"], item["disposition"]) for item in chronology],
            [(rejected, "changes-requested"), (accepted, "accepted")],
        )
        self.assertEqual(resolution["authority"]["accepted_runtime_commit"], accepted)
        self.assertEqual(
            resolution["authority"]["runtime_commit_chain"],
            [
                {"snapshot": rejected, "review_disposition": "changes-requested"},
                {"snapshot": accepted, "review_disposition": "accepted"},
            ],
        )

        def assert_no_rejected_in_accepted_fields(value: object, path: str = "") -> None:
            if isinstance(value, dict):
                for key, child in value.items():
                    child_path = f"{path}.{key}" if path else key
                    if "accepted" in key.lower():
                        self.assertNotIn(rejected, json.dumps(child), child_path)
                    assert_no_rejected_in_accepted_fields(child, child_path)
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    assert_no_rejected_in_accepted_fields(child, f"{path}[{index}]")

        batch = next(
            row for row in jsonl(self.campaign / "trait_batches" / "batch_04.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        assert_no_rejected_in_accepted_fields(batch)
        assert_no_rejected_in_accepted_fields(resolution)

    def test_shared_wrapper_blocker_removes_only_gordanite_owner(self) -> None:
        before = json.loads((self.campaign / "release_blocker_queue.json").read_bytes())
        before_blocker = next(item for item in before["identities"] if item["semantic_identity"] == GENERATOR.SHARED_BLOCKER)
        expected = [
            queue_id for queue_id in before_blocker["queue_ids"]
            if queue_id != GENERATOR.GORDANITE_WRAPPER_QUEUE_ID
        ]
        self.run_generator()
        after = json.loads((self.campaign / "release_blocker_queue.json").read_bytes())
        blocker = next(item for item in after["identities"] if item["semantic_identity"] == GENERATOR.SHARED_BLOCKER)
        self.assertEqual(blocker["status"], "open")
        self.assertEqual(blocker["queue_ids"], expected)
        self.assertNotIn(GENERATOR.GORDANITE_WRAPPER_QUEUE_ID, blocker["queue_ids"])

    def test_duplicate_and_review_corruption_fail_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_04.jsonl"
        target = next(line for line in batch.read_text(encoding="utf-8").splitlines() if json.loads(line)["trait_id"] == GENERATOR.TRAIT)
        batch.write_text(batch.read_text(encoding="utf-8") + target + "\n", encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaises(ValueError):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

        self.tearDown()
        self.setUp()
        review = self.campaign / "independent_reviews" / "traits_01_04.json"
        artifact = json.loads(review.read_bytes())
        row = next(item for item in artifact["per_trait_review"] if item["trait_id"] == GENERATOR.TRAIT)
        row["omissions"] = [item for item in row["omissions"] if item["id"] != GENERATOR.CLOSED_FINDINGS[0]]
        review.write_text(json.dumps(artifact), encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaises(ValueError):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_rejected_identity_mutation_is_detected_without_tracked_writes(self) -> None:
        hook = self.root / GENERATOR.HOOK
        text = hook.read_text(encoding="utf-8")
        old = (
            "local username = character.getUsername\n"
            "        and tryReadIdentity(function() return character:getUsername() end) or nil\n"
            "    local fullName = character.getFullName\n"
            "        and tryReadIdentity(function() return character:getFullName() end) or nil"
        )
        replacement = (
            "local username = character.getUsername\n"
            "        and tryReadIdentity(function() return character:getUsername() end) or nil\n"
            "    local fullName = username and character.getFullName\n"
            "        and tryReadIdentity(function() return character:getFullName() end) or nil"
        )
        self.assertIn(old, text)
        hook.write_text(text.replace(old, replacement), encoding="utf-8", newline="\n")
        before = files(self.campaign)
        with self.assertRaisesRegex(ValueError, "source/release hook parity mismatch"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(files(self.campaign), before)

    def test_injected_promotion_failure_rolls_back_exactly(self) -> None:
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
