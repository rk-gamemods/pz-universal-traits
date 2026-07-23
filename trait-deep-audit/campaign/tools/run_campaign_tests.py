#!/usr/bin/env python3
"""Run campaign test modules concurrently with process isolation and bounded output."""

from __future__ import annotations

import hashlib
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed, wait
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


CAMPAIGN_ROOT = Path(__file__).resolve().parents[1]
TEST_ROOT = CAMPAIGN_ROOT / "tests"
MAX_WORKERS = 4
MODULE_TIMEOUT_SECONDS = 300.0
MAX_OUTPUT_BYTES = 1_000_000
TAIL_BYTES = 16_384
POLL_SECONDS = 0.01
TERMINATION_WAIT_SECONDS = 1.0
READER_JOIN_SECONDS = 1.0
EXECUTOR_SHUTDOWN_SECONDS = 4.0
START_GATE_CODE = (
    "import os,subprocess,sys; "
    "token=sys.stdin.buffer.read(1); "
    "token == b'1' or sys.exit(125); "
    "options={'creationflags': 0x08000000} if os.name == 'nt' else {}; "
    "raise SystemExit(subprocess.call([sys.executable, *sys.argv[1:]], "
    "stdout=sys.stdout, stderr=sys.stderr, **options))"
)
RAN_RE = re.compile(rb"^Ran (\d+) tests? in ", re.MULTILINE)
RESULT_RE = re.compile(rb"^(.+?) \.\.\. (?:ok|FAIL|ERROR|skipped .+)\r?$", re.MULTILINE)
TEST_ID_RE = re.compile(r"^test[^ ]+ \([^()]+\.([^.()]+)\.(test[^.()]+)\)$")


class RunnerError(RuntimeError):
    """The runner could not establish a complete trustworthy test result."""


@dataclass(frozen=True)
class ModuleResult:
    module: str
    status: str
    returncode: int | None
    duration_seconds: float
    test_ids: tuple[str, ...]
    detail: str = ""
    output_path: Path | None = None


class _ProcessContainment:
    def terminate(self) -> str:
        raise NotImplementedError

    def close(self) -> None:
        pass


class _PosixProcessGroup(_ProcessContainment):
    def __init__(self, process_group: int) -> None:
        self.process_group = process_group

    def terminate(self) -> str:
        try:
            os.killpg(self.process_group, signal.SIGKILL)
        except ProcessLookupError:
            return ""
        except OSError as exc:
            return f"process-group termination failed: {exc}"
        return ""


class _WindowsJob(_ProcessContainment):
    def __init__(self, kernel32, handle) -> None:
        self.kernel32 = kernel32
        self.handle = handle

    def terminate(self) -> str:
        if not self.handle:
            return ""
        if not self.kernel32.TerminateJobObject(self.handle, 1):
            import ctypes

            return f"job termination failed: {ctypes.get_last_error()}"
        return ""

    def close(self) -> None:
        if self.handle:
            self.kernel32.CloseHandle(self.handle)
            self.handle = None


