"""Regression tests for campaign normalization and structural validation."""

from __future__ import annotations

import importlib.util
import json
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CAMPAIGN_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CAMPAIGN_ROOT / "tools"))
MODULE_PATH = CAMPAIGN_ROOT / "tools" / "build_final_trait_ledger.py"
SPEC = importlib.util.spec_from_file_location("build_final_trait_ledger", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

PATTERN_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "check_recurring_patterns.py"
PATTERN_SPEC = importlib.util.spec_from_file_location("check_recurring_patterns", PATTERN_MODULE_PATH)
assert PATTERN_SPEC and PATTERN_SPEC.loader
PATTERN_MODULE = importlib.util.module_from_spec(PATTERN_SPEC)
PATTERN_SPEC.loader.exec_module(PATTERN_MODULE)

VALIDATOR_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "validate_campaign.py"
VALIDATOR_SPEC = importlib.util.spec_from_file_location("validate_campaign", VALIDATOR_MODULE_PATH)
assert VALIDATOR_SPEC and VALIDATOR_SPEC.loader
VALIDATOR_MODULE = importlib.util.module_from_spec(VALIDATOR_SPEC)
VALIDATOR_SPEC.loader.exec_module(VALIDATOR_MODULE)

MANIFEST_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "build_campaign_manifest.py"
MANIFEST_SPEC = importlib.util.spec_from_file_location(
    "build_campaign_manifest", MANIFEST_MODULE_PATH
)
assert MANIFEST_SPEC and MANIFEST_SPEC.loader
MANIFEST_MODULE = importlib.util.module_from_spec(MANIFEST_SPEC)
MANIFEST_SPEC.loader.exec_module(MANIFEST_MODULE)

QUEUE_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "build_remediation_queue.py"
QUEUE_SPEC = importlib.util.spec_from_file_location(
    "build_remediation_queue", QUEUE_MODULE_PATH
)
assert QUEUE_SPEC and QUEUE_SPEC.loader
QUEUE_MODULE = importlib.util.module_from_spec(QUEUE_SPEC)
QUEUE_SPEC.loader.exec_module(QUEUE_MODULE)

WOOD_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "regenerate_woodsplitter.py"
WOOD_SPEC = importlib.util.spec_from_file_location("regenerate_woodsplitter", WOOD_MODULE_PATH)
assert WOOD_SPEC and WOOD_SPEC.loader
WOOD_MODULE = importlib.util.module_from_spec(WOOD_SPEC)
WOOD_SPEC.loader.exec_module(WOOD_MODULE)


def _wood_fixture(destination: Path) -> Path:
    root = destination / "UTMods"
    campaign = root / "trait-deep-audit" / "campaign"
    shutil.copytree(
        CAMPAIGN_ROOT,
        campaign,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    for relative in (
        WOOD_MODULE.SOURCE_UI,
        WOOD_MODULE.RELEASE_UI,
    ):
        source = CAMPAIGN_ROOT.parents[1] / relative
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return root


class ResolutionRecordTests(unittest.TestCase):
    def test_builds_canonical_resolution_record(self) -> None:
        record = QUEUE_MODULE.make_resolution_record(
            "finding:AUDIT-001",
            "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
            "task-123",
            ["z/file.py", "a/file.py"],
            ["reports/test.json", "reports/diff.txt"],
            "Focused and campaign-tool tests passed.",
        )
        self.assertEqual(
            tuple(record),
            (
                "queue_id",
                "commit_sha",
                "task_id",
                "changed_paths",
                "validation_artifacts",
                "resolution_evidence",
            ),
        )
        self.assertEqual(
            record["commit_sha"], "abcdef0123456789abcdef0123456789abcdef01"
        )
        self.assertEqual(record["changed_paths"], ["a/file.py", "z/file.py"])
        self.assertEqual(
            record["validation_artifacts"],
            ["reports/diff.txt", "reports/test.json"],
        )

    def test_rejects_missing_or_invalid_scalar_values(self) -> None:
        valid = {
            "queue_id": "queue-1",
            "commit_sha": "a" * 40,
            "task_id": "task-1",
            "changed_paths": ["src/file.py"],
            "validation_artifacts": ["reports/test.txt"],
            "resolution_evidence": "Tests passed.",
        }
        for name, value in (
            ("queue_id", ""),
            ("task_id", "   "),
            ("resolution_evidence", ""),
            ("commit_sha", "a" * 39),
            ("commit_sha", "g" * 40),
        ):
            with self.subTest(name=name, value=value):
                arguments = {**valid, name: value}
                with self.assertRaises(ValueError):
                    QUEUE_MODULE.make_resolution_record(**arguments)

    def test_rejects_noncanonical_or_duplicate_paths(self) -> None:
        invalid_paths = (
            [],
            [""],
            ["/absolute/file.py"],
            ["C:/absolute/file.py"],
            ["parent/../file.py"],
            ["windows\\file.py"],
            ["duplicate.py", "duplicate.py"],
        )
        for paths in invalid_paths:
            with self.subTest(paths=paths):
                with self.assertRaises(ValueError):
                    QUEUE_MODULE.make_resolution_record(
                        "queue-1",
                        "a" * 40,
                        "task-1",
                        paths,
                        ["reports/test.txt"],
                        "Tests passed.",
                    )
                with self.assertRaises(ValueError):
                    QUEUE_MODULE.make_resolution_record(
                        "queue-1",
                        "a" * 40,
                        "task-1",
                        ["src/file.py"],
                        paths,
                        "Tests passed.",
                    )


class NormalizationTests(unittest.TestCase):
    def test_legacy_states_map_to_terminal_vocabulary(self) -> None:
        self.assertEqual(MODULE.normalize_state("proven"), "proven-correct")
        self.assertEqual(MODULE.normalize_state("defect"), "confirmed-defect")
        self.assertEqual(MODULE.normalize_state("gap"), "coverage-gap")
        self.assertEqual(MODULE.normalize_state("partial"), "coverage-gap")
        self.assertEqual(MODULE.normalize_state("reviewed"), "runtime-unproven")
        self.assertEqual(MODULE.normalize_state("not-applicable", ""), "proven-correct")
        self.assertEqual(
            MODULE.normalize_state("not-applicable", "No live Kahlua validation."),
            "runtime-unproven",
        )

    def test_unknown_state_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown audit state"):
            MODULE.normalize_state("probably fine")

    def test_missing_and_duplicate_membership_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "membership mismatch"):
            MODULE.validate_membership(["a", "b"], ["a"])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            MODULE.validate_membership(["a", "b"], ["a", "a"])

    def test_unmapped_dimension_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "unmapped audit dimension"):
            MODULE.normalize_dimensions({"mystery dimension": {"state": "proven"}})

    def test_legacy_missing_proof_spellings_are_preserved(self) -> None:
        dimensions = {
            name: {"state": "proven", "evidence": name, "missing_proof": ""}
            for name in MODULE.CANONICAL_DIMENSIONS
        }
        dimensions["registration"] = {
            "state": "runtime-unproven",
            "evidence": "legacy spaced key",
            "exact missing proof": "No in-game registration trace.",
        }
        dimensions["definition_parser"] = {
            "state": "runtime-unproven",
            "evidence": "legacy underscored key",
            "exact_missing_proof": "No ScriptManager load trace.",
        }
        normalized = MODULE.normalize_dimensions(dimensions)
        self.assertEqual(
            normalized["registration"]["missing_proof"],
            ["No in-game registration trace."],
        )
        self.assertEqual(
            normalized["definition_parser"]["missing_proof"],
            ["No ScriptManager load trace."],
        )

    def test_missing_and_stale_generated_artifacts_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "artifact.json"
            self.assertEqual(
                VALIDATOR_MODULE.generated_artifact_errors(path, "expected\n", "artifact.json"),
                ["artifact.json is missing"],
            )
            path.write_text("stale\n", encoding="utf-8")
            self.assertEqual(
                VALIDATOR_MODULE.generated_artifact_errors(path, "expected\n", "artifact.json"),
                ["artifact.json is stale or nondeterministic"],
            )
            path.write_text("expected\n", encoding="utf-8")
            self.assertEqual(
                VALIDATOR_MODULE.generated_artifact_errors(path, "expected\n", "artifact.json"),
                [],
            )

    def test_help_and_unknown_arguments_do_not_mutate_outputs(self) -> None:
        outputs = [
            MODULE.OUTPUT_PATH,
            MODULE.OUTPUT_JSONL_PATH,
            PATTERN_MODULE.OUTPUT_PATH,
            MANIFEST_MODULE.OUTPUT_PATH,
            QUEUE_MODULE.DIMENSION_OUTPUT_PATH,
            QUEUE_MODULE.QUEUE_OUTPUT_PATH,
            QUEUE_MODULE.SUMMARY_OUTPUT_PATH,
        ]
        before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in outputs}
        scripts = [
            MODULE_PATH,
            PATTERN_MODULE_PATH,
            VALIDATOR_MODULE_PATH,
            MANIFEST_MODULE_PATH,
            QUEUE_MODULE_PATH,
        ]
        for script in scripts:
            help_result = subprocess.run(
                [sys.executable, "-B", str(script), "--help"],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(help_result.returncode, 0, help_result.stderr)
            invalid_result = subprocess.run(
                [sys.executable, "-B", str(script), "--unexpected"],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(invalid_result.returncode, 2)
        after = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in outputs}
        self.assertEqual(before, after)

    def test_current_ledger_is_complete_and_deterministic(self) -> None:
        first = MODULE.render_ledger(MODULE.build_ledger(CAMPAIGN_ROOT))
        second = MODULE.render_ledger(MODULE.build_ledger(CAMPAIGN_ROOT))
        self.assertEqual(first, second)
        ledger = json.loads(first)
        ledger_rows = MODULE.render_trait_rows(ledger)
        self.assertEqual(ledger_rows, MODULE.render_trait_rows(json.loads(second)))
        self.assertEqual(len(ledger_rows.splitlines()), 198)
        self.assertEqual(ledger["counts"]["traits"], 198)
        self.assertEqual(ledger["counts"]["unique_traits"], 198)
        self.assertEqual(ledger["counts"]["independent_reviewed_traits"], 198)
        self.assertEqual(ledger["counts"]["independent_review_findings"], 118)
        self.assertEqual(len(ledger["traits"]), 198)
        self.assertTrue(all(len(row["dimensions"]) == 24 for row in ledger["traits"]))
        self.assertTrue(all(row["independent_review"] for row in ledger["traits"]))

    def test_remediation_queue_is_closed_world_and_dependency_ordered(self) -> None:
        ledger = MODULE.build_ledger(CAMPAIGN_ROOT)
        dimensions = QUEUE_MODULE.build_dimension_rows(ledger)
        findings = QUEUE_MODULE.build_finding_rows(ledger, CAMPAIGN_ROOT)
        queue = QUEUE_MODULE.build_queue(dimensions, findings)

        self.assertEqual(len(dimensions), 198 * 24)
        self.assertEqual(len({row["queue_id"] for row in dimensions}), 198 * 24)
        self.assertEqual(
            {row["state"] for row in dimensions}, set(MODULE.TERMINAL_STATES)
        )
        expected_findings = (
            ledger["counts"]["findings"]
            + ledger["counts"]["independent_review_findings"]
            + len(PATTERN_MODULE.build_report()["findings"])
        )
        self.assertEqual(len(findings), expected_findings)
        self.assertEqual(len({row["queue_id"] for row in findings}), expected_findings)
        self.assertTrue(queue)
        self.assertEqual(len(queue), len({row["queue_id"] for row in queue}))
        self.assertTrue(all(tuple(row) == QUEUE_MODULE.QUEUE_COLUMNS for row in queue))
        self.assertTrue(all(row["state"] != "proven-correct" for row in queue))
        queue_ids = {row["queue_id"] for row in queue}
        self.assertTrue(
            all(set(row["depends_on"]).issubset(queue_ids) for row in queue)
        )

    def test_remediation_outputs_are_deterministic_and_match_ledger_counts(self) -> None:
        first = QUEUE_MODULE.build_outputs(CAMPAIGN_ROOT)
        second = QUEUE_MODULE.build_outputs(CAMPAIGN_ROOT)
        self.assertEqual(first, second)
        dimension_rows = [json.loads(line) for line in first[0].splitlines()]
        queue_rows = [json.loads(line) for line in first[1].splitlines()]
        summary = json.loads(first[2])
        self.assertEqual(len(dimension_rows), 4752)
        self.assertEqual(summary["counts"]["dimension_records"], 4752)
        self.assertEqual(summary["counts"]["open_queue_records"], len(queue_rows))
        self.assertEqual(summary["acceptance"]["allowed_terminal_state"], "proven-correct")


class CampaignManifestTests(unittest.TestCase):
    def test_text_metadata_and_total_are_line_ending_independent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lf = b'{\n  "value": "same"\n}\n'
            crlf = lf.replace(b"\n", b"\r\n")
            path = root / "artifact.json"
            path.write_bytes(lf)
            lf_manifest = MANIFEST_MODULE.build_manifest(root, required_artifacts=())
            path.write_bytes(crlf)
            crlf_manifest = MANIFEST_MODULE.build_manifest(root, required_artifacts=())
            self.assertEqual(lf_manifest["files"], crlf_manifest["files"])
            self.assertEqual(lf_manifest["total_bytes"], crlf_manifest["total_bytes"])
            self.assertEqual(lf_manifest["files"][0]["byte_semantics"], "utf-8-lf")

    def test_raw_artifacts_keep_raw_byte_semantics_and_content_changes_are_detected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            text = root / "artifact.json"
            binary = root / "artifact.bin"
            text.write_bytes(b'{"value":1}\n')
            binary.write_bytes(b"\x00\r\n\xff")
            first = MANIFEST_MODULE.build_manifest(root, required_artifacts=())
            text.write_bytes(b'{"value":2}\n')
            binary.write_bytes(b"\x00\n\xff")
            second = MANIFEST_MODULE.build_manifest(root, required_artifacts=())
            first_rows = {row["path"]: row for row in first["files"]}
            second_rows = {row["path"]: row for row in second["files"]}
            self.assertNotEqual(first_rows["artifact.json"]["sha256"], second_rows["artifact.json"]["sha256"])
            self.assertEqual(first_rows["artifact.bin"]["byte_semantics"], "raw")
            self.assertNotEqual(first_rows["artifact.bin"]["bytes"], second_rows["artifact.bin"]["bytes"])
            self.assertNotEqual(first_rows["artifact.bin"]["sha256"], second_rows["artifact.bin"]["sha256"])

    def test_manifest_is_closed_world_and_deterministic(self) -> None:
        first = MANIFEST_MODULE.render_manifest(MANIFEST_MODULE.build_manifest())
        second = MANIFEST_MODULE.render_manifest(MANIFEST_MODULE.build_manifest())
        self.assertEqual(first, second)
        manifest = json.loads(first)
        paths = [row["path"] for row in manifest["files"]]
        expected = [
            path.relative_to(CAMPAIGN_ROOT).as_posix()
            for path in MANIFEST_MODULE.campaign_files(CAMPAIGN_ROOT)
        ]
        self.assertEqual(paths, expected)
        self.assertEqual(len(paths), len(set(paths)))
        self.assertEqual(manifest["file_count"], len(paths))
        self.assertTrue(set(manifest["required_artifacts"]).issubset(paths))

    def test_manifest_excludes_only_self_and_python_caches(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "kept.txt").write_text("kept", encoding="utf-8")
            (root / "campaign_manifest.json").write_text("self", encoding="utf-8")
            cache = root / "tools" / "__pycache__"
            cache.mkdir(parents=True)
            (cache / "ignored.pyc").write_bytes(b"cache")
            manifest = MANIFEST_MODULE.build_manifest(root, required_artifacts=())
            self.assertEqual([row["path"] for row in manifest["files"]], ["kept.txt"])

    def test_missing_required_artifact_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(FileNotFoundError, "required.json"):
                MANIFEST_MODULE.build_manifest(
                    Path(directory), required_artifacts=("required.json",)
                )


class WoodSplitterRegeneratorTests(unittest.TestCase):
    def assertNoTransactionArtifacts(self, campaign: Path) -> None:
        artifacts = [
            path for path in campaign.rglob("*")
            if path.name == WOOD_MODULE.JOURNAL_NAME
            or path.name.startswith(WOOD_MODULE.TRANSACTION_PREFIX)
        ]
        self.assertEqual(artifacts, [])

    def test_plan_is_deterministic_and_preserves_unrelated_event_records(self) -> None:
        first = WOOD_MODULE.build_plan()
        second = WOOD_MODULE.build_plan()
        self.assertEqual(first.planned, second.planned)

        named_events = ("OnActionAdded", "OnClimbFence", "OnFenceClimb", "OnFishCaught")
        for relative, owner in (
            ("final_trait_ledger_rows.jsonl", lambda row: row.get("trait_id") == WOOD_MODULE.TRAIT),
            ("dimension_ledger_rows.jsonl", lambda row: row.get("trait_id") == WOOD_MODULE.TRAIT),
            ("remediation_queue.jsonl", lambda row: row.get("trait_id") == WOOD_MODULE.TRAIT),
        ):
            before = WOOD_MODULE._load_jsonl(first.original[relative])
            after = WOOD_MODULE._load_jsonl(first.planned[relative])
            self.assertEqual([row for row in before if not owner(row)], [row for row in after if not owner(row)])
            before_named = [row for row in before if any(name in json.dumps(row) for name in named_events)]
            after_named = [row for row in after if any(name in json.dumps(row) for name in named_events)]
            self.assertEqual(before_named, after_named)

        recurring_before = WOOD_MODULE._load_json(first.original["recurring_pattern_findings.json"])
        recurring_after = WOOD_MODULE._load_json(first.planned["recurring_pattern_findings.json"])
        self.assertEqual(
            [row for row in recurring_before["findings"] if row["id"] != WOOD_MODULE.PATTERN_ID],
            [row for row in recurring_after["findings"] if row["id"] != WOOD_MODULE.PATTERN_ID],
        )

    def test_fresh_lf_and_crlf_checkouts_are_fixed_points_on_both_runs(self) -> None:
        for ending in (b"\n", b"\r\n"):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory() as directory:
                root = _wood_fixture(Path(directory))
                campaign = root / "trait-deep-audit" / "campaign"
                for path in campaign.rglob("*"):
                    if path.is_file() and path.suffix.lower() in MANIFEST_MODULE.TEXT_ARTIFACT_SUFFIXES:
                        canonical = MANIFEST_MODULE.canonical_artifact_bytes(path)
                        path.write_bytes(canonical.replace(b"\n", ending))
                first = WOOD_MODULE.commit_transaction(WOOD_MODULE.build_plan(root))
                second = WOOD_MODULE.commit_transaction(WOOD_MODULE.build_plan(root))
                self.assertEqual(first, [])
                self.assertEqual(second, [])

    def test_commit_failure_rolls_back_every_owned_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            master = root / "trait-deep-audit/campaign/MASTER_COVERAGE_LEDGER.md"
            master.write_text(master.read_text(encoding="utf-8").replace(
                "UniversalTraits:UT_woodsplitter is statically validated",
                "UniversalTraits:UT_woodsplitter is stale",
            ), encoding="utf-8", newline="\n")
            recurring = root / "trait-deep-audit/campaign/recurring_pattern_findings.json"
            recurring.write_text(
                recurring.read_text(encoding="utf-8").replace(
                    "Translator preprocessing mutates literal percent signs",
                    "stale translator finding",
                ),
                encoding="utf-8",
                newline="\n",
            )
            plan = WOOD_MODULE.build_plan(root)
            before = {relative: (plan.campaign / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
            calls = 0

            def fail_once(source: str | Path, target: str | Path) -> None:
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("injected replacement failure")
                os.replace(source, target)

            with self.assertRaisesRegex(OSError, "injected replacement failure"):
                WOOD_MODULE.commit_transaction(plan, replace=fail_once)
            after = {relative: (plan.campaign / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
            self.assertEqual(before, after)
            self.assertNoTransactionArtifacts(plan.campaign)

    def test_fingerprints_are_checkout_line_ending_independent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            lf_plan = WOOD_MODULE.build_plan(root)
            for relative in (WOOD_MODULE.SOURCE_UI, WOOD_MODULE.RELEASE_UI):
                path = root / relative
                path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
            crlf_plan = WOOD_MODULE.build_plan(root)
            for relative in ("translation_audit.json", "source_inventory.json", "final_trait_ledger.json"):
                self.assertEqual(lf_plan.planned[relative], crlf_plan.planned[relative])

    def test_source_inventory_duplicate_missing_extra_and_cross_owned_paths_fail(self) -> None:
        mutations = (
            lambda anchors: anchors.append(dict(next(row for row in anchors if row.get("path") == WOOD_MODULE.SOURCE_UI))),
            lambda anchors: anchors.__setitem__(slice(None), [row for row in anchors if row.get("path") != WOOD_MODULE.SOURCE_UI]),
            lambda anchors: anchors.append({"path": WOOD_MODULE.RELEASE_UI}),
        )
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                with tempfile.TemporaryDirectory() as directory:
                    root = _wood_fixture(Path(directory))
                    path = root / "trait-deep-audit/campaign/source_inventory.json"
                    artifact = json.loads(path.read_text(encoding="utf-8"))
                    mutate(artifact["sources"]["anchors"])
                    path.write_text(json.dumps(artifact), encoding="utf-8", newline="\n")
                    before = {relative: (root / "trait-deep-audit/campaign" / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
                    with self.assertRaisesRegex(ValueError, "ownership|cross-owned"):
                        WOOD_MODULE.build_plan(root)
                    after = {relative: (root / "trait-deep-audit/campaign" / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
                    self.assertEqual(before, after)

    def test_interrupted_promotion_recovers_exact_preimages_idempotently(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            master = root / "trait-deep-audit/campaign/MASTER_COVERAGE_LEDGER.md"
            master.write_text(master.read_text(encoding="utf-8").replace("statically validated", "stale"), encoding="utf-8", newline="\n")
            plan = WOOD_MODULE.build_plan(root)
            changed = [relative for relative in WOOD_MODULE.OUTPUTS if plan.planned[relative] != plan.original[relative]]
            entries = []
            for relative in changed:
                target = plan.campaign / relative
                stage = target.parent / f"{WOOD_MODULE.TRANSACTION_PREFIX}{target.name}.stage"
                backup = target.parent / f"{WOOD_MODULE.TRANSACTION_PREFIX}{target.name}.backup"
                WOOD_MODULE._write_durable(stage, plan.planned[relative])
                WOOD_MODULE._write_durable(backup, plan.original[relative])
                entries.append({
                    "relative": relative,
                    "stage": stage.name,
                    "backup": backup.name,
                    "preimage_sha256": WOOD_MODULE._sha256(plan.original[relative]),
                    "planned_sha256": WOOD_MODULE._sha256(plan.planned[relative]),
                })
            journal = plan.campaign / WOOD_MODULE.JOURNAL_NAME
            WOOD_MODULE._write_durable(journal, WOOD_MODULE._json_bytes({
                "schema": "regenerate_woodsplitter.transaction.v1",
                "phase": "promoting",
                "entries": entries,
            }, sort_keys=True))
            first = entries[0]
            first_target = plan.campaign / first["relative"]
            os.replace(first_target.parent / first["stage"], first_target)

            self.assertTrue(WOOD_MODULE.recover_transaction(plan.campaign))
            self.assertFalse(WOOD_MODULE.recover_transaction(plan.campaign))
            self.assertEqual(
                {relative: (plan.campaign / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS},
                plan.original,
            )
            self.assertNoTransactionArtifacts(plan.campaign)

    def test_ambiguous_ownership_fails_before_writes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            batch = root / "trait-deep-audit/campaign/trait_batches/batch_12.jsonl"
            original = batch.read_bytes()
            wood_line = next(
                line for line in original.decode("utf-8").splitlines()
                if json.loads(line)["trait_id"] == WOOD_MODULE.TRAIT
            )
            batch.write_bytes(original + wood_line.encode("utf-8") + b"\n")
            before = {
                relative: (root / "trait-deep-audit/campaign" / relative).read_bytes()
                for relative in WOOD_MODULE.OUTPUTS
            }
            with self.assertRaisesRegex(ValueError, "ownership mismatch"):
                WOOD_MODULE.build_plan(root)
            after = {
                relative: (root / "trait-deep-audit/campaign" / relative).read_bytes()
                for relative in WOOD_MODULE.OUTPUTS
            }
            self.assertEqual(before, after)

    def test_arguments_are_rejected_without_writes(self) -> None:
        before = {relative: (CAMPAIGN_ROOT / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
        result = subprocess.run(
            [sys.executable, "-B", str(WOOD_MODULE_PATH), "--unexpected"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        after = {relative: (CAMPAIGN_ROOT / relative).read_bytes() for relative in WOOD_MODULE.OUTPUTS}
        self.assertEqual(before, after)


class RecurringPatternTests(unittest.TestCase):
    def test_unwavering_translation_is_ascii_safe_and_release_identical(self) -> None:
        repository_root = CAMPAIGN_ROOT.parents[1]
        source_path = (
            repository_root
            / "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
        )
        release_path = (
            repository_root
            / "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
        )
        source_bytes = source_path.read_bytes()
        source_ui = json.loads(source_bytes)

        self.assertNotIn("\u2014", source_ui["UI_UT_unwaveringDesc"])
        self.assertEqual(
            source_ui["UI_UT_unwaveringDesc"],
            "Fear never really got its hooks into you. Every 10 in-game minutes, "
            "if panic is above 10, panic is reduced by 10.",
        )
        self.assertEqual(source_bytes, release_path.read_bytes())

    def test_event_argument_inversion_and_fractional_clock_are_detected(self) -> None:
        source = """
local function onHit(attacker, weapon, target)
end
Events.OnWeaponHitCharacter.Add(onHit)
local hour = getGameTime():getTimeOfDay()
if hour >= 0.25 then
    if hour <= 0.75 then end
end
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.lua"
            path.write_text(source, encoding="utf-8")
            self.assertEqual(len(PATTERN_MODULE.weapon_hit_signature_inversions(path)), 1)
            self.assertEqual(len(PATTERN_MODULE.fractional_time_of_day_thresholds(path)), 2)

    def test_current_report_is_deterministic_and_schema_complete(self) -> None:
        first = PATTERN_MODULE.render_report(PATTERN_MODULE.build_report())
        second = PATTERN_MODULE.render_report(PATTERN_MODULE.build_report())
        self.assertEqual(first, second)
        report = json.loads(first)
        ids = [finding["id"] for finding in report["findings"]]
        self.assertEqual(len(ids), len(set(ids)))
        required = {
            "id",
            "state",
            "severity",
            "confidence",
            "title",
            "anchors",
            "affected_surfaces",
            "reproduction_evidence",
            "missing_proof",
            "recommended_correction",
            "smallest_regression_test",
        }
        self.assertTrue(all(required.issubset(finding) for finding in report["findings"]))

    def test_event_registry_fixture_rejects_unknown_event(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manager = root / "Java" / "source" / "zombie" / "Lua" / "LuaEventManager.java"
            manager.parent.mkdir(parents=True)
            manager.write_text('AddEvent("KnownEvent");\n', encoding="utf-8")
            lua_path = root / "consumer.lua"
            lua_path.write_text("Events.UnknownEvent.Add(handler)\n", encoding="utf-8")
            known = PATTERN_MODULE.engine_event_names(root)
            used = {event for event, _handler, _line in PATTERN_MODULE.lua_event_registrations(lua_path)}
            self.assertEqual(known, {"KnownEvent"})
            self.assertEqual(used - known, {"UnknownEvent"})

    def test_translator_and_tree_parity_negative_fixtures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ui_path = root / "UI.json"
            ui_path.write_text(
                json.dumps({"bad": "50% faster", "safe": "50%."}),
                encoding="utf-8",
            )
            self.assertEqual(PATTERN_MODULE.translator_mutated_percent_keys(ui_path), ["bad"])

            source = root / "source"
            release = root / "release"
            source.mkdir()
            release.mkdir()
            (source / "same.txt").write_text("same", encoding="utf-8")
            (release / "same.txt").write_text("same", encoding="utf-8")
            (source / "changed.txt").write_text("source", encoding="utf-8")
            (release / "changed.txt").write_text("release", encoding="utf-8")
            (source / "missing.txt").write_text("missing", encoding="utf-8")
            (release / "extra.txt").write_text("extra", encoding="utf-8")
            self.assertEqual(
                PATTERN_MODULE.tree_parity(source, release),
                {
                    "missing_in_release": ["missing.txt"],
                    "extra_in_release": ["extra.txt"],
                    "content_mismatch": ["changed.txt"],
                },
            )


if __name__ == "__main__":
    unittest.main()
