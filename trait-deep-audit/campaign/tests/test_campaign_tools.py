"""Regression tests for campaign normalization and structural validation."""

from __future__ import annotations

import importlib.util
import json
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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

UNWAVERING_MODULE_PATH = CAMPAIGN_ROOT / "tools" / "regenerate_unwavering.py"
UNWAVERING_SPEC = importlib.util.spec_from_file_location(
    "regenerate_unwavering", UNWAVERING_MODULE_PATH
)
assert UNWAVERING_SPEC and UNWAVERING_SPEC.loader
UNWAVERING_MODULE = importlib.util.module_from_spec(UNWAVERING_SPEC)
UNWAVERING_SPEC.loader.exec_module(UNWAVERING_MODULE)


PRE_REMEDIATION_TEXT_REPLACEMENTS = (
    ("fungi - the edible", "fungi — the edible"),
    ("not reduced - it just hurts", "not reduced — it just hurts"),
    ("normal - wounds bleed", "normal — wounds bleed"),
    ("×0.8 (-20 percent)", "×0.8 (−20 percent)"),
    ("×0.5 (-50 percent)", "×0.5 (−50 percent)"),
    ("×0.7 (-30 percent)", "×0.7 (−30 percent)"),
    ("×0.6 (-40 percent)", "×0.6 (−40 percent)"),
    ("zero - purely a lifestyle trait", "zero — purely a lifestyle trait"),
    ("slowly - your body needs less food", "slowly — your body needs less food"),
    (
        "stress decreases by -0.06 and panic decreases by -0.04",
        "stress decreases by −0.06 and panic decreases by −0.04",
    ),
    (
        "stress decreases by -0.08 when stress is above 0.6, or -0.03 otherwise",
        "stress decreases by −0.08 when stress is above 0.6, or −0.03 otherwise",
    ),
    (
        "stress decreases by -0.15 and boredom decreases by -0.2",
        "stress decreases by −0.15 and boredom decreases by −0.2",
    ),
)


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
        text = target.read_text(encoding="utf-8")
        for current, pre_remediation in PRE_REMEDIATION_TEXT_REPLACEMENTS:
            text = text.replace(current, pre_remediation)
        target.write_text(text, encoding="utf-8", newline="\n")
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


