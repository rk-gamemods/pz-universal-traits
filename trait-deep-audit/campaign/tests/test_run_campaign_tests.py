"""Contract tests for the bounded parallel campaign test runner."""

from __future__ import annotations

import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "run_campaign_tests.py"
SPEC = importlib.util.spec_from_file_location("run_campaign_tests", MODULE_PATH)
assert SPEC and SPEC.loader
RUNNER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = RUNNER
SPEC.loader.exec_module(RUNNER)


class RunnerContractTests(unittest.TestCase):
    def test_discovery_is_sorted_and_missing_tests_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "test_z.py").write_text("", encoding="utf-8")
            (root / "test_a.py").write_text("", encoding="utf-8")
            (root / "helper.py").write_text("", encoding="utf-8")
            self.assertEqual([path.name for path in RUNNER.discover_tests(root)], ["test_a.py", "test_z.py"])
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RUNNER.RunnerError, "no campaign tests"):
                RUNNER.discover_tests(Path(directory))

    def test_suite_preserves_order_limits_workers_and_continues_after_failure(self) -> None:
        tests = [Path(f"test_{index}.py") for index in range(8)]
        lock = threading.Lock()
        active = 0
        peak = 0
        completed: list[str] = []

        def worker(path: Path, _output: Path) -> RUNNER.ModuleResult:
            nonlocal active, peak
            with lock:
                active += 1
                peak = max(peak, active)
            time.sleep(0.02)
            with lock:
                active -= 1
                completed.append(path.name)
            status = "failed" if path.name == "test_1.py" else "passed"
            return RUNNER.ModuleResult(path.name, status, 1 if status == "failed" else 0, 0.02, (path.stem,))

        results = RUNNER.run_suite(tests, Path("unused"), worker=worker)
        self.assertEqual([result.module for result in results], [path.name for path in tests])
        self.assertEqual(peak, 4)
        self.assertEqual(set(completed), {path.name for path in tests})
        self.assertEqual(results[1].status, "failed")

    def test_launch_error_fails_closed(self) -> None:
        launch_options = {}

        def fail_launch(*_args, **kwargs):
            launch_options.update(kwargs)
            raise OSError("injected launch failure")

        with tempfile.TemporaryDirectory() as directory:
            result = RUNNER.run_module(Path(directory) / "test_x.py", Path(directory), popen=fail_launch)
        self.assertEqual(result.status, "launch-error")
        self.assertIn("injected launch failure", result.detail)
        if os.name == "nt":
            self.assertEqual(
                launch_options["creationflags"] & subprocess.CREATE_NO_WINDOW,
                subprocess.CREATE_NO_WINDOW,
            )
        else:
            self.assertIs(launch_options["start_new_session"], True)

    def _write_module(self, root: Path, body: str) -> Path:
        path = root / "test_fixture.py"
        path.write_text("import unittest\n" + body, encoding="utf-8")
        return path

    def test_timeout_is_bounded_and_temp_output_is_removable(self) -> None:
        timeout_pid = None
        interrupted_pid = None
        started = time.perf_counter()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pid_path = root / "descendant.pid"
            test_path = self._write_descendant_module(root, pid_path)
            output = root / "output"
            output.mkdir()
            result = RUNNER.run_module(test_path, output, timeout=0.2)
            self.assertEqual(result.status, "timeout")
            timeout_pid = int(pid_path.read_text(encoding="ascii"))
            self.assertTrue(result.output_path and result.output_path.is_file())
        self.assertLess(time.perf_counter() - started, 3.0)
        self.assertFalse(root.exists())
        self._assert_pid_exits(timeout_pid)

        started = time.perf_counter()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pid_path = root / "interrupted-descendant.pid"
            test_path = self._write_descendant_module(root, pid_path)
            output = root / "output"
            output.mkdir()

            def interrupt_after_descendant_starts(_futures):
                deadline = time.monotonic() + 2
                while not pid_path.is_file() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(pid_path.is_file())
                raise KeyboardInterrupt
                yield

            with mock.patch.object(
                RUNNER, "as_completed", interrupt_after_descendant_starts
            ), self.assertRaises(KeyboardInterrupt):
                RUNNER.run_suite([test_path], output)
            interrupted_pid = int(pid_path.read_text(encoding="ascii"))
        self.assertLess(time.perf_counter() - started, 3.0)
        self.assertFalse(root.exists())
        self._assert_pid_exits(interrupted_pid)

    def _write_descendant_module(self, root: Path, pid_path: Path) -> Path:
        return self._write_module(
            root,
            "import pathlib, subprocess, sys, time\n"
            "class T(unittest.TestCase):\n"
            "    def test_descendant(self):\n"
            "        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])\n"
            f"        pathlib.Path({str(pid_path)!r}).write_text(str(child.pid), encoding='ascii')\n"
            "        time.sleep(30)\n",
        )

    def _assert_pid_exits(self, pid: int) -> None:
        deadline = time.monotonic() + 1
        while self._pid_alive(pid) and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertFalse(self._pid_alive(pid))

    def _pid_alive(self, pid: int) -> bool:
        if os.name != "nt":
            stat_path = Path(f"/proc/{pid}/stat")
            if stat_path.is_file():
                try:
                    if stat_path.read_text(encoding="ascii").split()[2] == "Z":
                        return False
                except (OSError, IndexError):
                    pass
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                return False
            return True
        import ctypes
        from ctypes import wintypes

        synchronize = 0x00100000
        handle = ctypes.windll.kernel32.OpenProcess(synchronize, False, pid)
        if not handle:
            return False
        try:
            return ctypes.windll.kernel32.WaitForSingleObject(wintypes.HANDLE(handle), 0) == 0x102
        finally:
            ctypes.windll.kernel32.CloseHandle(wintypes.HANDLE(handle))

    def test_output_is_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            test_path = self._write_module(
                root,
                "class T(unittest.TestCase):\n    def test_noise(self): print('x' * 2000000)\n",
            )
            output = root / "output"
            output.mkdir()
            result = RUNNER.run_module(test_path, output)
            self.assertEqual(result.status, "output-limit")
            self.assertLessEqual(result.output_path.stat().st_size, RUNNER.MAX_OUTPUT_BYTES)

    def test_success_and_failure_results_are_parsed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "output"
            output.mkdir()
            success = self._write_module(root, "class T(unittest.TestCase):\n    def test_ok(self): pass\n")
            passed = RUNNER.run_module(success, output)
            self.assertEqual((passed.status, len(passed.test_ids)), ("passed", 1))
            failure = self._write_module(root, "class T(unittest.TestCase):\n    def test_bad(self): self.fail('boom')\n")
            failed = RUNNER.run_module(failure, output)
            self.assertEqual((failed.status, len(failed.test_ids)), ("failed", 1))

    def test_malformed_worker_result_fails_closed(self) -> None:
        result = RUNNER.run_suite(
            [Path("test_x.py")],
            Path("unused"),
            worker=lambda _path, _output: object(),
        )[0]
        self.assertEqual(result.status, "internal-error")

    def test_main_cleans_temp_directory_on_success_and_failure(self) -> None:
        created: list[Path] = []
        real_temp = tempfile.TemporaryDirectory

        class TrackingTemporaryDirectory(real_temp):
            def __enter__(self):
                value = super().__enter__()
                created.append(Path(value))
                return value

        cases = (
            (RUNNER.ModuleResult("test_x.py", "passed", 0, 0.1, ("T.test_x",)), 0),
            (RUNNER.ModuleResult("test_x.py", "failed", 1, 0.1, ("T.test_x",)), 1),
        )
        for results, expected in cases:
            with self.subTest(expected=expected), mock.patch.object(
                RUNNER, "discover_tests", return_value=[Path("test_x.py")]
            ), mock.patch.object(RUNNER, "run_suite", return_value=[results]), mock.patch.object(
                RUNNER.tempfile, "TemporaryDirectory", TrackingTemporaryDirectory
            ):
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    self.assertEqual(RUNNER.main(), expected)
                self.assertFalse(created[-1].exists())

    def test_main_fails_closed_on_empty_discovery(self) -> None:
        with mock.patch.object(RUNNER, "discover_tests", side_effect=RUNNER.RunnerError("no tests")):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(RUNNER.main(), 1)


if __name__ == "__main__":
    unittest.main()
