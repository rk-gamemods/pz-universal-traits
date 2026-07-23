#!/usr/bin/env python3
"""Read-only verification and explicitly targeted transactional deployment for UTMods."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

PLATFORM = os.name

SCRIPT_DIR = Path(__file__).resolve().parent
MODS = ("UniversalTraits", "UT_CORE")
VERSION_DIR = "42.0"
EXIT_OK = 0
EXIT_USAGE = 2
EXIT_DRIFT = 3
EXIT_DEPLOY_FAILED = 4
EXIT_ROLLBACK_FAILED = 5
MAX_REPORTED_ISSUES = 100
FILE_ATTRIBUTE_REPARSE_POINT = 0x400
_CREATE_BOUNDARY_HOOK = None
_WRITE_BOUNDARY_HOOK = None


@dataclass(frozen=True)
class Entry:
    size: int
    sha256: str


@dataclass
class Prepared:
    name: str
    destination: Path
    stage: Path
    backup: Path
    expected: dict[str, Entry]
    had_destination: bool = False
    installed: bool = False


class DeployError(RuntimeError):
    def __init__(self, kind: str, message: str, **details: object) -> None:
        super().__init__(message)
        self.kind = kind
        self.details = details

    def payload(self) -> dict[str, object]:
        return {"kind": self.kind, "message": str(self), **self.details}


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))


class ContractParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        emit({"action": "usage", "error": {"kind": "usage", "message": message}, "exit_code": EXIT_USAGE})
        raise SystemExit(EXIT_USAGE)


def _is_reparse(st: os.stat_result) -> bool:
    return stat.S_ISLNK(st.st_mode) or bool(getattr(st, "st_file_attributes", 0) & FILE_ATTRIBUTE_REPARSE_POINT)


def _lstat(path: Path, *, missing_ok: bool = False) -> os.stat_result | None:
    try:
        value = path.lstat()
    except FileNotFoundError:
        if missing_ok:
            return None
        raise DeployError("path-missing", "required path disappeared", path=str(path))
    except OSError as error:
        raise DeployError("path-read", "unable to inspect path", path=str(path), os_error=str(error)) from error
    if _is_reparse(value):
        raise DeployError("reparse-point", "symlink or reparse point is forbidden", path=str(path))
    return value


def _stable_stat_snapshot(st: os.stat_result) -> tuple[int, int, int, int, int]:
    return (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns)


def _require_directory(path: Path, *, label: str) -> None:
    absolute = Path(os.path.abspath(path))
    chain = list(reversed(absolute.parents)) + [absolute]
    for component in chain:
        try:
            value = component.lstat()
        except FileNotFoundError:
            continue
        except OSError as error:
            raise DeployError("path-read", "unable to inspect path component", path=str(component), os_error=str(error)) from error
        if _is_reparse(value):
            raise DeployError("reparse-point", "symlink or reparse point is forbidden in path ancestry", path=str(component))
    value = _lstat(path)
    if value is None or not stat.S_ISDIR(value.st_mode):
        raise DeployError("not-directory", f"{label} must be a real directory", path=str(path))


def _contained(parent: Path, child: Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def _check_components(root: Path, path: Path, *, allow_missing_leaf: bool = False) -> None:
    root_abs = Path(os.path.abspath(root))
    path_abs = Path(os.path.abspath(path))
    if not _contained(root_abs, path_abs):
        raise DeployError("containment", "path escapes its authorized root", root=str(root_abs), path=str(path_abs))
    _require_directory(root_abs, label="authorized root")
    current = root_abs
    for part in path_abs.relative_to(root_abs).parts:
        current /= part
        # Once a component is absent, every descendant is necessarily absent too.
        # Existing ancestors have already been lstat-checked without following links;
        # callers must recheck the newly-created suffix immediately after mkdir.
        value = _lstat(current, missing_ok=allow_missing_leaf)
        if value is None:
            return


def _creation_boundary(parent: Path, child: Path) -> None:
    if _CREATE_BOUNDARY_HOOK is not None:
        _CREATE_BOUNDARY_HOOK(parent, child)


def _write_boundary(parent: Path, child: Path) -> None:
    if _WRITE_BOUNDARY_HOOK is not None:
        _WRITE_BOUNDARY_HOOK(parent, child)


def _open_directory_fd(path: Path) -> int:
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        return os.open(path, flags)
    except OSError as error:
        raise DeployError("path-read", "unable to open real directory", path=str(path), os_error=str(error)) from error


def _mkdir_relative_posix(parent_fd: int, name: str, parent: Path, child: Path) -> int:
    child_fd: int | None = None
    try:
        parent_before = os.fstat(parent_fd)
        _creation_boundary(parent, child)
        os.mkdir(name, dir_fd=parent_fd)
        child_fd = os.open(
            name,
            os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0),
            dir_fd=parent_fd,
        )
        parent_after = os.fstat(parent_fd)
        child_stat = os.fstat(child_fd)
        child_path_stat = _lstat(child)
        if child_path_stat is None or not stat.S_ISDIR(child_path_stat.st_mode):
            raise DeployError("path-race", "new stage component is not the created directory", path=str(child))
        if (parent_before.st_dev, parent_before.st_ino) != (parent_after.st_dev, parent_after.st_ino):
            raise DeployError("path-race", "stage parent changed during component creation", path=str(parent))
        if (child_stat.st_dev, child_stat.st_ino) != (child_path_stat.st_dev, child_path_stat.st_ino):
            raise DeployError("path-race", "new stage component was substituted", path=str(child))
        result = child_fd
        child_fd = None
        return result
    except FileExistsError as error:
        raise DeployError("artifact-collision", "unexpected stage component already exists", path=str(child)) from error
    except OSError as error:
        raise DeployError("stage-create", "unable to create stage component safely", path=str(child), os_error=str(error)) from error
    finally:
        if child_fd is not None:
            os.close(child_fd)


def _mkdir_relative_windows(parent_handle: int, name: str, parent: Path, child: Path) -> int:
    from ctypes import wintypes

    class UNICODE_STRING(ctypes.Structure):
        _fields_ = (("Length", wintypes.USHORT), ("MaximumLength", wintypes.USHORT), ("Buffer", wintypes.LPWSTR))

    class OBJECT_ATTRIBUTES(ctypes.Structure):
        _fields_ = (
            ("Length", wintypes.ULONG),
            ("RootDirectory", wintypes.HANDLE),
            ("ObjectName", ctypes.POINTER(UNICODE_STRING)),
            ("Attributes", wintypes.ULONG),
            ("SecurityDescriptor", wintypes.LPVOID),
            ("SecurityQualityOfService", wintypes.LPVOID),
        )

    class IO_STATUS_BLOCK(ctypes.Structure):
        _fields_ = (("Status", ctypes.c_ssize_t), ("Information", ctypes.c_size_t))

    ntdll = ctypes.WinDLL("ntdll", use_last_error=True)
    nt_create_file = ntdll.NtCreateFile
    nt_create_file.argtypes = (
        ctypes.POINTER(wintypes.HANDLE),
        wintypes.ULONG,
        ctypes.POINTER(OBJECT_ATTRIBUTES),
        ctypes.POINTER(IO_STATUS_BLOCK),
        ctypes.c_void_p,
        wintypes.ULONG,
        wintypes.ULONG,
        wintypes.ULONG,
        wintypes.ULONG,
        ctypes.c_void_p,
        wintypes.ULONG,
    )
    nt_create_file.restype = ctypes.c_long
    buffer = ctypes.create_unicode_buffer(name)
    unicode_name = UNICODE_STRING(len(name.encode("utf-16-le")), len(name.encode("utf-16-le")) + 2, ctypes.cast(buffer, wintypes.LPWSTR))
    attributes = OBJECT_ATTRIBUTES(ctypes.sizeof(OBJECT_ATTRIBUTES), parent_handle, ctypes.pointer(unicode_name), 0x40, None, None)
    io_status = IO_STATUS_BLOCK()
    child_handle = wintypes.HANDLE()
    _creation_boundary(parent, child)
    status = nt_create_file(
        ctypes.byref(child_handle),
        0x00100000 | 0x0080 | 0x0001,
        ctypes.byref(attributes),
        ctypes.byref(io_status),
        None,
        0,
        0x7,
        2,
        0x00000001 | 0x00200000 | 0x00000020,
        None,
        0,
    )
    if status < 0:
        kind = "artifact-collision" if status & 0xFFFFFFFF == 0xC0000035 else "stage-create"
        raise DeployError(kind, "unable to create stage component safely", path=str(child), ntstatus=f"0x{status & 0xFFFFFFFF:08x}")
    result = int(child_handle.value)
    try:
        _verify_windows_path_handle(child, result, directory=True)
        return result
    except BaseException:
        _close_directory_handle(result)
        raise


def _windows_handle_identity(handle: int, *, path: Path, directory: bool) -> tuple[int, int]:
    from ctypes import wintypes

    class BY_HANDLE_FILE_INFORMATION(ctypes.Structure):
        _fields_ = (
            ("FileAttributes", wintypes.DWORD),
            ("CreationTimeLow", wintypes.DWORD),
            ("CreationTimeHigh", wintypes.DWORD),
            ("LastAccessTimeLow", wintypes.DWORD),
            ("LastAccessTimeHigh", wintypes.DWORD),
            ("LastWriteTimeLow", wintypes.DWORD),
            ("LastWriteTimeHigh", wintypes.DWORD),
            ("VolumeSerialNumber", wintypes.DWORD),
            ("FileSizeHigh", wintypes.DWORD),
            ("FileSizeLow", wintypes.DWORD),
            ("NumberOfLinks", wintypes.DWORD),
            ("FileIndexHigh", wintypes.DWORD),
            ("FileIndexLow", wintypes.DWORD),
        )

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    information = BY_HANDLE_FILE_INFORMATION()
    get_information = kernel32.GetFileInformationByHandle
    get_information.argtypes = (wintypes.HANDLE, ctypes.POINTER(BY_HANDLE_FILE_INFORMATION))
    get_information.restype = wintypes.BOOL
    if not get_information(handle, ctypes.byref(information)):
        raise DeployError("path-read", "unable to inspect opened stage object", path=str(path), win_error=ctypes.get_last_error())
    if information.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT:
        raise DeployError("reparse-point", "opened stage object is a reparse point", path=str(path))
    is_directory = bool(information.FileAttributes & 0x10)
    if is_directory != directory:
        raise DeployError("not-directory" if directory else "not-file", "opened stage object has the wrong type", path=str(path))
    return (
        int(information.VolumeSerialNumber),
        (int(information.FileIndexHigh) << 32) | int(information.FileIndexLow),
    )


def _open_windows_path(path: Path, *, directory: bool) -> int:
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel32.CreateFileW
    create_file.argtypes = (
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.LPVOID,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.HANDLE,
    )
    create_file.restype = wintypes.HANDLE
    close_handle = kernel32.CloseHandle
    close_handle.argtypes = (wintypes.HANDLE,)
    close_handle.restype = wintypes.BOOL
    handle = create_file(
        str(path),
        0x00100000 | 0x0080 | (0x0001 if directory else 0),
        0x7,
        None,
        3,
        (0x02000000 if directory else 0) | 0x00200000,
        None,
    )
    invalid = ctypes.c_void_p(-1).value
    if handle == invalid:
        raise DeployError("path-read", "unable to open real directory", path=str(path), win_error=ctypes.get_last_error())
    result = int(handle)
    try:
        _windows_handle_identity(result, path=path, directory=directory)
        return result
    except BaseException:
        close_handle(handle)
        raise


def _open_windows_directory(path: Path) -> int:
    return _open_windows_path(path, directory=True)


def _verify_windows_path_handle(path: Path, handle: int, *, directory: bool) -> None:
    expected = _windows_handle_identity(handle, path=path, directory=directory)
    probe = _open_windows_path(path, directory=directory)
    try:
        actual = _windows_handle_identity(probe, path=path, directory=directory)
    finally:
        _close_directory_handle(probe)
    if actual != expected:
        raise DeployError("path-race", "stage object pathname no longer names the opened object", path=str(path))


def _close_directory_handle(handle: int) -> None:
    if PLATFORM == "nt":
        from ctypes import wintypes

        close_handle = ctypes.WinDLL("kernel32", use_last_error=True).CloseHandle
        close_handle.argtypes = (wintypes.HANDLE,)
        close_handle.restype = wintypes.BOOL
        close_handle(handle)
    else:
        os.close(handle)


def _write_all_posix(fd: int, data: bytes, path: Path) -> None:
    offset = 0
    while offset < len(data):
        try:
            written = os.write(fd, data[offset:])
        except OSError as error:
            raise DeployError("copy-failed", "unable to write staged file", destination=str(path), os_error=str(error)) from error
        if written <= 0:
            raise DeployError("copy-failed", "staged file write made no progress", destination=str(path))
        offset += written


def _write_all_windows(handle: int, data: bytes, path: Path) -> None:
    from ctypes import wintypes

    write_file = ctypes.WinDLL("kernel32", use_last_error=True).WriteFile
    write_file.argtypes = (wintypes.HANDLE, wintypes.LPCVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID)
    write_file.restype = wintypes.BOOL
    offset = 0
    while offset < len(data):
        chunk = data[offset : offset + 1024 * 1024]
        buffer = ctypes.create_string_buffer(chunk)
        written = wintypes.DWORD()
        if not write_file(handle, buffer, len(chunk), ctypes.byref(written), None):
            raise DeployError("copy-failed", "unable to write staged file", destination=str(path), win_error=ctypes.get_last_error())
        if written.value <= 0:
            raise DeployError("copy-failed", "staged file write made no progress", destination=str(path))
        offset += written.value


def _create_file_relative_windows(parent_handle: int, name: str, destination: Path) -> int:
    from ctypes import wintypes

    class UNICODE_STRING(ctypes.Structure):
        _fields_ = (("Length", wintypes.USHORT), ("MaximumLength", wintypes.USHORT), ("Buffer", wintypes.LPWSTR))

    class OBJECT_ATTRIBUTES(ctypes.Structure):
        _fields_ = (
            ("Length", wintypes.ULONG),
            ("RootDirectory", wintypes.HANDLE),
            ("ObjectName", ctypes.POINTER(UNICODE_STRING)),
            ("Attributes", wintypes.ULONG),
            ("SecurityDescriptor", wintypes.LPVOID),
            ("SecurityQualityOfService", wintypes.LPVOID),
        )

    class IO_STATUS_BLOCK(ctypes.Structure):
        _fields_ = (("Status", ctypes.c_ssize_t), ("Information", ctypes.c_size_t))

    ntdll = ctypes.WinDLL("ntdll", use_last_error=True)
    nt_create_file = ntdll.NtCreateFile
    nt_create_file.argtypes = (
        ctypes.POINTER(wintypes.HANDLE), wintypes.ULONG, ctypes.POINTER(OBJECT_ATTRIBUTES),
        ctypes.POINTER(IO_STATUS_BLOCK), ctypes.c_void_p, wintypes.ULONG, wintypes.ULONG,
        wintypes.ULONG, wintypes.ULONG, ctypes.c_void_p, wintypes.ULONG,
    )
    nt_create_file.restype = ctypes.c_long
    buffer = ctypes.create_unicode_buffer(name)
    encoded_length = len(name.encode("utf-16-le"))
    unicode_name = UNICODE_STRING(encoded_length, encoded_length + 2, ctypes.cast(buffer, wintypes.LPWSTR))
    attributes = OBJECT_ATTRIBUTES(ctypes.sizeof(OBJECT_ATTRIBUTES), parent_handle, ctypes.pointer(unicode_name), 0x40, None, None)
    io_status = IO_STATUS_BLOCK()
    file_handle = wintypes.HANDLE()
    status = nt_create_file(
        ctypes.byref(file_handle), 0x00100000 | 0x0080 | 0x0002,
        ctypes.byref(attributes), ctypes.byref(io_status), None, 0, 0x7, 2,
        0x00000040 | 0x00200000 | 0x00000020, None, 0,
    )
    if status < 0:
        kind = "artifact-collision" if status & 0xFFFFFFFF == 0xC0000035 else "copy-failed"
        raise DeployError(kind, "unable to create staged file safely", destination=str(destination), ntstatus=f"0x{status & 0xFFFFFFFF:08x}")
    result = int(file_handle.value)
    try:
        _verify_windows_path_handle(destination, result, directory=False)
        return result
    except BaseException:
        _close_directory_handle(result)
        raise


class _StageWriter:
    def __init__(self, stage: Path) -> None:
        self.stage = Path(os.path.abspath(stage))
        self.handles: dict[Path, int] = {}
        _require_directory(self.stage.parent, label="stage parent")
        parent_handle = _open_windows_directory(self.stage.parent) if PLATFORM == "nt" else _open_directory_fd(self.stage.parent)
        stage_handle: int | None = None
        try:
            try:
                if _lstat(self.stage, missing_ok=True) is not None:
                    raise DeployError("artifact-collision", "stage path already exists", path=str(self.stage))
                stage_handle = (
                    _mkdir_relative_windows(parent_handle, self.stage.name, self.stage.parent, self.stage)
                    if PLATFORM == "nt"
                    else _mkdir_relative_posix(parent_handle, self.stage.name, self.stage.parent, self.stage)
                )
            finally:
                _close_directory_handle(parent_handle)
            self.handles[Path()] = stage_handle
            stage_handle = None
        except BaseException:
            if stage_handle is not None:
                try:
                    _close_directory_handle(stage_handle)
                except BaseException:
                    pass
            raise

    def close(self) -> None:
        handles = reversed(tuple(self.handles.values()))
        self.handles.clear()
        first_error: BaseException | None = None
        for handle in handles:
            try:
                _close_directory_handle(handle)
            except BaseException as error:
                if first_error is None:
                    first_error = error
        if first_error is not None:
            raise first_error

    def ensure(self, relative: Path) -> None:
        if relative.is_absolute() or not _contained(self.stage, self.stage / relative):
            raise DeployError("containment", "stage component escapes its owned root", root=str(self.stage), path=str(self.stage / relative))
        current = Path()
        for part in relative.parts:
            parent = current
            current /= part
            if current in self.handles:
                continue
            parent_path = self.stage / parent
            child_path = self.stage / current
            if _lstat(child_path, missing_ok=True) is not None:
                raise DeployError("artifact-collision", "unexpected stage component already exists", path=str(child_path))
            handle = (
                _mkdir_relative_windows(self.handles[parent], part, parent_path, child_path)
                if PLATFORM == "nt"
                else _mkdir_relative_posix(self.handles[parent], part, parent_path, child_path)
            )
            self.handles[current] = handle

    def copy(self, source: Path, relative: Path) -> None:
        parent = relative.parent
        self.ensure(parent)
        destination = self.stage / relative
        before = _lstat(source)
        if before is None or not stat.S_ISREG(before.st_mode):
            raise DeployError("not-file", "copy source must be a regular file", path=str(source))
        try:
            data = source.read_bytes()
        except OSError as error:
            raise DeployError("file-read", "unable to read copy source", path=str(source), os_error=str(error)) from error
        after = _lstat(source)
        if _stable_stat_snapshot(before) != _stable_stat_snapshot(after):
            raise DeployError("file-race", "source changed while it was copied", path=str(source))
        file_handle: int | None = None
        try:
            _write_boundary(destination.parent, destination)
            if PLATFORM == "nt":
                file_handle = _create_file_relative_windows(self.handles[parent], relative.name, destination)
                _write_all_windows(file_handle, data, destination)
                _verify_windows_path_handle(destination, file_handle, directory=False)
            else:
                try:
                    file_handle = os.open(
                        relative.name,
                        os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
                        0o666,
                        dir_fd=self.handles[parent],
                    )
                except OSError as error:
                    raise DeployError("copy-failed", "unable to create staged file safely", destination=str(destination), os_error=str(error)) from error
                _write_all_posix(file_handle, data, destination)
                handle_stat = os.fstat(file_handle)
                path_stat = _lstat(destination)
                if path_stat is None or (handle_stat.st_dev, handle_stat.st_ino) != (path_stat.st_dev, path_stat.st_ino):
                    raise DeployError("path-race", "staged file was substituted", path=str(destination))
        finally:
            if file_handle is not None:
                _close_directory_handle(file_handle)


def _walk_files(root: Path) -> list[Path]:
    _require_directory(root, label="manifest root")
    files: list[Path] = []

    def visit(directory: Path) -> None:
        try:
            entries = sorted(os.scandir(directory), key=lambda item: item.name)
        except OSError as error:
            raise DeployError("directory-read", "unable to enumerate directory", path=str(directory), os_error=str(error)) from error
        for item in entries:
            path = Path(item.path)
            try:
                value = item.stat(follow_symlinks=False)
            except OSError as error:
                raise DeployError("path-read", "unable to inspect directory entry", path=str(path), os_error=str(error)) from error
            if _is_reparse(value):
                raise DeployError("reparse-point", "symlink or reparse point is forbidden", path=str(path))
            if stat.S_ISDIR(value.st_mode):
                visit(path)
            elif stat.S_ISREG(value.st_mode):
                files.append(path)
            else:
                raise DeployError("special-file", "only regular files and directories are allowed", path=str(path))

    visit(root)
    return files


def sha256(path: Path) -> str:
    before = _lstat(path)
    if before is None or not stat.S_ISREG(before.st_mode):
        raise DeployError("not-file", "manifest entry must be a regular file", path=str(path))
    digest = hashlib.sha256()
    try:
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        raise DeployError("file-read", "unable to read file", path=str(path), os_error=str(error)) from error
    after = _lstat(path)
    if _stable_stat_snapshot(before) != _stable_stat_snapshot(after):
        raise DeployError("file-race", "file changed while it was being hashed", path=str(path))
    return digest.hexdigest()


def entry(path: Path) -> Entry:
    before = _lstat(path)
    if before is None or not stat.S_ISREG(before.st_mode):
        raise DeployError("not-file", "manifest entry must be a regular file", path=str(path))
    digest = sha256(path)
    after = _lstat(path)
    if _stable_stat_snapshot(before) != _stable_stat_snapshot(after):
        raise DeployError("file-race", "file changed while its manifest entry was built", path=str(path))
    return Entry(after.st_size, digest)


def source_manifest(mod_root: Path) -> tuple[dict[str, Entry], list[str]]:
    issues: list[str] = []
    _require_directory(mod_root, label="mod source")
    media = mod_root / "media"
    mod_info = mod_root / "mod.info"
    poster = mod_root / "poster.png"
    for path, label, directory in ((media, "media", True), (mod_info, "mod.info", False), (poster, "poster.png", False)):
        value = _lstat(path, missing_ok=True)
        if value is None or (directory and not stat.S_ISDIR(value.st_mode)) or (not directory and not stat.S_ISREG(value.st_mode)):
            issues.append(f"missing-source:{label}")
    if _lstat(mod_info, missing_ok=True) is not None:
        try:
            text = mod_info.read_text(encoding="utf-8", errors="strict")
        except UnicodeError as error:
            raise DeployError("invalid-utf8", "mod.info is not valid UTF-8", path=str(mod_info), error=str(error)) from error
        except OSError as error:
            raise DeployError("file-read", "unable to read mod.info", path=str(mod_info), os_error=str(error)) from error
        match = re.search(r"(?m)^\s*versionMin\s*=\s*(\S+)\s*$", text)
        if not match:
            issues.append("metadata:mod.info missing versionMin")
        elif match.group(1) != VERSION_DIR:
            issues.append(f"layout:versionMin must be {VERSION_DIR}, got {match.group(1)}")
    manifest: dict[str, Entry] = {}
    if _lstat(media, missing_ok=True) is not None:
        for path in _walk_files(media):
            manifest[f"{VERSION_DIR}/media/{path.relative_to(media).as_posix()}"] = entry(path)
    for metadata in (mod_info, poster):
        value = _lstat(metadata, missing_ok=True)
        if value is not None and stat.S_ISREG(value.st_mode):
            item = entry(metadata)
            manifest[metadata.name] = item
            manifest[f"{VERSION_DIR}/{metadata.name}"] = item
    return manifest, issues


def directory_manifest(root: Path) -> dict[str, Entry]:
    value = _lstat(root, missing_ok=True)
    if value is None:
        return {}
    if not stat.S_ISDIR(value.st_mode):
        raise DeployError("not-directory", "manifest destination must be a real directory", path=str(root))
    return {path.relative_to(root).as_posix(): entry(path) for path in _walk_files(root)}


def compare(expected: dict[str, Entry], actual: dict[str, Entry]) -> list[dict[str, str]]:
    problems: list[dict[str, str]] = []
    for relative in sorted(expected.keys() - actual.keys()):
        problems.append({"kind": "missing", "path": relative})
    for relative in sorted(actual.keys() - expected.keys()):
        problems.append({"kind": "extra", "path": relative})
    for relative in sorted(expected.keys() & actual.keys()):
        if expected[relative] != actual[relative]:
            problems.append({"kind": "mismatch", "path": relative})
    return problems


def canonical_destination(target_root: Path, mod_name: str) -> Path:
    if not target_root.is_absolute():
        raise ValueError("target root must be an absolute path")
    root = Path(os.path.abspath(target_root))
    _require_directory(root, label="target root")
    destination = root / mod_name
    if destination.parent != root or destination.name != mod_name:
        raise ValueError("destination escapes the exact target root")
    source = Path(os.path.abspath(SCRIPT_DIR))
    if root == source or _contained(source, root):
        raise ValueError("target root must not be the UTMods source tree")
    value = _lstat(destination, missing_ok=True)
    if value is not None and not stat.S_ISDIR(value.st_mode):
        raise DeployError("not-directory", "existing destination must be a real non-reparse directory", path=str(destination))
    return destination


def copy_source_package(mod_root: Path, stage: Path) -> None:
    _require_directory(mod_root, label="mod source")
    _check_components(stage.parent, stage, allow_missing_leaf=True)
    writer = _StageWriter(stage)
    try:
        media = mod_root / "media"
        for source in _walk_files(media):
            relative = source.relative_to(media)
            writer.copy(source, Path(VERSION_DIR) / "media" / relative)
        for name in ("mod.info", "poster.png"):
            writer.copy(mod_root / name, Path(name))
            writer.copy(mod_root / name, Path(VERSION_DIR) / name)
    finally:
        writer.close()
    directory_manifest(stage)


def _artifact_paths(destination: Path) -> tuple[Path, Path]:
    attempt = uuid.uuid4().hex
    return (
        destination.parent / f".{destination.name}.stage-{attempt}",
        destination.parent / f".{destination.name}.backup-{attempt}",
    )


def prepare_deployment(mod_root: Path, destination: Path, expected: dict[str, Entry]) -> Prepared:
    parent = destination.parent
    _require_directory(parent, label="target root")
    _check_components(parent, destination, allow_missing_leaf=True)
    current = _lstat(destination, missing_ok=True)
    if current is not None and not stat.S_ISDIR(current.st_mode):
        raise DeployError("not-directory", "existing destination must be a real non-reparse directory", path=str(destination))
    stage, backup = _artifact_paths(destination)
    for artifact in (stage, backup):
        _check_components(parent, artifact, allow_missing_leaf=True)
        if _lstat(artifact, missing_ok=True) is not None:
            raise DeployError("artifact-collision", "stage or backup path already exists", path=str(artifact))
    try:
        copy_source_package(mod_root, stage)
        staged_issues = compare(expected, directory_manifest(stage))
        if staged_issues:
            raise DeployError("stage-validation", "staging validation failed", issues=staged_issues[:MAX_REPORTED_ISSUES])
    except DeployError as error:
        error.details.setdefault("retained_stage", str(stage))
        raise
    return Prepared(mod_root.name, destination, stage, backup, expected)


def _replace(source: Path, destination: Path, root: Path) -> None:
    _check_components(root, source)
    _check_components(root, destination, allow_missing_leaf=True)
    try:
        os.replace(source, destination)
    except OSError as error:
        raise DeployError("replace-failed", "atomic rename failed", source=str(source), destination=str(destination), os_error=str(error)) from error


def _rollback(prepared: list[Prepared]) -> list[dict[str, object]]:
    failures: list[dict[str, object]] = []
    for item in reversed(prepared):
        try:
            if item.installed and _lstat(item.destination, missing_ok=True) is not None:
                _replace(item.destination, item.stage, item.destination.parent)
            if item.had_destination and _lstat(item.backup, missing_ok=True) is not None:
                _replace(item.backup, item.destination, item.destination.parent)
        except DeployError as error:
            failures.append({"mod": item.name, "error": error.payload(), "retained_stage": str(item.stage), "retained_backup": str(item.backup)})
    return failures


def deploy_campaign(prepared: list[Prepared]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    completed: list[Prepared] = []
    try:
        for item in prepared:
            root = item.destination.parent
            _require_directory(root, label="target root")
            _check_components(root, item.stage)
            _check_components(root, item.backup, allow_missing_leaf=True)
            if _lstat(item.backup, missing_ok=True) is not None:
                raise DeployError("artifact-collision", "backup path appeared before swap", path=str(item.backup))
            current = _lstat(item.destination, missing_ok=True)
            if current is not None:
                if not stat.S_ISDIR(current.st_mode):
                    raise DeployError("not-directory", "existing destination must remain a real directory", path=str(item.destination))
                _replace(item.destination, item.backup, root)
                item.had_destination = True
            completed.append(item)
            _replace(item.stage, item.destination, root)
            item.installed = True
            issues = compare(item.expected, directory_manifest(item.destination))
            if issues:
                raise DeployError("post-swap-validation", "post-swap validation failed", issues=issues[:MAX_REPORTED_ISSUES])
    except DeployError as error:
        failures = _rollback(completed)
        if failures:
            raise DeployError("rollback-failed", "campaign deployment failed and rollback was incomplete", cause=error.payload(), rollback_failures=failures) from error
        raise DeployError("deployment-failed", "campaign deployment failed and all changed mods were rolled back", cause=error.payload()) from error

    warnings: list[dict[str, object]] = []
    results: list[dict[str, object]] = []
    for item in prepared:
        retained_backup: str | None = None
        if item.had_destination and _lstat(item.backup, missing_ok=True) is not None:
            try:
                _check_components(item.destination.parent, item.backup)
                directory_manifest(item.backup)
                _check_components(item.destination.parent, item.backup)
                shutil.rmtree(item.backup)
            except (OSError, DeployError) as error:
                retained_backup = str(item.backup)
                warnings.append({"kind": "backup-cleanup", "mod": item.name, "retained_backup": retained_backup, "message": str(error)})
        results.append({"mod": item.name, "deployment": "succeeded", "retained_backup": retained_backup, "visibility_gap": True})
    return results, warnings


def atomic_deploy(mod_root: Path, destination: Path, expected: dict[str, Entry]) -> Path | None:
    item = prepare_deployment(mod_root, destination, expected)
    _, warnings = deploy_campaign([item])
    return Path(warnings[0]["retained_backup"]) if warnings else None


def parser() -> argparse.ArgumentParser:
    result = ContractParser(description=__doc__)
    action = result.add_mutually_exclusive_group()
    action.add_argument("--verify-only", action="store_true", help="read-only (the default)")
    action.add_argument("--deploy", action="store_true", help="explicitly enable transactional mutation")
    result.add_argument("--target-root", type=Path, help="exact absolute root containing mod folders")
    result.add_argument("mods", nargs="*", choices=MODS)
    return result


def bounded(issues: Iterable[dict[str, str]]) -> tuple[list[dict[str, str]], int]:
    values = list(issues)
    return values[:MAX_REPORTED_ISSUES], max(0, len(values) - MAX_REPORTED_ISSUES)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    selected = args.mods or list(MODS)
    if args.deploy and args.target_root is None:
        parser().error("--deploy requires --target-root")
    if args.target_root is not None and not args.target_root.is_absolute():
        parser().error("--target-root must be an absolute path")
    results: list[dict[str, object]] = []
    warnings: list[dict[str, object]] = []
    exit_code = EXIT_OK
    prepared: list[Prepared] = []
    try:
        target_root = Path(os.path.abspath(args.target_root)) if args.target_root is not None else None
        if args.deploy:
            _require_directory(target_root, label="deploy target root")
        for name in selected:
            mod_root = SCRIPT_DIR / name
            expected, source_issues = source_manifest(mod_root)
            destinations: list[tuple[str, Path]] = [("release", mod_root / "release" / name)]
            if target_root is not None:
                destinations.append(("target", canonical_destination(target_root, name)))
            checks: list[dict[str, object]] = []
            for label, destination in destinations:
                issues, omitted = bounded(compare(expected, directory_manifest(destination)))
                checks.append({"destination": label, "issues": issues, "omitted": omitted})
            result: dict[str, object] = {"mod": name, "source_issues": source_issues, "checks": checks}
            results.append(result)
            if source_issues or any(check["issues"] or check["omitted"] for check in checks):
                exit_code = max(exit_code, EXIT_DRIFT)
            if args.deploy:
                if source_issues:
                    raise DeployError("source-invalid", "deployment source has validation issues", mod=name, issues=source_issues)
                prepared.append(prepare_deployment(mod_root, canonical_destination(target_root, name), expected))
        if args.deploy:
            deployment_results, warnings = deploy_campaign(prepared)
            by_name = {item["mod"]: item for item in deployment_results}
            for result in results:
                result.update(by_name[str(result["mod"])])
            exit_code = EXIT_OK
    except DeployError as error:
        if prepared:
            error.details.setdefault("staging_artifacts", [str(item.stage) for item in prepared])
        exit_code = EXIT_ROLLBACK_FAILED if error.kind == "rollback-failed" else (EXIT_DEPLOY_FAILED if args.deploy else EXIT_DRIFT)
        if args.deploy:
            for result in results:
                result.setdefault("deployment", "failed")
        emit({"action": "deploy" if args.deploy else "verify", "error": error.payload(), "exit_code": exit_code, "results": results, "warnings": warnings})
        return exit_code
    except ValueError as error:
        emit({"action": "usage", "error": {"kind": "usage", "message": str(error)}, "exit_code": EXIT_USAGE})
        return EXIT_USAGE
    except (OSError, UnicodeError) as error:
        exit_code = EXIT_DEPLOY_FAILED if args.deploy else EXIT_DRIFT
        emit({"action": "deploy" if args.deploy else "verify", "error": {"kind": "internal-io", "message": str(error)}, "exit_code": exit_code, "results": results, "warnings": warnings})
        return exit_code
    emit({"action": "deploy" if args.deploy else "verify", "exit_code": exit_code, "results": results, "warnings": warnings})
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
