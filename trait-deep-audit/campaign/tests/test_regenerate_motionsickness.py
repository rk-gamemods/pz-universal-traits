"""Focused safety tests for the Motion Sickness campaign generator."""
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
    "regenerate_motionsickness", TOOLS / "regenerate_motionsickness.py"
)
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def _all_files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"
    }


def _jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class MotionSicknessGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        for relative in (GENERATOR.RUNTIME, GENERATOR.RELEASE):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _run(self) -> list[str]:
        return GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign)

    def test_exact_owned_output_set_and_non_motion_records_are_preserved(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_06.jsonl"
        review = self.campaign / "independent_reviews" / "traits_05_08.json"
        blockers = self.campaign / "release_blocker_queue.json"
        before_files = _all_files(self.campaign)
        before_batch = [row for row in _jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT]
        before_review = [
            row for row in json.loads(review.read_bytes())["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_blockers = [
            row for row in json.loads(blockers.read_bytes())["identities"]
            if row.get("semantic_identity") != GENERATOR.BLOCKER_IDENTITY
        ]
        changed = self._run()
        after_files = _all_files(self.campaign)
        actual = {path for path in before_files | after_files if before_files.get(path) != after_files.get(path)}
        self.assertEqual(actual, set(changed))
        self.assertLessEqual(actual, set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual([row for row in _jsonl(batch) if row["trait_id"] != GENERATOR.TRAIT], before_batch)
        self.assertEqual(
            [row for row in json.loads(review.read_bytes())["per_trait_review"] if row["trait_id"] != GENERATOR.TRAIT],
            before_review,
        )
        after_blockers = json.loads(blockers.read_bytes())["identities"]
        expected_blockers = []
        for row in before_blockers:
            expected = {
                **row,
                "dependencies": [d for d in row["dependencies"] if d != GENERATOR.BLOCKER_IDENTITY],
            }
            if row["semantic_identity"] == "package:UniversalTraits-release-reconciliation":
                expected["queue_ids"] = [
                    item for item in row["queue_ids"]
                    if item != "finding:RP-PACKAGE-PARITY-UniversalTraits"
                ]
            expected_blockers.append(expected)
        self.assertEqual(
            expected_blockers,
            after_blockers,
        )

    def test_contract_transitions_preserve_open_uncertainty(self) -> None:
        self._run()
        batch = next(
            row for row in _jsonl(self.campaign / "trait_batches" / "batch_06.jsonl")
            if row["trait_id"] == GENERATOR.TRAIT
        )
        self.assertEqual(batch["overall_state"], "confirmed-defect")
        self.assertEqual([finding["id"] for finding in batch["findings"]], [GENERATOR.OPEN_FINDING])
        for dimension in ("java_lua", "kahlua", "reset_save_load"):
            self.assertEqual(batch["dimensions"][dimension]["state"], "runtime-unproven")
        self.assertEqual(batch["dimensions"]["multiplayer"]["state"], "not-applicable")
        review = json.loads((self.campaign / "independent_reviews" / "traits_05_08.json").read_bytes())
        trait = next(row for row in review["per_trait_review"] if row["trait_id"] == GENERATOR.TRAIT)
        stale = next(row for row in trait["omissions"] if row["id"] == GENERATOR.STALE_FINDING)
        self.assertEqual(stale["state"], "proven-correct")
        self.assertEqual(stale["resolution_state"], "closed-stale-finding")
        self.assertIn("Multiplayer", " ".join(trait["unresolved_proof"]))

    def test_duplicate_and_missing_exact_identities_fail_before_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_06.jsonl"
        rows = _jsonl(batch)
        target = next(row for row in rows if row["trait_id"] == GENERATOR.TRAIT)
        batch.write_text(
            "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in rows + [target]),
            encoding="utf-8",
            newline="\n",
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected one trait_id"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

        batch.write_text(
            "".join(
                json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
                for row in rows if row["trait_id"] != GENERATOR.TRAIT
            ),
            encoding="utf-8",
            newline="\n",
        )
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "found 0"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

    def test_duplicate_blocker_rejected_and_resolved_absence_is_idempotent(self) -> None:
        blockers = self.campaign / "release_blocker_queue.json"
        artifact = json.loads(blockers.read_bytes())
        target = {
            "semantic_identity": GENERATOR.BLOCKER_IDENTITY,
            "identity_kind": "trait",
            "status": "open",
            "priority_reason_code": "invalid-runtime-api",
            "queue_ids": [f"finding:{GENERATOR.STALE_FINDING}"],
            "dependencies": [],
            "evidence_scope": "stale test fixture",
        }
        artifact["identities"].extend((target, dict(target)))
        blockers.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
        before = _all_files(self.campaign)
        with self.assertRaisesRegex(ValueError, "expected at most one"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(_all_files(self.campaign), before)

        self.temporary.cleanup()
        self.setUp()
        blockers = self.campaign / "release_blocker_queue.json"
        artifact = json.loads(blockers.read_bytes())
        artifact["identities"] = [
            row for row in artifact["identities"] if row.get("semantic_identity") != GENERATOR.BLOCKER_IDENTITY
        ]
        for row in artifact["identities"]:
            row["dependencies"] = [item for item in row["dependencies"] if item != GENERATOR.BLOCKER_IDENTITY]
        blockers.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8", newline="\n")
        self._run()
        self.assertEqual(self._run(), [])

    def test_injected_promotion_failure_rolls_back_existing_and_new_outputs(self) -> None:
        resolution = self.campaign / "change-impact" / "motionsickness-stale-runtime-finding-resolution.json"
        resolution.unlink(missing_ok=True)
        plan = GENERATOR.build_plan(self.root, self.campaign)
        plan[GENERATOR.OWNED_OUTPUTS[0]] += b" "
        plan[GENERATOR.OWNED_OUTPUTS[1]] += b" "
        plan["recurring_pattern_findings.json"] += b" "
        before = _all_files(self.campaign)
        calls = 0

        def fail_after_new_output(source: str | Path, destination: str | Path) -> None:
            nonlocal calls
            calls += 1
            if calls == 4:
                raise OSError("injected promotion failure")
            Path(source).replace(destination)

        with self.assertRaisesRegex(OSError, "injected promotion failure"):
            GENERATOR.commit_plan(plan, self.campaign, replace=fail_after_new_output)
        self.assertEqual(_all_files(self.campaign), before)
        self.assertFalse(any(path.name.startswith(".regenerate_motionsickness-") for path in self.campaign.iterdir()))

    def test_second_pass_is_a_deterministic_fixed_point(self) -> None:
        self._run()
        first = _all_files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(_all_files(self.campaign), first)


if __name__ == "__main__":
    unittest.main()