def _create_windows_job(process: subprocess.Popen) -> _WindowsJob:
    import ctypes
    from ctypes import wintypes

    class BasicLimitInformation(ctypes.Structure):
        _fields_ = [
            ("PerProcessUserTimeLimit", ctypes.c_longlong),
            ("PerJobUserTimeLimit", ctypes.c_longlong),
            ("LimitFlags", wintypes.DWORD),
            ("MinimumWorkingSetSize", ctypes.c_size_t),
            ("MaximumWorkingSetSize", ctypes.c_size_t),
            ("ActiveProcessLimit", wintypes.DWORD),
            ("Affinity", ctypes.c_size_t),
            ("PriorityClass", wintypes.DWORD),
            ("SchedulingClass", wintypes.DWORD),
        ]

    class IoCounters(ctypes.Structure):
        _fields_ = [
            ("ReadOperationCount", ctypes.c_ulonglong),
            ("WriteOperationCount", ctypes.c_ulonglong),
            ("OtherOperationCount", ctypes.c_ulonglong),
            ("ReadTransferCount", ctypes.c_ulonglong),
            ("WriteTransferCount", ctypes.c_ulonglong),
            ("OtherTransferCount", ctypes.c_ulonglong),
        ]

    class ExtendedLimitInformation(ctypes.Structure):
        _fields_ = [
            ("BasicLimitInformation", BasicLimitInformation),
            ("IoInfo", IoCounters),
            ("ProcessMemoryLimit", ctypes.c_size_t),
            ("JobMemoryLimit", ctypes.c_size_t),
            ("PeakProcessMemoryUsed", ctypes.c_size_t),
            ("PeakJobMemoryUsed", ctypes.c_size_t),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel32.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    kernel32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        raise OSError(ctypes.get_last_error(), "CreateJobObjectW failed")
    containment = _WindowsJob(kernel32, job)
    information = ExtendedLimitInformation()
    information.BasicLimitInformation.LimitFlags = 0x00002000
    if not kernel32.SetInformationJobObject(
        job, 9, ctypes.byref(information), ctypes.sizeof(information)
    ):
        error = ctypes.get_last_error()
        containment.close()
        raise OSError(error, "SetInformationJobObject failed")
    process_handle = wintypes.HANDLE(int(process._handle))
    if not kernel32.AssignProcessToJobObject(job, process_handle):
        error = ctypes.get_last_error()
        containment.close()
        raise OSError(error, "AssignProcessToJobObject failed")
    return containment


def _create_containment(process: subprocess.Popen) -> _ProcessContainment:
    if os.name == "nt":
        return _create_windows_job(process)
    return _PosixProcessGroup(process.pid)


def discover_tests(test_root: Path = TEST_ROOT) -> list[Path]:
    tests = sorted(path for path in test_root.glob("test_*.py") if path.is_file())
    if not tests:
        raise RunnerError(f"no campaign tests discovered under {test_root}")
    return tests


def _bounded_reader(
    stream,
    output_path: Path,
    overflow: threading.Event,
    errors: list[str],
) -> None:
    written = 0
    try:
        with output_path.open("wb") as output:
            read_chunk = getattr(stream, "read1", stream.read)
            while True:
                chunk = read_chunk(64 * 1024)
                if not chunk:
                    return
                remaining = MAX_OUTPUT_BYTES - written
                if remaining > 0:
                    output.write(chunk[:remaining])
                    written += min(len(chunk), remaining)
                if len(chunk) > remaining:
                    overflow.set()
    except (OSError, ValueError) as exc:
        errors.append(f"output reader failed: {exc}")


def _bounded_wait(process: subprocess.Popen) -> tuple[int | None, str]:
    try:
        return process.wait(timeout=TERMINATION_WAIT_SECONDS), ""
    except subprocess.TimeoutExpired:
        return None, f"process did not exit within {TERMINATION_WAIT_SECONDS:.3f} seconds"


def _cleanup_owned_process(
    process: subprocess.Popen,
    containment: _ProcessContainment,
    reader: threading.Thread | None,
    reader_errors: list[str],
) -> tuple[int | None, str]:
    problems = []
    try:
        termination_error = containment.terminate()
        if termination_error:
            problems.append(termination_error)
    except BaseException as exc:
        problems.append(f"containment termination raised: {exc}")
    try:
        containment.close()
    except BaseException as exc:
        problems.append(f"containment close raised: {exc}")
    returncode, wait_error = _bounded_wait(process)
    if wait_error:
        problems.append(wait_error)
    if process.stdin is not None and not process.stdin.closed:
        try:
            process.stdin.close()
        except OSError as exc:
            problems.append(f"stdin close failed: {exc}")
    if reader is not None and reader.ident is not None:
        reader.join(READER_JOIN_SECONDS)
        if reader.is_alive() and process.stdout is not None:
            try:
                process.stdout.close()
            except OSError as exc:
                problems.append(f"stdout close failed: {exc}")
            reader.join(READER_JOIN_SECONDS)
        if reader.is_alive():
            problems.append(
                f"output reader did not stop within {2 * READER_JOIN_SECONDS:.3f} seconds"
            )
    if process.stdout is not None and not process.stdout.closed:
        try:
            process.stdout.close()
        except OSError as exc:
            problems.append(f"stdout close failed: {exc}")
    problems.extend(reader_errors)
    return returncode, "; ".join(problems)


def _parse_output(path: Path) -> tuple[int, tuple[str, ...]]:
    raw = path.read_bytes()
    matches = RAN_RE.findall(raw)
    if len(matches) != 1:
        raise RunnerError("unittest output has no unique completion summary")
    expected = int(matches[0])
    exposed = tuple(match.decode("utf-8", errors="replace") for match in RESULT_RE.findall(raw))
    test_ids = []
    for identity in exposed:
        match = TEST_ID_RE.fullmatch(identity)
        if match is None:
            raise RunnerError(f"unrecognized unittest identity: {identity}")
        test_ids.append(f"{match.group(1)}.{match.group(2)}")
    if len(test_ids) != expected:
        raise RunnerError(
            f"unittest output reported {expected} tests but exposed {len(test_ids)} results"
        )
    return expected, tuple(test_ids)


def run_module(
    test_path: Path,
    output_root: Path,
    timeout: float = MODULE_TIMEOUT_SECONDS,
    popen: Callable[..., subprocess.Popen] = subprocess.Popen,
    cancel_event: threading.Event | None = None,
) -> ModuleResult:
    started = time.perf_counter()
    output_path = output_root / f"{test_path.stem}.log"
    target = ["-B", "-m", "unittest", "-v", test_path.stem]
    command = [sys.executable, "-B", "-c", START_GATE_CODE, *target]
    launch_options = {"start_new_session": True} if os.name != "nt" else {
        "creationflags": subprocess.CREATE_NO_WINDOW
    }
    try:
        process = popen(
            command,
            cwd=test_path.parent,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            **launch_options,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return ModuleResult(test_path.name, "launch-error", None, time.perf_counter() - started, (), str(exc))

    if process.stdin is None or process.stdout is None:
        process.kill()
        _, wait_error = _bounded_wait(process)
        return ModuleResult(
            test_path.name,
            "internal-error",
            None,
            time.perf_counter() - started,
            (),
            wait_error or "startup gate pipes unavailable",
        )

    try:
        containment = _create_containment(process)
    except BaseException as exc:
        process.kill()
        _, wait_error = _bounded_wait(process)
        process.stdin.close()
        process.stdout.close()
        if not isinstance(exc, (OSError, AttributeError)):
            raise
        detail = f"process containment failed: {exc}"
        if wait_error:
            detail += f"; {wait_error}"
        return ModuleResult(
            test_path.name,
            "launch-error",
            process.poll(),
            time.perf_counter() - started,
            (),
            detail,
        )

    overflow = threading.Event()
    reader_errors: list[str] = []
    reader = threading.Thread(
        target=_bounded_reader,
        args=(process.stdout, output_path, overflow, reader_errors),
        name=f"campaign-output-{test_path.stem}",
        daemon=True,
    )
    status = "completed"
    detail = ""
    deadline = time.monotonic() + timeout
    try:
        reader.start()
        process.stdin.write(b"1")
        process.stdin.flush()
        process.stdin.close()
        while process.poll() is None:
            if overflow.is_set():
                status, detail = "output-limit", f"output exceeded {MAX_OUTPUT_BYTES} bytes"
                break
            if cancel_event is not None and cancel_event.is_set():
                status, detail = "interrupted", "runner requested module termination"
                break
            if time.monotonic() >= deadline:
                status, detail = "timeout", f"module exceeded {timeout:.3f} seconds"
                break
            time.sleep(POLL_SECONDS)
    except BaseException:
        _cleanup_owned_process(process, containment, reader, reader_errors)
        raise

    returncode, cleanup_error = _cleanup_owned_process(
        process, containment, reader, reader_errors
    )

    duration = time.perf_counter() - started
    if cleanup_error:
        status = "cleanup-error"
        detail = f"{detail}; {cleanup_error}" if detail else cleanup_error
    if status == "completed" and overflow.is_set():
        status, detail = "output-limit", f"output exceeded {MAX_OUTPUT_BYTES} bytes"
    if status != "completed":
        return ModuleResult(test_path.name, status, returncode, duration, (), detail, output_path)
    try:
        _, test_ids = _parse_output(output_path)
    except (OSError, RunnerError) as exc:
        return ModuleResult(test_path.name, "malformed-result", returncode, duration, (), str(exc), output_path)
    if returncode != 0:
        return ModuleResult(test_path.name, "failed", returncode, duration, test_ids, "unittest failed", output_path)
    return ModuleResult(test_path.name, "passed", returncode, duration, test_ids, output_path=output_path)


def run_suite(
    tests: Iterable[Path],
    output_root: Path,
    worker: Callable[[Path, Path], ModuleResult] = run_module,
    max_workers: int = MAX_WORKERS,
) -> list[ModuleResult]:
    ordered = list(tests)
    if not ordered:
        raise RunnerError("test execution received an empty discovery result")
    results: dict[Path, ModuleResult] = {}
    cancel_event = threading.Event()
    executor = ThreadPoolExecutor(max_workers=max_workers)
    futures = {}
    try:
        for path in ordered:
            future = executor.submit(
                worker,
                path,
                output_root,
                **({"cancel_event": cancel_event} if worker is run_module else {}),
            )
            futures[future] = path
        for future in as_completed(futures):
            path = futures[future]
            try:
                result = future.result()
                if not isinstance(result, ModuleResult) or result.module != path.name:
                    raise RunnerError(f"malformed worker result for {path.name}")
            except BaseException as exc:
                result = ModuleResult(path.name, "internal-error", None, 0.0, (), str(exc))
            results[path] = result
    except BaseException:
        cancel_event.set()
        for future in futures:
            future.cancel()
        wait(futures, timeout=EXECUTOR_SHUTDOWN_SECONDS)
        executor.shutdown(wait=False, cancel_futures=True)
        raise
    executor.shutdown(wait=True)
    return [results[path] for path in ordered]


def _tail(path: Path | None) -> str:
    if path is None or not path.is_file():
        return ""
    with path.open("rb") as stream:
        stream.seek(max(0, path.stat().st_size - TAIL_BYTES))
        return stream.read().decode("utf-8", errors="replace")


def result_set_digest(results: Iterable[ModuleResult]) -> str:
    identities = sorted(f"{result.module}:{test_id}" for result in results for test_id in result.test_ids)
    return hashlib.sha256("\n".join(identities).encode("utf-8")).hexdigest()


def main() -> int:
    try:
        tests = discover_tests()
        with tempfile.TemporaryDirectory(prefix="utmods-campaign-tests-") as directory:
            results = run_suite(tests, Path(directory))
            for result in results:
                print(
                    f"{result.module}: {result.status} tests={len(result.test_ids)} "
                    f"seconds={result.duration_seconds:.3f}"
                )
                if result.status != "passed":
                    if result.detail:
                        print(f"  {result.detail}")
                    tail = _tail(result.output_path)
                    if tail:
                        print(tail)
            passed = all(result.status == "passed" for result in results)
            total = sum(len(result.test_ids) for result in results)
            print(f"TOTAL tests={total} modules={len(results)} status={'pass' if passed else 'fail'}")
            print(f"RESULT_SET_SHA256 {result_set_digest(results)}")
            return 0 if passed else 1
    except BaseException as exc:
        print(f"campaign test runner internal error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
