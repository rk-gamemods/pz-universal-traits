"""Regression tests for campaign normalization and structural validation."""

from __future__ import annotations

import importlib.util
import json
import hashlib
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
        ]
        before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in outputs}
        scripts = [
            MODULE_PATH,
            PATTERN_MODULE_PATH,
            VALIDATOR_MODULE_PATH,
            MANIFEST_MODULE_PATH,
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


class CampaignManifestTests(unittest.TestCase):
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


class RecurringPatternTests(unittest.TestCase):
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