class ReleaseBlockerQueueDigestTests(unittest.TestCase):
    def test_updates_from_exact_raw_bytes_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            queue_path = root / "remediation_queue.jsonl"
            release_blocker_path = root / "release_blocker_queue.json"
            queue_bytes = b'{"queue_id":"one"}\r\n'
            queue_path.write_bytes(queue_bytes)
            release_blocker_path.write_text(
                json.dumps(
                    {
                        "schema_version": "1.0",
                        "remediation_queue_sha256": "0" * 64,
                        "identities": [],
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
                newline="\n",
            )

            QUEUE_MODULE.update_release_blocker_queue_sha256(
                queue_path, release_blocker_path
            )
            first = release_blocker_path.read_bytes()
            self.assertEqual(
                json.loads(first)["remediation_queue_sha256"],
                hashlib.sha256(queue_bytes).hexdigest(),
            )

            QUEUE_MODULE.update_release_blocker_queue_sha256(
                queue_path, release_blocker_path
            )
            self.assertEqual(release_blocker_path.read_bytes(), first)

    def test_one_byte_queue_mutation_changes_digest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            queue_path = root / "remediation_queue.jsonl"
            release_blocker_path = root / "release_blocker_queue.json"
            queue_path.write_bytes(b"a")
            release_blocker_path.write_text(
                '{"remediation_queue_sha256":"' + "0" * 64 + '"}\n',
                encoding="utf-8",
                newline="\n",
            )
            QUEUE_MODULE.update_release_blocker_queue_sha256(
                queue_path, release_blocker_path
            )
            first_digest = json.loads(release_blocker_path.read_bytes())[
                "remediation_queue_sha256"
            ]

            queue_path.write_bytes(b"b")
            QUEUE_MODULE.update_release_blocker_queue_sha256(
                queue_path, release_blocker_path
            )
            second_digest = json.loads(release_blocker_path.read_bytes())[
                "remediation_queue_sha256"
            ]
            self.assertNotEqual(first_digest, second_digest)
            self.assertEqual(second_digest, hashlib.sha256(b"b").hexdigest())

    def test_rejects_malformed_json_and_missing_or_malformed_field(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            queue_path = root / "remediation_queue.jsonl"
            release_blocker_path = root / "release_blocker_queue.json"
            queue_path.write_bytes(b"queue\n")
            cases = (
                ("malformed-json", "{"),
                ("non-object", "[]\n"),
                ("missing-field", "{}\n"),
                ("malformed-field", '{"remediation_queue_sha256":"ABC"}\n'),
            )
            for name, release_blocker_text in cases:
                with self.subTest(name=name):
                    release_blocker_path.write_text(
                        release_blocker_text,
                        encoding="utf-8",
                        newline="\n",
                    )
                    before = release_blocker_path.read_bytes()
                    with self.assertRaises((json.JSONDecodeError, ValueError)):
                        QUEUE_MODULE.update_release_blocker_queue_sha256(
                            queue_path, release_blocker_path
                        )
                    self.assertEqual(release_blocker_path.read_bytes(), before)


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


class UnwaveringRegeneratorTests(unittest.TestCase):
    def make_campaign(self, root: Path) -> Path:
        campaign = root / "campaign"
        campaign.mkdir()
        for relative in UNWAVERING_MODULE.DERIVED_OUTPUTS:
            (campaign / relative).write_bytes(f"original:{relative}\n".encode("utf-8"))
        (campaign / "release_blocker_queue.json").write_bytes(
            json.dumps({"remediation_queue_sha256": "0" * 64}).encode("utf-8")
        )
        (campaign / "stable-input.txt").write_bytes(b"stable\n")
        return campaign

    def test_derived_plan_hashes_exact_queue_before_manifest_last(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            campaign = self.make_campaign(Path(directory))
            queue_bytes = b'{"queue_id":"crlf"}\r\n{"queue_id":"lf"}\n'
            expected_digest = hashlib.sha256(queue_bytes).hexdigest()
            calls: list[str] = []
            temporary_paths: list[tuple[Path, Path]] = []
            real_update = UNWAVERING_MODULE.update_release_blocker_queue_sha256

            def update_blocker(queue_path: Path, blocker_path: Path) -> None:
                self.assertEqual(queue_path.read_bytes(), queue_bytes)
                temporary_paths.append((queue_path, blocker_path))
                real_update(queue_path, blocker_path)
                calls.append("release-blocker-updated")

            def build_manifest(overlay: Path) -> dict[str, object]:
                self.assertEqual((overlay / "remediation_queue.jsonl").read_bytes(), queue_bytes)
                blocker = json.loads((overlay / "release_blocker_queue.json").read_bytes())
                self.assertEqual(blocker["remediation_queue_sha256"], expected_digest)
                calls.append("manifest-regenerated")
                return {"observed_digest": blocker["remediation_queue_sha256"]}

            with (
                mock.patch.object(UNWAVERING_MODULE, "CAMPAIGN", campaign),
                mock.patch.object(UNWAVERING_MODULE, "build_ledger", return_value={}),
                mock.patch.object(UNWAVERING_MODULE, "render_ledger", return_value="ledger\n"),
                mock.patch.object(UNWAVERING_MODULE, "render_trait_rows", return_value="rows\n"),
                mock.patch.object(
                    UNWAVERING_MODULE,
                    "build_outputs",
                    return_value=("dimensions\n", queue_bytes.decode("utf-8"), "summary\n"),
                ),
                mock.patch.object(UNWAVERING_MODULE, "build_report", return_value={}),
                mock.patch.object(UNWAVERING_MODULE, "render_report", return_value="patterns\n"),
                mock.patch.object(
                    UNWAVERING_MODULE,
                    "update_release_blocker_queue_sha256",
                    side_effect=update_blocker,
                ),
                mock.patch.object(UNWAVERING_MODULE, "build_manifest", side_effect=build_manifest),
                mock.patch.object(
                    UNWAVERING_MODULE,
                    "render_manifest",
                    side_effect=lambda value: json.dumps(value) + "\n",
                ),
            ):
                UNWAVERING_MODULE._regenerate_derived()

            self.assertEqual(calls, ["release-blocker-updated", "manifest-regenerated"])
            self.assertEqual((campaign / "remediation_queue.jsonl").read_bytes(), queue_bytes)
            blocker = json.loads((campaign / "release_blocker_queue.json").read_bytes())
            self.assertEqual(blocker["remediation_queue_sha256"], expected_digest)
            self.assertEqual(len(temporary_paths), 1)
            self.assertFalse(temporary_paths[0][0].parent.exists())

    def test_derived_plan_cleans_temporary_inputs_and_preserves_canonical_on_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            campaign = self.make_campaign(Path(directory))
            before = {
                relative: (campaign / relative).read_bytes()
                for relative in UNWAVERING_MODULE.DERIVED_OUTPUTS
            }
            queue_bytes = b'{"queue_id":"failure-crlf"}\r\n{"queue_id":"failure-lf"}\n'
            temporary_paths: list[tuple[Path, Path]] = []
            real_update = UNWAVERING_MODULE.update_release_blocker_queue_sha256

            def fail_after_real_update(queue_path: Path, blocker_path: Path) -> None:
                temporary_paths.append((queue_path, blocker_path))
                real_update(queue_path, blocker_path)
                raise RuntimeError("injected temporary workflow failure")

            with (
                mock.patch.object(UNWAVERING_MODULE, "CAMPAIGN", campaign),
                mock.patch.object(UNWAVERING_MODULE, "build_ledger", return_value={}),
                mock.patch.object(UNWAVERING_MODULE, "render_ledger", return_value="ledger\n"),
                mock.patch.object(UNWAVERING_MODULE, "render_trait_rows", return_value="rows\n"),
                mock.patch.object(
                    UNWAVERING_MODULE,
                    "build_outputs",
                    return_value=("dimensions\n", queue_bytes.decode("utf-8"), "summary\n"),
                ),
                mock.patch.object(UNWAVERING_MODULE, "build_report", return_value={}),
                mock.patch.object(UNWAVERING_MODULE, "render_report", return_value="patterns\n"),
                mock.patch.object(
                    UNWAVERING_MODULE,
                    "update_release_blocker_queue_sha256",
                    side_effect=fail_after_real_update,
                ),
                mock.patch.object(UNWAVERING_MODULE, "build_manifest") as build_manifest,
            ):
                with self.assertRaisesRegex(RuntimeError, "injected temporary workflow failure"):
                    UNWAVERING_MODULE._regenerate_derived()

            self.assertEqual(len(temporary_paths), 1)
            self.assertFalse(temporary_paths[0][0].parent.exists())
            build_manifest.assert_not_called()
            after = {
                relative: (campaign / relative).read_bytes()
                for relative in UNWAVERING_MODULE.DERIVED_OUTPUTS
            }
            self.assertEqual(after, before)


class WoodSplitterRegeneratorTests(unittest.TestCase):
    def assertNoTransactionArtifacts(self, campaign: Path) -> None:
        artifacts = [
            path for path in campaign.rglob("*")
            if path.name == WOOD_MODULE.JOURNAL_NAME
            or path.name.startswith(WOOD_MODULE.TRANSACTION_PREFIX)
        ]
        self.assertEqual(artifacts, [])

    def test_build_plan_updates_release_blocker_after_queue_before_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            campaign = root / "trait-deep-audit" / "campaign"
            queue_bytes = b'{"queue_id":"planned-crlf"}\r\n{"queue_id":"planned-lf"}\n'
            initial_digest = "0" * 64
            release_blocker_path = campaign / "release_blocker_queue.json"
            release_blocker_path.write_bytes(
                json.dumps({"remediation_queue_sha256": initial_digest}).encode("utf-8")
            )
            expected_digest = __import__("hashlib").sha256(queue_bytes).hexdigest()
            expected_blocker_bytes = (
                json.dumps(
                    {"remediation_queue_sha256": expected_digest},
                    indent=2,
                    ensure_ascii=False,
                )
                + "\n"
            ).encode("utf-8")
            calls: list[str] = []
            temporary_paths: list[tuple[Path, Path]] = []

            def update_derived(plan, *_: object) -> None:
                calls.append("queue-written")
                plan.planned["remediation_queue.jsonl"] = queue_bytes

            real_update = WOOD_MODULE.update_release_blocker_queue_sha256

            def update_release_blocker(queue_path: Path, blocker_path: Path) -> None:
                temporary_paths.append((queue_path, blocker_path))
                self.assertEqual(queue_path.read_bytes(), queue_bytes)
                self.assertEqual(
                    json.loads(blocker_path.read_bytes())["remediation_queue_sha256"],
                    initial_digest,
                )
                real_update(queue_path, blocker_path)
                self.assertEqual(
                    json.loads(blocker_path.read_bytes())["remediation_queue_sha256"],
                    expected_digest,
                )
                calls.append("release-blocker-updated")

            def update_manifest(plan) -> None:
                self.assertEqual(plan.planned["release_blocker_queue.json"], expected_blocker_bytes)
                calls.append("manifest-regenerated")

            with (
                mock.patch.object(WOOD_MODULE, "_update_batch", return_value={}),
                mock.patch.object(WOOD_MODULE, "_update_source_records", return_value={}),
                mock.patch.object(WOOD_MODULE, "_update_change_impact"),
                mock.patch.object(
                    WOOD_MODULE,
                    "_update_derived",
                    side_effect=update_derived,
                ),
                mock.patch.object(
                    WOOD_MODULE,
                    "update_release_blocker_queue_sha256",
                    side_effect=update_release_blocker,
                ),
                mock.patch.object(WOOD_MODULE, "_update_pattern"),
                mock.patch.object(WOOD_MODULE, "_update_master"),
                mock.patch.object(
                    WOOD_MODULE,
                    "_update_manifest",
                    side_effect=update_manifest,
                ),
            ):
                plan = WOOD_MODULE.build_plan(root)

            self.assertEqual(plan.planned["remediation_queue.jsonl"], queue_bytes)
            self.assertEqual(plan.planned["release_blocker_queue.json"], expected_blocker_bytes)
            self.assertNotEqual(expected_digest, initial_digest)
            self.assertEqual(
                calls,
                ["queue-written", "release-blocker-updated", "manifest-regenerated"],
            )
            self.assertEqual(len(temporary_paths), 1)
            queue_path, blocker_path = temporary_paths[0]
            self.assertEqual(queue_path.name, "remediation_queue.jsonl")
            self.assertEqual(blocker_path.name, "release_blocker_queue.json")
            self.assertEqual(queue_path.parent, blocker_path.parent)
            self.assertFalse(queue_path.parent.exists())

    def test_build_plan_cleans_temporary_hash_inputs_after_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = _wood_fixture(Path(directory))
            campaign = root / "trait-deep-audit" / "campaign"
            queue_bytes = b'{"queue_id":"failure-crlf"}\r\n{"queue_id":"failure-lf"}\n'
            release_blocker_path = campaign / "release_blocker_queue.json"
            release_blocker_path.write_bytes(
                json.dumps({"remediation_queue_sha256": "f" * 64}).encode("utf-8")
            )
            canonical_before = {
                relative: (campaign / relative).read_bytes()
                for relative in WOOD_MODULE.OUTPUTS
            }
            temporary_paths: list[tuple[Path, Path]] = []
            real_update = WOOD_MODULE.update_release_blocker_queue_sha256

            def update_derived(plan, *_: object) -> None:
                plan.planned["remediation_queue.jsonl"] = queue_bytes

            def fail_after_real_update(queue_path: Path, blocker_path: Path) -> None:
                temporary_paths.append((queue_path, blocker_path))
                self.assertEqual(queue_path.read_bytes(), queue_bytes)
                real_update(queue_path, blocker_path)
                raise RuntimeError("injected temporary workflow failure")

            with (
                mock.patch.object(WOOD_MODULE, "_update_batch", return_value={}),
                mock.patch.object(WOOD_MODULE, "_update_source_records", return_value={}),
                mock.patch.object(WOOD_MODULE, "_update_change_impact"),
                mock.patch.object(WOOD_MODULE, "_update_derived", side_effect=update_derived),
                mock.patch.object(
                    WOOD_MODULE,
                    "update_release_blocker_queue_sha256",
                    side_effect=fail_after_real_update,
                ),
                mock.patch.object(WOOD_MODULE, "_update_pattern"),
                mock.patch.object(WOOD_MODULE, "_update_master"),
                mock.patch.object(WOOD_MODULE, "_update_manifest") as update_manifest,
            ):
                with self.assertRaisesRegex(RuntimeError, "injected temporary workflow failure"):
                    WOOD_MODULE.build_plan(root)

            self.assertEqual(len(temporary_paths), 1)
            self.assertFalse(temporary_paths[0][0].parent.exists())
            update_manifest.assert_not_called()
            canonical_after = {
                relative: (campaign / relative).read_bytes()
                for relative in WOOD_MODULE.OUTPUTS
            }
            self.assertEqual(canonical_after, canonical_before)

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
    def translator_code_points(self) -> tuple[int, ...]:
        authority = (
            CAMPAIGN_ROOT.parents[1].parent
            / "PZCodebase/Java/source/zombie/core/Translator.java"
        )
        text = authority.read_text(encoding="utf-8")
        match = re.search(
            r"public\s+static\s+final\s+char\[\]\s+LOOKALIKE_CHARS\s*=\s*"
            r"new\s+char\[\]\s*\{(?P<body>.*?)\};",
            text,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "Build 42.19 Translator.java authority is malformed")
        assert match is not None
        values = tuple(
            int(value, 16)
            for value in re.findall(r"'\\u([0-9A-Fa-f]{4})'", match.group("body"))
        )
        self.assertEqual(len(values), 44)
        self.assertEqual(len(set(values)), 44)
        return values

    @staticmethod
    def translator_declaration(code_points: tuple[int, ...]) -> str:
        entries = ",\n".join(f"        '\\u{code_point:04x}'" for code_point in code_points)
        return (
            "    public static final char[] LOOKALIKE_CHARS = new char[]{\n"
            f"{entries}\n"
            "    };\n"
        )

    def write_translator_fixture(self, root: Path) -> Path:
        authority = root / "Translator.java"
        authority.write_text(
            "public final class Translator {\n"
            f"{self.translator_declaration(self.translator_code_points())}"
            "}\n",
            encoding="utf-8",
        )
        return authority

    def test_translator_confusable_scan_covers_all_authority_characters_and_raw_order(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authority = self.write_translator_fixture(root)
            code_points = self.translator_code_points()
            literal = "".join(chr(code_point) for code_point in code_points)
            raw = ('{"all":"' + literal + '","escaped":"\\u2014",'
                   '"allowed":"ASCII controls: \\n \\t; café Ω"}\n').encode("utf-8")
            source = root / "source.json"
            release = root / "release.json"
            source.write_bytes(raw)
            release.write_bytes(raw)

            first = PATTERN_MODULE.scan_translator_confusable_json(source, release, authority)
            second = PATTERN_MODULE.scan_translator_confusable_json(source, release, authority)
            self.assertEqual(first, second)
            self.assertEqual(first["errors"], [])
            self.assertEqual(len(first["findings"]), 44)
            self.assertEqual(
                [row["code_point"] for row in first["findings"]],
                [f"U+{code_point:04X}" for code_point in code_points],
            )
            self.assertTrue(all(row["json_key"] == "all" for row in first["findings"]))
            self.assertTrue(all(row["source_release_side"] == "source-and-release" for row in first["findings"]))

    def test_translator_confusable_scan_reports_duplicates_and_utf8_coordinates(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authority = self.write_translator_fixture(root)
            raw = '{\n  "key": "café—x—"\n}\n'.encode("utf-8")
            source = root / "source.json"
            release = root / "release.json"
            source.write_bytes(raw)
            release.write_bytes(raw)

            result = PATTERN_MODULE.scan_translator_confusable_json(source, release, authority)
            self.assertEqual(result["errors"], [])
            self.assertEqual(len(result["findings"]), 2)
            expected_offsets = [index for index in range(len(raw)) if raw.startswith("—".encode("utf-8"), index)]
            self.assertEqual([row["byte_offset"] for row in result["findings"]], expected_offsets)
            self.assertEqual([row["line"] for row in result["findings"]], [2, 2])
            self.assertEqual([row["column"] for row in result["findings"]], [15, 17])
            self.assertEqual([row["json_key"] for row in result["findings"]], ["key", "key"])

    def test_translator_confusable_scan_fails_closed_for_invalid_inputs_and_parity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authority = self.write_translator_fixture(root)
            source = root / "source.json"
            release = root / "release.json"
            valid = b'{"key":"safe"}\n'
            source.write_bytes(valid)
            release.write_bytes(valid)

            cases = []
            cases.append((root / "missing-authority.java", source, release, "missing-authority"))
            empty_authority = root / "empty-authority.java"
            empty_authority.write_text("class Translator {}\n", encoding="utf-8")
            cases.append((empty_authority, source, release, "missing-authority-inventory"))
            mismatched_authority = root / "mismatched-authority.java"
            mismatched_authority.write_text(
                authority.read_text(encoding="utf-8").replace("'\\u2019'", "'\\u2018'", 1),
                encoding="utf-8",
            )
            cases.append(
                (mismatched_authority, source, release, "authority-inventory-mismatch")
            )
            missing_source = root / "missing.json"
            cases.append((authority, missing_source, release, "missing-file"))
            invalid_utf8 = root / "invalid-utf8.json"
            invalid_utf8.write_bytes(b'{"key":"\xff"}')
            cases.append((authority, invalid_utf8, release, "invalid-utf8"))
            invalid_json = root / "invalid-json.json"
            invalid_json.write_text('{"key":', encoding="utf-8")
            cases.append((authority, invalid_json, release, "invalid-json"))
            mismatch = root / "mismatch.json"
            mismatch.write_bytes(b'{"key":"different"}\n')
            cases.append((authority, source, mismatch, "source-release-parity-mismatch"))

            for authority_case, source_case, release_case, expected_kind in cases:
                with self.subTest(expected_kind=expected_kind):
                    result = PATTERN_MODULE.scan_translator_confusable_json(
                        source_case, release_case, authority_case
                    )
                    self.assertEqual(result["findings"], [])
                    self.assertIn(expected_kind, {row["kind"] for row in result["errors"]})

    def test_translator_authority_declaration_cardinality_and_inventory_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.json"
            release = root / "release.json"
            source.write_bytes(b'{"key":"safe"}\n')
            release.write_bytes(source.read_bytes())
            code_points = self.translator_code_points()
            valid = self.translator_declaration(code_points)
            malformed = "    public static final char[] LOOKALIKE_CHARS = notAnArray;\n"
            swapped = (code_points[1], code_points[0], *code_points[2:])
            cases = (
                ("zero", "class Translator {}\n", "missing-authority-inventory"),
                ("one-valid", f"class Translator {{\n{valid}}}\n", None),
                ("one-malformed", f"class Translator {{\n{malformed}}}\n", "malformed-authority-inventory"),
                ("duplicate-valid", f"class Translator {{\n{valid}{valid}}}\n", "multiple-authority-inventories"),
                ("valid-malformed", f"class Translator {{\n{valid}{malformed}}}\n", "multiple-authority-inventories"),
                ("malformed-valid", f"class Translator {{\n{malformed}{valid}}}\n", "multiple-authority-inventories"),
                (
                    "duplicate-code-point",
                    f"class Translator {{\n{self.translator_declaration(code_points + (code_points[0],))}}}\n",
                    "authority-inventory-mismatch",
                ),
                (
                    "wrong-count",
                    f"class Translator {{\n{self.translator_declaration(code_points[:-1])}}}\n",
                    "authority-inventory-mismatch",
                ),
                (
                    "wrong-content",
                    f"class Translator {{\n{self.translator_declaration((0x0041, *code_points[1:]))}}}\n",
                    "authority-inventory-mismatch",
                ),
                (
                    "wrong-order",
                    f"class Translator {{\n{self.translator_declaration(swapped)}}}\n",
                    "authority-inventory-mismatch",
                ),
            )

            for name, text, expected_kind in cases:
                with self.subTest(name=name):
                    authority = root / f"{name}.java"
                    authority.write_text(text, encoding="utf-8")
                    first = PATTERN_MODULE.scan_translator_confusable_json(
                        source, release, authority
                    )
                    second = PATTERN_MODULE.scan_translator_confusable_json(
                        source, release, authority
                    )
                    self.assertEqual(first, second)
                    self.assertEqual(first["findings"], [])
                    self.assertEqual(
                        [row["kind"] for row in first["errors"]],
                        [] if expected_kind is None else [expected_kind],
                    )

    def test_translator_confusable_errors_have_deterministic_order(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authority = self.write_translator_fixture(root)
            missing_source = root / "missing.json"
            invalid_release = root / "invalid.json"
            invalid_release.write_bytes(b'{"key":"\xff"}')

            first = PATTERN_MODULE.scan_translator_confusable_json(
                missing_source, invalid_release, authority
            )
            second = PATTERN_MODULE.scan_translator_confusable_json(
                missing_source, invalid_release, authority
            )
            self.assertEqual(first, second)
            self.assertEqual(first["findings"], [])
            self.assertEqual(
                [row["kind"] for row in first["errors"]],
                ["invalid-utf8", "missing-file"],
            )

    def test_frozen_pre_remediation_translation_confusable_inventory(self) -> None:
        inventory = {
            "UI_UT_mushroomerDesc": "fungi — the edible",
            "UI_UT_badteethDesc": "not reduced — it just hurts",
            "UI_UT_heavilybleedingwoundsDesc": "normal — wounds bleed",
            "UI_UT_mundaneDesc": "×0.8 (−20 percent)",
            "UI_UT_antigunDesc": "×0.5 (−50 percent)",
            "UI_UT_flateartherDesc": "×0.7 (−30 percent)",
            "UI_UT_ludditeDesc": "×0.6 (−40 percent)",
            "UI_UT_owlpersonDesc": "zero — purely a lifestyle trait",
            "UI_UT_larkpersonDesc": "zero — purely a lifestyle trait",
            "UI_UT_asceticDesc": "slowly — your body needs less food",
            "UI_UT_optimistDesc": "−0.06 and −0.04",
            "UI_UT_mstoptimistDesc": "−0.08 or −0.03",
            "UI_UT_maniacDesc": "−0.15 and −0.2",
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            authority = self.write_translator_fixture(root)
            raw = (json.dumps(inventory, ensure_ascii=False) + "\n").encode("utf-8")
            source = root / "source.json"
            release = root / "release.json"
            source.write_bytes(raw)
            release.write_bytes(raw)
            result = PATTERN_MODULE.scan_translator_confusable_json(
                source, release, authority
            )

        self.assertEqual(result["errors"], [])
        self.assertEqual(len(result["findings"]), 16)
        self.assertEqual(len({row["json_key"] for row in result["findings"]}), 13)
        self.assertEqual(
            {code_point: sum(row["code_point"] == code_point for row in result["findings"])
             for code_point in ("U+2014", "U+2212")},
            {"U+2014": 6, "U+2212": 10},
        )

    def test_current_translation_confusable_inventory_is_zero_and_gate_passes(self) -> None:
        repository_root = CAMPAIGN_ROOT.parents[1]
        source = (
            repository_root
            / "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
        )
        release = (
            repository_root
            / "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
        )
        authority = repository_root.parent / "PZCodebase/Java/source/zombie/core/Translator.java"
        result = PATTERN_MODULE.scan_translator_confusable_json(source, release, authority)
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["findings"], [])
        self.assertEqual(PATTERN_MODULE.canonical_translator_confusable_gate_errors(), [])

    def test_translator_confusable_gate_fails_for_one_reintroduced_character(self) -> None:
        for rejected in ("—", "−"):
            with self.subTest(rejected=rejected), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source = (
                    root / "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
                )
                release = (
                    root
                    / "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json"
                )
                source.parent.mkdir(parents=True)
                release.parent.mkdir(parents=True)
                raw = (
                    json.dumps(
                        {"key": f"safe {rejected} unsafe"}, ensure_ascii=False
                    )
                    + "\n"
                ).encode("utf-8")
                source.write_bytes(raw)
                release.write_bytes(raw)
                pzcodebase = root / "PZCodebase"
                authority = pzcodebase / "Java/source/zombie/core/Translator.java"
                authority.parent.mkdir(parents=True)
                authority.write_text(
                    "public final class Translator {\n"
                    f"{self.translator_declaration(self.translator_code_points())}"
                    "}\n",
                    encoding="utf-8",
                )

                errors = PATTERN_MODULE.canonical_translator_confusable_gate_errors(
                    root, pzcodebase
                )
                self.assertEqual(len(errors), 1)
                self.assertIn("Translator confusable finding", errors[0])

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
