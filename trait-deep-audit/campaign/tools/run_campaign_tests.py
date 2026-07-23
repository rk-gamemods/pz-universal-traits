#!/usr/bin/env python3
"""Run campaign test modules concurrently with process isolation and bounded output."""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
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


def discover_tests(test_root: Path = TEST_ROOT) -> list[Path]:
    tests = sorted(path for path in test_root.glob("test_*.py") if path.is_file())
    if not tests:
        raise RunnerError(f"no campaign tests discovered under {test_root}")
    return tests


def _bounded_reader(stream, output_path: Path, overflow: threading.Event) -> None:
    written = 0
    with output_path.open("wb") as output:
        while True:
            chunk = stream.read(64 * 1024)
            if not chunk:
                return
            remaining = MAX_OUTPUT_BYTES - written
            if remaining > 0:
                output.write(chunk[:remaining])
                written += min(len(chunk), remaining)
            if len(chunk) > remaining:
                overflow.set()


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
) -> ModuleResult:
    started = time.perf_counter()
    output_path = output_root / f"{test_path.stem}.log"
    command = [sys.executable, "-B", "-m", "unittest", "-v", test_path.stem]
    try:
        process = popen(
            command,
            cwd=test_path.parent,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return ModuleResult(test_path.name, "launch-error", None, time.perf_counter() - started, (), str(exc))

    if process.stdout is None:
        process.kill()
        process.wait()
        return ModuleResult(test_path.name, "internal-error", None, time.perf_counter() - started, (), "stdout pipe unavailable")

    overflow = threading.Event()
    reader = threading.Thread(
        target=_bounded_reader,
        args=(process.stdout, output_path, overflow),
        name=f"campaign-output-{test_path.stem}",
    )
    reader.start()
    status = "completed"
    detail = ""
    deadline = time.monotonic() + timeout
    try:
        while process.poll() is None:
            if overflow.is_set():
                status, detail = "output-limit", f"output exceeded {MAX_OUTPUT_BYTES} bytes"
                process.kill()
                break
            if time.monotonic() >= deadline:
                status, detail = "timeout", f"module exceeded {timeout:.3f} seconds"
                process.kill()
                break
            time.sleep(POLL_SECONDS)
        returncode = process.wait()
    except BaseException:
        process.kill()
        process.wait()
        raise
    finally:
        process.stdout.close()
        reader.join()

    duration = time.perf_counter() - started
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
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(worker, path, output_root): path for path in ordered}
        for future in as_completed(futures):
            path = futures[future]
            try:
                result = future.result()
                if not isinstance(result, ModuleResult) or result.module != path.name:
                    raise RunnerError(f"malformed worker result for {path.name}")
            except BaseException as exc:
                result = ModuleResult(path.name, "internal-error", None, 0.0, (), str(exc))
            results[path] = result
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
