import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


generator = load("generate_smoke_pings")
checker = load("check_smoke_log")
gate = load("run_update_safe_gate")


def inventory():
    return {"unique_surfaces": [
        {"receiver": "player", "method": "getAlpha", "verification_kind": "method_call"},
        {"receiver": "ISEatFoodAction", "method": "getBeta", "verification_kind": "method_call"}],
        "call_sites": [
        {"receiver": "player", "method": "getAlpha", "arg_count": 0, "relative_file": "a.lua"},
        {"receiver": "ISEatFoodAction", "method": "getBeta", "arg_count": 0, "relative_file": "b.lua"}]}


class GeneratorTests(unittest.TestCase):
    def test_runtime_identity_is_not_in_canonical_bytes(self):
        emitted, _ = generator.build_plan(inventory(), {})
        source = generator.generate_lua(emitted)
        self.assertNotIn("run-1", source)
        self.assertIn("UT_SMOKE_RUN_ID", source)
        self.assertIn("UT_SMOKE_CHALLENGE", source)
        self.assertIn("getTimestampMs()", source)

    def test_global_member_must_be_callable(self):
        source = generator.generate_lua([("ISEatFoodAction", "getBeta")])
        self.assertIn("type(ISEatFoodAction.getBeta) ~= 'function'", source)

    def test_atomic_write_preserves_destination_when_replace_is_interrupted(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "out"
            target.write_text("old", encoding="utf-8")
            with mock.patch.object(generator.os, "replace", side_effect=OSError("interrupted")):
                with self.assertRaises(OSError):
                    generator.atomic_write(target, "new")
            self.assertEqual(target.read_text(encoding="utf-8"), "old")
            self.assertEqual(list(Path(temp).iterdir()), [target])

    def test_report_is_exact_emitted_surface_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "inventory.json"
            source.write_text(json.dumps(inventory()), encoding="utf-8")
            _, report = generator.generate(source, None)
            self.assertEqual(report["surfaces"][-2:], ["ISEatFoodAction.getBeta", "player.getAlpha"])
            self.assertEqual(report["calls"][-2:], [
                {"surface": "print", "count": 12, "evidence": "protocol"},
                {"surface": "Events.OnGameStart.Add", "count": 1, "evidence": "protocol"}])
            self.assertIn({"surface": "player.getInventory", "count": 1, "evidence": "marker"},
                          report["calls"])

    def test_every_setup_and_emitted_call_is_marked_with_exact_multiplicity(self):
        emitted = [("player", "getStats"), ("player", "getAlpha")]
        source = generator.generate_lua(emitted)
        manifest = generator.call_manifest(emitted)
        for item in (entry for entry in manifest if entry["evidence"] == "marker"):
            self.assertEqual(source.count(f"mark('{item['surface']}')"), item["count"])
        self.assertEqual(next(x for x in manifest if x["surface"] == "player.getStats")["count"], 2)

    def test_pair_promotion_rolls_back_if_second_promotion_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            output, report_path = Path(temp) / "out.lua", Path(temp) / "report.json"
            output.write_text("old-output", encoding="utf-8")
            report_path.write_text("old-report", encoding="utf-8")
            source = generator.generate_lua([])
            calls_manifest = generator.call_manifest([])
            report = {"version": 2, "status": "generated",
                      "surfaces": [x["surface"] for x in calls_manifest if x["evidence"] == "marker"],
                      "calls": calls_manifest,
                      "omitted": {}}
            real_replace = generator.os.replace
            calls = 0

            def fail_second_promotion(src, dst):
                nonlocal calls
                calls += 1
                if calls == 4:
                    raise OSError("second promotion interrupted")
                return real_replace(src, dst)

            with mock.patch.object(generator.os, "replace", side_effect=fail_second_promotion):
                with self.assertRaises(OSError):
                    generator.promote_pair(output, source, report_path, report)
            self.assertEqual(output.read_text(encoding="utf-8"), "old-output")
            self.assertEqual(report_path.read_text(encoding="utf-8"), "old-report")
            self.assertEqual(sorted(p.name for p in Path(temp).iterdir()), ["out.lua", "report.json"])

    def test_pair_validation_failure_cleans_stages_without_replacing_either_file(self):
        with tempfile.TemporaryDirectory() as temp:
            output, report_path = Path(temp) / "out.lua", Path(temp) / "report.json"
            output.write_text("old-output", encoding="utf-8")
            report_path.write_text("old-report", encoding="utf-8")
            with mock.patch.object(generator, "_validate_staged_pair", side_effect=ValueError("bad stage")):
                with self.assertRaises(ValueError):
                    generator.promote_pair(output, "new-output", report_path, {})
            self.assertEqual(output.read_text(encoding="utf-8"), "old-output")
            self.assertEqual(report_path.read_text(encoding="utf-8"), "old-report")
            self.assertEqual(sorted(p.name for p in Path(temp).iterdir()), ["out.lua", "report.json"])

    def test_second_stage_failure_cleans_first_stage_without_replacing_destinations(self):
        with tempfile.TemporaryDirectory() as temp:
            output, report_path = Path(temp) / "out.lua", Path(temp) / "report.json"
            output.write_text("old-output", encoding="utf-8")
            report_path.write_text("old-report", encoding="utf-8")
            real_stage = generator._stage_text
            calls = 0

            def fail_report_stage(path, text):
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("report staging interrupted")
                return real_stage(path, text)

            with mock.patch.object(generator, "_stage_text", side_effect=fail_report_stage):
                with self.assertRaises(OSError):
                    generator.promote_pair(output, "new-output", report_path, {})
            self.assertEqual(output.read_text(encoding="utf-8"), "old-output")
            self.assertEqual(report_path.read_text(encoding="utf-8"), "old-report")
            self.assertEqual(sorted(p.name for p in Path(temp).iterdir()), ["out.lua", "report.json"])


class CheckerTests(unittest.TestCase):
    def check(self, rows, surfaces=("player.getAlpha",), start=100, end=200):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / "log"
            manifest = Path(temp) / "manifest"
            log.write_text("\n".join(rows), encoding="utf-8")
            calls = [{"surface": surface, "count": 1, "evidence": "marker"} for surface in surfaces]
            calls.extend([
                {"surface": "getTimestampMs", "count": len(surfaces), "evidence": "protocol"},
                {"surface": "print", "count": len(surfaces), "evidence": "protocol"},
                {"surface": "Events.OnGameStart.Add", "count": 1, "evidence": "protocol"},
            ])
            manifest.write_text(json.dumps({"version": 2, "status": "generated",
                                             "surfaces": list(surfaces), "calls": calls}), encoding="utf-8")
            return checker.validate(log, manifest, "wanted", "fresh", start, end)

    def marker(self, surface="player.getAlpha", run="wanted", challenge="fresh", timestamp=150):
        return f"[UT_SMOKE] run={run} challenge={challenge} timestamp={timestamp} surface={surface}"

    def test_exact_once_passes(self):
        self.assertEqual(self.check([self.marker()])["status"], "clean")

    def test_replay_before_interval_does_not_prove_run(self):
        result = self.check([self.marker(timestamp=99)])
        self.assertEqual(result["missing"], ["player.getAlpha"])

    def test_mixed_runs_are_rejected(self):
        result = self.check([self.marker(), self.marker(run="foreign")])
        self.assertTrue(result["foreign_markers"])

    def test_duplicates_extras_and_missing_are_rejected(self):
        result = self.check([self.marker(), self.marker(), self.marker("other.x")],
                            surfaces=("player.getAlpha", "missing.x"))
        self.assertEqual(result["duplicates"], ["player.getAlpha"])
        self.assertEqual(result["extras"], ["other.x"])
        self.assertEqual(result["missing"], ["missing.x"])

    def test_unexpected_surface_is_extra_not_duplicate(self):
        result = self.check([self.marker(), self.marker("other.x")])
        self.assertEqual(result["duplicates"], [])
        self.assertEqual(result["extras"], ["other.x"])

    def test_missing_inputs_and_malformed_manifest_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            log, manifest = Path(temp) / "log", Path(temp) / "manifest"
            log.write_text("", encoding="utf-8")
            manifest.write_text("{", encoding="utf-8")
            with self.assertRaises(json.JSONDecodeError):
                checker.validate(log, manifest, "x", "y", 1, 2)

    def test_split_line_ut_error_inside_trace_block_fails(self):
        result = self.check(["ERROR: General error", "stack traceback:",
                             "    at UniversalTraits/UT_Traits.lua:42", self.marker()])
        self.assertTrue(result["errors"])

    def test_error_header_followed_by_unrelated_line_does_not_attach_to_later_ut_path(self):
        result = self.check(["ERROR: unrelated subsystem", "normal gameplay message",
                             "UniversalTraits/UT_Traits.lua loaded", self.marker()])
        self.assertFalse(result["errors"])

    def test_direct_ut_loaded_line_after_error_is_not_a_stack_frame(self):
        result = self.check(["ERROR: unrelated subsystem",
                             "UniversalTraits/UT_Traits.lua loaded", self.marker()])
        self.assertFalse(result["errors"])


class GateTests(unittest.TestCase):
    def test_smoke_proof_arguments_are_mandatory(self):
        for argv in ([], ["--run-id", "r"], ["--run-id", "r", "--smoke-log", "x"]):
            with self.assertRaises(SystemExit):
                gate.parse_args(argv)

    def test_empty_failed_or_malformed_steps_never_pass(self):
        self.assertEqual(gate.gate_status([]), "fail")
        self.assertEqual(gate.gate_status([{}]), "fail")
        self.assertEqual(gate.gate_status([{"returncode": 1}]), "fail")

    def test_missing_tool_and_timeout_are_nonclean(self):
        with mock.patch.object(gate.subprocess, "run", side_effect=OSError("missing")):
            self.assertNotEqual(gate.run_step("x", ["missing"], 1)["returncode"], 0)
        with mock.patch.object(gate.subprocess, "run", side_effect=gate.subprocess.TimeoutExpired(["x"], 1)):
            self.assertNotEqual(gate.run_step("x", ["x"], 1)["returncode"], 0)

    def test_source_and_release_must_both_match(self):
        with tempfile.TemporaryDirectory() as temp:
            generated = Path(temp) / "generated"
            source = Path(temp) / "source"
            release = Path(temp) / "release"
            generated.write_bytes(b"a")
            source.write_bytes(b"a")
            release.write_bytes(b"b")
            self.assertEqual(generated.read_bytes(), source.read_bytes())
            self.assertNotEqual(generated.read_bytes(), release.read_bytes())

    def test_mutation_is_a_gate_failure(self):
        steps = [{"returncode": 0}, {"returncode": 1, "label": "Worktree mutation check"}]
        self.assertEqual(gate.gate_status(steps), "fail")

    def invoke_main(self, defect=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, release = root / "source.lua", root / "release.lua"
            source.write_bytes(b"generated")
            release.write_bytes(b"generated" if defect != "mismatch" else b"different")
            args = SimpleNamespace(lua_exe=Path("lua"), baseline_file=Path("baseline"),
                                   smoke_log=Path("smoke.log"), run_id="run", challenge="challenge",
                                   max_age_hours=4.0, smoke_allowlist=None, step_timeout_seconds=1.0)
            snapshots = [{"same": (1, "x")}, {"same": (1, "x")}]
            if defect == "mutation":
                snapshots[1] = {"changed": (2, "y")}

            def runner(label, command, timeout):
                result = {"label": label, "returncode": 0, "stdout_tail": "", "stderr_tail": ""}
                step_defects = {"ut_core": "UT_CORE tests",
                                "universal_traits": "UniversalTraits tests",
                                "pz_api": "PZ API verifier"}
                if step_defects.get(defect) == label:
                    result["returncode"] = 1
                    return result
                if label == "Smoke generation":
                    if defect in {"generation", "missing", "timeout"}:
                        result["returncode"] = 124 if defect == "timeout" else 1
                        return result
                    generated = Path(command[command.index("--output") + 1])
                    report = Path(command[command.index("--report") + 1])
                    generated.write_bytes(b"generated")
                    if defect == "malformed_report":
                        report.write_text("{", encoding="utf-8")
                    else:
                        report.write_text(json.dumps({"version": 2, "status": "generated",
                            "surfaces": ["getPlayer"],
                            "calls": [
                                {"surface": "getPlayer", "count": 1, "evidence": "marker"},
                                {"surface": "getTimestampMs", "count": 1, "evidence": "protocol"},
                                {"surface": "print", "count": 1, "evidence": "protocol"},
                                {"surface": "Events.OnGameStart.Add", "count": 1,
                                 "evidence": "protocol"}]}),
                            encoding="utf-8")
                elif label == "Smoke log validation" and defect == "smoke_check":
                    result["returncode"] = 1
                return result

            with mock.patch.object(gate, "parse_args", return_value=args), \
                    mock.patch.object(gate, "snapshot_tree", side_effect=snapshots), \
                    mock.patch.object(gate, "run_step", side_effect=runner), \
                    mock.patch.object(gate, "GENERATED_SMOKE", source), \
                    mock.patch.object(gate, "RELEASE_SMOKE", release), \
                    mock.patch("builtins.print"):
                return gate.main([])

    def test_orchestration_boundary_returns_one_for_each_gate_defect(self):
        for defect in ("generation", "malformed_report", "mismatch", "smoke_check",
                       "mutation", "timeout", "missing"):
            with self.subTest(defect=defect):
                self.assertEqual(self.invoke_main(defect), 1)

    def test_each_prerequisite_step_failure_returns_one_from_main(self):
        for defect in ("ut_core", "universal_traits", "pz_api"):
            with self.subTest(defect=defect):
                self.assertEqual(self.invoke_main(defect), 1)


if __name__ == "__main__":
    unittest.main()
