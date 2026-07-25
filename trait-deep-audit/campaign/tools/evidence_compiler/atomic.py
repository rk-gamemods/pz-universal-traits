"""Small atomic multi-file writer used by generated evidence views."""

from __future__ import annotations

import os
import tempfile
from collections.abc import Callable, Mapping
from pathlib import Path


class AtomicWriteError(RuntimeError):
    """A planned write failed and rollback may need operator attention."""


def _durable_temp(target: Path, data: bytes) -> Path:
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(
        prefix=f".{target.name}.", suffix=".tmp", dir=target.parent
    )
    path = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return path


def commit_files(
    rendered: Mapping[Path, bytes],
    *,
    replace: Callable[[str | os.PathLike[str], str | os.PathLike[str]], None] = os.replace,
) -> list[Path]:
    """Commit changed files as one best-effort transaction with exact rollback."""
    changed = {
        path: data
        for path, data in rendered.items()
        if not path.exists() or path.read_bytes() != data
    }
    if not changed:
        return []

    original = {
        path: path.read_bytes() if path.exists() else None for path in changed
    }
    staged: dict[Path, Path] = {}
    committed: list[Path] = []
    try:
        for target in sorted(changed, key=lambda item: item.as_posix()):
            staged[target] = _durable_temp(target, changed[target])
        for target in sorted(staged, key=lambda item: item.as_posix()):
            replace(staged[target], target)
            committed.append(target)
    except BaseException as error:
        rollback_errors: list[str] = []
        for target in reversed(committed):
            try:
                before = original[target]
                if before is None:
                    target.unlink(missing_ok=True)
                else:
                    restore = _durable_temp(target, before)
                    try:
                        os.replace(restore, target)
                    finally:
                        restore.unlink(missing_ok=True)
            except BaseException as rollback_error:
                rollback_errors.append(f"{target}: {rollback_error}")
        detail = f"atomic evidence write failed: {error}"
        if rollback_errors:
            detail += "; rollback errors: " + " | ".join(rollback_errors)
        raise AtomicWriteError(detail) from error
    finally:
        for path in staged.values():
            path.unlink(missing_ok=True)
    return committed
