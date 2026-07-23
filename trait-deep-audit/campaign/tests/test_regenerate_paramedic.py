"""Safety tests for the Paramedic campaign generator."""

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
SPEC = importlib.util.spec_from_file_location("regenerate_paramedic", TOOLS / "regenerate_paramedic.py")
assert SPEC and SPEC.loader
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def _files(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"
    }


def _jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


class ParamedicGeneratorSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "UTMods"
        self.campaign = self.root / "trait-deep-audit" / "campaign"
        shutil.copytree(CAMPAIGN, self.campaign, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        source_root = CAMPAIGN.parents[1]
        for relative in (
            GENERATOR.RUNTIME, GENERATOR.RELEASE, GENERATOR.SOURCE_UI,
            GENERATOR.SHARED_RUNTIME, GENERATOR.SHARED_RELEASE,
            GENERATOR.RELEASE_UI, GENERATOR.SOURCE_DEFINITION,
            GENERATOR.RELEASE_DEFINITION, GENERATOR.MOCKS, GENERATOR.TESTS,
            GENERATOR.ACTIVE_AUDIT,
        ):
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / relative, destination)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _run(self) -> list[str]:
        return GENERATOR.commit_plan(GENERATOR.build_plan(self.root, self.campaign), self.campaign)

    def test_exact_owned_output_set_and_non_paramedic_records_are_preserved(self) -> None:
        batch_path = self.campaign / "trait_batches" / "batch_08.jsonl"
        review_path = self.campaign / "independent_reviews" / "traits_05_08.json"
        translation_path = self.campaign / "translation_audit.json"
        blocker_path = self.campaign / "release_blocker_queue.json"
        before_batch = [row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT]
        before_review = [
            row for row in json.loads(review_path.read_text(encoding="utf-8"))["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_translation = [
            row for row in json.loads(translation_path.read_text(encoding="utf-8"))["per_trait_ledger"]
            if row["trait_id"] != GENERATOR.TRAIT
        ]
        before_blockers = [
            row for row in json.loads(blocker_path.read_text(encoding="utf-8"))["identities"]
            if row["semantic_identity"] != GENERATOR.SHARED_BLOCKER
        ]
        before_files = _files(self.campaign)
        changed = self._run()
        after_files = _files(self.campaign)
        actual = {path for path in before_files | after_files if before_files.get(path) != after_files.get(path)}
        self.assertEqual(actual, set(changed))
        self.assertLessEqual(actual, set(GENERATOR.OWNED_OUTPUTS))
        self.assertEqual(before_batch, [row for row in _jsonl(batch_path) if row["trait_id"] != GENERATOR.TRAIT])
        self.assertEqual(before_review, [
            row for row in json.loads(review_path.read_text(encoding="utf-8"))["per_trait_review"]
            if row["trait_id"] != GENERATOR.TRAIT
        ])
        self.assertEqual(before_translation, [
            row for row in json.loads(translation_path.read_text(encoding="utf-8"))["per_trait_ledger"]
            if row["trait_id"] != GENERATOR.TRAIT
        ])
        self.assertEqual(before_blockers, [
            row for row in json.loads(blocker_path.read_text(encoding="utf-8"))["identities"]
            if row["semantic_identity"] != GENERATOR.SHARED_BLOCKER
        ])

    def test_accepted_supersession_closes_only_static_defect(self) -> None:
        self._run()
        row = next(row for row in _jsonl(self.campaign / "trait_batches" / "batch_08.jsonl") if row["trait_id"] == GENERATOR.TRAIT)
        findings = {finding["id"]: finding for finding in row["findings"]}
        self.assertEqual(row["overall_state"], "runtime-unproven")
        self.assertEqual(findings[GENERATOR.CLOSED_FINDING]["resolution_state"], "proven-correct")
        self.assertEqual(findings[GENERATOR.RETAINED_FINDING]["resolution_state"], "runtime-unproven")
        review = json.loads((self.campaign / "independent_reviews" / "traits_05_08.json").read_text(encoding="utf-8"))
        reviewed = next(item for item in review["per_trait_review"] if item["trait_id"] == GENERATOR.TRAIT)
        self.assertEqual(reviewed["original_state"], "confirmed-defect")
        self.assertEqual(reviewed["verified_finding_ids"], [GENERATOR.CLOSED_FINDING, GENERATOR.RETAINED_FINDING])
        self.assertTrue(reviewed["superseding_review"]["historical_review_preserved"])

    def test_exact_real_and_invented_action_identifiers(self) -> None:
        self._run()
        resolution = json.loads((self.campaign / GENERATOR.RESOLUTION).read_text(encoding="utf-8"))
        expected = [
            "ISMedicalCheckAction", "ISApplyBandage", "ISCleanBurn",
            "ISComfreyCataplasm", "ISGarlicCataplasm", "ISPlantainCataplasm",
            "ISDisinfect", "ISRemoveBullet", "ISRemoveGlass", "ISSplint", "ISStitch",
        ]
        invented = ["ISApplyComfrey", "ISApplyGarlic", "ISApplyPlantain"]
        self.assertEqual(resolution["exact_medical_action_types"], expected)
        self.assertEqual(resolution["rejected_invented_action_types"], invented)
        self.assertTrue(set(expected).isdisjoint(invented))
        hook = resolution["shared_work_speed_hook"]
        self.assertTrue(hook["byte_identical"])
        self.assertEqual(hook["exact_medical_action_types"], expected)
        self.assertEqual(
            hook["constructor_action_types"],
            ["ISMedicalCheckAction", "ISSplint"],
        )
        self.assertEqual(
            {anchor["id"] for anchor in hook["semantic_anchors"]},
            {
                "independent_half_factor",
                "additive_modifiers_before_paramedic",
                "constructor_installation",
                "get_duration_skips_constructor_adjusted_action",
                "constructor_skips_already_adjusted_action",
                "constructor_marks_adjusted_after_half_factor",
            },
        )
        self.assertEqual(
            hook["source"]["sha256"],
            hook["release_42_0"]["sha256"],
        )

    def test_temporary_shared_hook_divergence_is_rejected_without_canonical_writes(self) -> None:
        release = self.root / GENERATOR.SHARED_RELEASE
        release.write_bytes(release.read_bytes() + b"\n-- temporary divergence\n")
        before = _files(self.campaign)
        with self.assertRaisesRegex(ValueError, "exact 42.0 release mirror diverge"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(before, _files(self.campaign))

    def test_guard_removal_from_both_parity_copies_is_rejected_without_artifact_writes(self) -> None:
        for relative in (GENERATOR.SHARED_RUNTIME, GENERATOR.SHARED_RELEASE):
            path = self.root / relative
            source = path.read_text(encoding="utf-8")
            changed = source.replace(
                "            action._utParamedicDurationApplied = true\n",
                "",
                1,
            )
            self.assertNotEqual(source, changed)
            path.write_text(changed, encoding="utf-8")
        before = _files(self.campaign)
        with self.assertRaisesRegex(ValueError, "double-apply guard drifted"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(before, _files(self.campaign))

    def test_guard_removal_from_one_parity_copy_is_rejected_without_artifact_writes(self) -> None:
        path = self.root / GENERATOR.SHARED_RUNTIME
        source = path.read_text(encoding="utf-8")
        changed = source.replace(
            "    if timedAction._utParamedicDurationApplied or not hasParamedic(timedAction) then\n",
            "    if not hasParamedic(timedAction) then\n",
            1,
        )
        self.assertNotEqual(source, changed)
        path.write_text(changed, encoding="utf-8")
        before = _files(self.campaign)
        with self.assertRaisesRegex(ValueError, "exact 42.0 release mirror diverge"):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(before, _files(self.campaign))

    def test_shared_blocker_removes_only_paramedic_queue_id(self) -> None:
        self._run()
        blockers = json.loads((self.campaign / "release_blocker_queue.json").read_text(encoding="utf-8"))
        blocker = next(row for row in blockers["identities"] if row["semantic_identity"] == GENERATOR.SHARED_BLOCKER)
        self.assertNotIn(GENERATOR.PARAMEDIC_QUEUE_ID, blocker["queue_ids"])
        self.assertEqual(blocker["queue_ids"].count(GENERATOR.PITCREW_QUEUE_ID), 1)
        self.assertEqual(blocker["evidence_scope"], "Pit Crew registers OnActionAdded, which is absent from the current event registry.")

    def test_second_pass_is_fixed_point(self) -> None:
        self._run()
        before = _files(self.campaign)
        self.assertEqual(self._run(), [])
        self.assertEqual(before, _files(self.campaign))

    def test_duplicate_target_is_rejected_without_writes(self) -> None:
        batch = self.campaign / "trait_batches" / "batch_08.jsonl"
        target = next(line for line in batch.read_text(encoding="utf-8").splitlines() if json.loads(line)["trait_id"] == GENERATOR.TRAIT)
        batch.write_text(batch.read_text(encoding="utf-8") + target + "\n", encoding="utf-8")
        before = _files(self.campaign)
        with self.assertRaises(ValueError):
            GENERATOR.build_plan(self.root, self.campaign)
        self.assertEqual(before, _files(self.campaign))

    def test_injected_promotion_failure_rolls_back_all_outputs(self) -> None:
        plan = GENERATOR.build_plan(self.root, self.campaign)
        plan[GENERATOR.OWNED_OUTPUTS[0]] += b" "
        plan[GENERATOR.OWNED_OUTPUTS[1]] += b" "
        before = _files(self.campaign)
        calls = 0

        def fail_second(source: str | Path, destination: str | Path) -> None:
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected promotion failure")
            Path(source).replace(destination)

        with self.assertRaisesRegex(OSError, "injected promotion failure"):
            GENERATOR.commit_plan(plan, self.campaign, replace=fail_second)
        self.assertEqual(before, _files(self.campaign))


if __name__ == "__main__":
    unittest.main()
