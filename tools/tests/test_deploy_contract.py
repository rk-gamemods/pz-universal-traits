from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import deploy


class DeployContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        for name in deploy.MODS:
            mod = self.source / name
            (mod / "media" / "lua").mkdir(parents=True)
            (mod / "media" / "lua" / "example.lua").write_text(f"return '{name}'\n", encoding="utf-8")
            (mod / "mod.info").write_text("versionMin=42.0\n", encoding="utf-8")
            (mod / "poster.png").write_bytes(b"png")
            release = mod / "release" / name
            release.parent.mkdir()
            expected, _ = deploy.source_manifest(mod)
            deploy.copy_source_package(mod, release)
            self.assertEqual([], deploy.compare(expected, deploy.directory_manifest(release)))

    def run_main(self, *args: str) -> tuple[int, dict[str, object]]:
        output = io.StringIO()
        with mock.patch.object(deploy, "SCRIPT_DIR", self.source), contextlib.redirect_stdout(output):
            code = deploy.main(list(args))
        lines = output.getvalue().splitlines()
        self.assertEqual(1, len(lines), output.getvalue())
        return code, json.loads(lines[0])

    def make_target(self, *, old: bool = False) -> Path:
        target = self.root / "target"
        target.mkdir()
        if old:
            for name in deploy.MODS:
                destination = target / name
                destination.mkdir()
                (destination / "old").write_text(name, encoding="utf-8")
        return target

    def directory_symlink(self, target: Path, link: Path) -> None:
        try:
            os.symlink(target, link, target_is_directory=True)
        except (NotImplementedError, OSError) as error:
            self.skipTest(f"directory symlinks unavailable on this platform: {error}")

    def test_unknown_flag_and_usage_are_structured_and_deterministic(self) -> None:
        for args in (("--unknown",), ("--deploy",), ("--deploy", "--target-root", "relative")):
            output = io.StringIO()
            with contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as caught:
                deploy.main(list(args))
            self.assertEqual(deploy.EXIT_USAGE, caught.exception.code)
            payload = json.loads(output.getvalue())
            self.assertEqual("usage", payload["error"]["kind"])

    def test_default_and_verify_only_make_no_writes(self) -> None:
        target = self.make_target()
        before = deploy.directory_manifest(self.root)
        for args in ((), ("--verify-only",), ("--verify-only", "--target-root", str(target))):
            self.run_main(*args)
            self.assertEqual(before, deploy.directory_manifest(self.root))

    def test_deploy_requires_explicit_absolute_external_target(self) -> None:
        with mock.patch.object(deploy, "SCRIPT_DIR", self.source):
            with self.assertRaises(ValueError):
                deploy.canonical_destination(self.source, deploy.MODS[0])

    def test_existing_destination_file_is_rejected_without_mutation(self) -> None:
        target = self.make_target()
        destination = target / deploy.MODS[0]
        destination.write_text("do not replace", encoding="utf-8")
        code, report = self.run_main("--deploy", "--target-root", str(target), deploy.MODS[0])
        self.assertEqual(deploy.EXIT_DEPLOY_FAILED, code)
        self.assertEqual("not-directory", report["error"]["kind"])
        self.assertEqual("do not replace", destination.read_text(encoding="utf-8"))

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks unsupported")
    def test_source_symlink_is_rejected(self) -> None:
        outside = self.root / "outside.lua"
        outside.write_text("secret", encoding="utf-8")
        link = self.source / deploy.MODS[0] / "media" / "lua" / "linked.lua"
        try:
            link.symlink_to(outside)
        except OSError as error:
            self.skipTest(str(error))
        with self.assertRaisesRegex(deploy.DeployError, "reparse point"):
            deploy.source_manifest(self.source / deploy.MODS[0])

    def test_windows_reparse_attribute_is_rejected(self) -> None:
        fake = mock.Mock(st_mode=stat_mode_file(), st_file_attributes=deploy.FILE_ATTRIBUTE_REPARSE_POINT)
        self.assertTrue(deploy._is_reparse(fake))

    def test_ordinary_nested_staging_creates_missing_intermediates(self) -> None:
        name = deploy.MODS[0]
        stage = self.root / "stage"
        deploy.copy_source_package(self.source / name, stage)
        self.assertTrue((stage / "42.0" / "media" / "lua" / "example.lua").is_file())
        expected, _ = deploy.source_manifest(self.source / name)
        self.assertEqual([], deploy.compare(expected, deploy.directory_manifest(stage)))

    def test_posix_child_descriptor_closes_for_every_post_open_failure(self) -> None:
        parent_stat = mock.Mock(st_dev=1, st_ino=2)
        child_stat = mock.Mock(st_dev=1, st_ino=3)
        cases = (
            ("parent-fstat", (parent_stat, OSError("parent inspection failed")), None),
            ("child-fstat", (parent_stat, parent_stat, OSError("child inspection failed")), None),
            ("child-lstat", (parent_stat, parent_stat, child_stat), deploy.DeployError("path-read", "child inspection failed")),
        )
        for label, fstat_results, lstat_error in cases:
            with self.subTest(failure=label):
                patches = (
                    mock.patch.object(deploy.os, "mkdir"),
                    mock.patch.object(deploy.os, "open", return_value=11),
                    mock.patch.object(deploy.os, "fstat", side_effect=fstat_results),
                    mock.patch.object(deploy.os, "close"),
                )
                with patches[0], patches[1], patches[2], patches[3] as close:
                    lstat_patch = (
                        mock.patch.object(deploy, "_lstat", side_effect=lstat_error)
                        if lstat_error is not None
                        else contextlib.nullcontext()
                    )
                    with lstat_patch, self.assertRaises(deploy.DeployError):
                        deploy._mkdir_relative_posix(10, "child", self.root, self.root / "child")
                close.assert_called_once_with(11)

    def test_stage_writer_closes_unregistered_stage_handle_when_parent_close_fails(self) -> None:
        for platform, open_name, mkdir_name in (
            ("posix", "_open_directory_fd", "_mkdir_relative_posix"),
            ("nt", "_open_windows_directory", "_mkdir_relative_windows"),
        ):
            with self.subTest(platform=platform):
                parent_error = OSError("parent close failed")

                def close_handle(handle: int) -> None:
                    if handle == 10:
                        raise parent_error

                with (
                    mock.patch.object(deploy.os, "name", platform),
                    mock.patch.object(deploy, "_require_directory"),
                    mock.patch.object(deploy, "_lstat", return_value=None),
                    mock.patch.object(deploy, open_name, return_value=10),
                    mock.patch.object(deploy, mkdir_name, return_value=11),
                    mock.patch.object(deploy, "_close_directory_handle", side_effect=close_handle) as close,
                ):
                    with self.assertRaises(OSError) as raised:
                        deploy._StageWriter(self.root / f"stage-{platform}")

                self.assertIs(parent_error, raised.exception)
                self.assertEqual([mock.call(10), mock.call(11)], close.call_args_list)

    def test_stage_writer_close_attempts_every_handle_and_clears_ownership(self) -> None:
        writer = object.__new__(deploy._StageWriter)
        writer.handles = {Path(): 10, Path("one"): 11, Path("two"): 12}
        close_error = OSError("middle close failed")

        def close_handle(handle: int) -> None:
            if handle == 11:
                raise close_error

        with mock.patch.object(deploy, "_close_directory_handle", side_effect=close_handle) as close:
            with self.assertRaises(OSError) as raised:
                writer.close()
            writer.close()

        self.assertIs(close_error, raised.exception)
        self.assertEqual([mock.call(12), mock.call(11), mock.call(10)], close.call_args_list)
        self.assertEqual({}, writer.handles)

    def test_substitution_at_each_nested_creation_boundary_cannot_escape(self) -> None:
        name = deploy.MODS[0]
        boundaries = ("42.0", "media", "lua")
        for attacked in boundaries:
            with self.subTest(component=attacked):
                stage = self.root / f"stage-{attacked}"
                outside = self.root / f"outside-{attacked}"
                outside.mkdir()
                replaced = False

                def substitute(parent: Path, child: Path) -> None:
                    nonlocal replaced
                    if replaced or child.name != attacked:
                        return
                    replaced = True
                    if parent.exists():
                        shutil.rmtree(parent)
                    self.directory_symlink(outside, parent)

                with mock.patch.object(deploy, "_CREATE_BOUNDARY_HOOK", substitute):
                    with self.assertRaises(deploy.DeployError):
                        deploy.copy_source_package(self.source / name, stage)
                self.assertTrue(replaced)
                self.assertFalse(any(outside.iterdir()))

    def test_substitution_after_directory_creation_cannot_redirect_file_write(self) -> None:
        name = deploy.MODS[0]
        stage = self.root / "stage-write"
        outside = self.root / "outside-write"
        outside.mkdir()
        replaced = False

        def substitute(parent: Path, child: Path) -> None:
            nonlocal replaced
            if replaced or child.name != "example.lua":
                return
            replaced = True
            shutil.rmtree(parent)
            self.directory_symlink(outside, parent)

        with mock.patch.object(deploy, "_WRITE_BOUNDARY_HOOK", substitute):
            with self.assertRaises(deploy.DeployError):
                deploy.copy_source_package(self.source / name, stage)
        self.assertTrue(replaced)
        self.assertFalse(any(outside.iterdir()))

    def test_target_root_symlink_ancestry_is_rejected(self) -> None:
        real_target = self.make_target()
        linked_target = self.root / "linked-target"
        self.directory_symlink(real_target, linked_target)
        with self.assertRaisesRegex(deploy.DeployError, "reparse point"):
            deploy.canonical_destination(linked_target, deploy.MODS[0])

    def test_destination_symlink_is_rejected(self) -> None:
        target = self.make_target()
        outside = self.root / "outside-destination"
        outside.mkdir()
        self.directory_symlink(outside, target / deploy.MODS[0])
        with self.assertRaisesRegex(deploy.DeployError, "reparse point"):
            deploy.canonical_destination(target, deploy.MODS[0])

    def test_destination_substitution_after_prepare_is_rejected(self) -> None:
        target = self.make_target(old=True)
        name = deploy.MODS[0]
        expected, _ = deploy.source_manifest(self.source / name)
        item = deploy.prepare_deployment(self.source / name, target / name, expected)
        outside = self.root / "outside-destination"
        outside.mkdir()
        shutil.rmtree(target / name)
        self.directory_symlink(outside, target / name)
        with self.assertRaisesRegex(deploy.DeployError, "rolled back"):
            deploy.deploy_campaign([item])
        self.assertFalse((outside / "42.0").exists())

    def test_stage_substitution_after_prepare_is_rejected(self) -> None:
        target = self.make_target(old=True)
        name = deploy.MODS[0]
        expected, _ = deploy.source_manifest(self.source / name)
        item = deploy.prepare_deployment(self.source / name, target / name, expected)
        outside = self.root / "outside-stage"
        outside.mkdir()
        shutil.rmtree(item.stage)
        self.directory_symlink(outside, item.stage)
        with self.assertRaisesRegex(deploy.DeployError, "rolled back"):
            deploy.deploy_campaign([item])
        self.assertEqual(name, (target / name / "old").read_text(encoding="utf-8"))
        self.assertFalse((outside / "42.0").exists())

    def test_backup_substitution_after_prepare_is_rejected(self) -> None:
        target = self.make_target(old=True)
        name = deploy.MODS[0]
        expected, _ = deploy.source_manifest(self.source / name)
        item = deploy.prepare_deployment(self.source / name, target / name, expected)
        outside = self.root / "outside-backup"
        outside.mkdir()
        self.directory_symlink(outside, item.backup)
        with self.assertRaisesRegex(deploy.DeployError, "rolled back"):
            deploy.deploy_campaign([item])
        self.assertEqual(name, (target / name / "old").read_text(encoding="utf-8"))
        self.assertFalse(any(outside.iterdir()))

    def test_all_mods_are_staged_before_first_swap(self) -> None:
        target = self.make_target(old=True)
        events: list[str] = []
        real_prepare = deploy.prepare_deployment
        real_replace = deploy.os.replace

        def prepare(*args: object, **kwargs: object) -> deploy.Prepared:
            item = real_prepare(*args, **kwargs)
            events.append(f"stage:{item.name}")
            return item

        def replace(source: Path, destination: Path) -> None:
            events.append(f"swap:{Path(destination).name}")
            real_replace(source, destination)

        with mock.patch.object(deploy, "prepare_deployment", side_effect=prepare), mock.patch.object(deploy.os, "replace", side_effect=replace):
            code, _ = self.run_main("--deploy", "--target-root", str(target))
        self.assertEqual(deploy.EXIT_OK, code)
        self.assertLess(max(i for i, event in enumerate(events) if event.startswith("stage:")), min(i for i, event in enumerate(events) if event.startswith("swap:")))

    def test_later_mod_failure_rolls_back_earlier_mod(self) -> None:
        target = self.make_target(old=True)
        real_replace = deploy.os.replace
        install_count = 0

        def fail_second_install(source: Path, destination: Path) -> None:
            nonlocal install_count
            if ".stage-" in Path(source).name:
                install_count += 1
                if install_count == 2:
                    raise OSError("later mod failed")
            real_replace(source, destination)

        with mock.patch.object(deploy.os, "replace", side_effect=fail_second_install):
            code, report = self.run_main("--deploy", "--target-root", str(target))
        self.assertEqual(deploy.EXIT_DEPLOY_FAILED, code)
        self.assertEqual("deployment-failed", report["error"]["kind"])
        for name in deploy.MODS:
            self.assertEqual(name, (target / name / "old").read_text(encoding="utf-8"))

    def test_post_swap_validation_failure_rolls_back(self) -> None:
        target = self.make_target(old=True)
        real_manifest = deploy.directory_manifest

        def invalid_after_swap(path: Path) -> dict[str, deploy.Entry]:
            if path == target / deploy.MODS[0] and not (path / "old").exists():
                return {}
            return real_manifest(path)

        with mock.patch.object(deploy, "directory_manifest", side_effect=invalid_after_swap):
            code, report = self.run_main("--deploy", "--target-root", str(target), deploy.MODS[0])
        self.assertEqual(deploy.EXIT_DEPLOY_FAILED, code)
        self.assertEqual("deployment-failed", report["error"]["kind"])
        self.assertTrue((target / deploy.MODS[0] / "old").is_file())

    def test_cleanup_failure_is_success_with_retained_backup_warning(self) -> None:
        target = self.make_target(old=True)
        with mock.patch.object(deploy.shutil, "rmtree", side_effect=OSError("locked")):
            code, report = self.run_main("--deploy", "--target-root", str(target), deploy.MODS[0])
        self.assertEqual(deploy.EXIT_OK, code)
        self.assertEqual("succeeded", report["results"][0]["deployment"])
        self.assertEqual("backup-cleanup", report["warnings"][0]["kind"])
        self.assertTrue(report["warnings"][0]["retained_backup"])

    def test_rollback_failure_has_exact_exit_and_structured_artifacts(self) -> None:
        target = self.make_target(old=True)
        real_replace = deploy.os.replace
        calls = 0

        def fail_swap_and_rollback(source: Path, destination: Path) -> None:
            nonlocal calls
            calls += 1
            if calls >= 2:
                raise OSError("replace blocked")
            real_replace(source, destination)

        with mock.patch.object(deploy.os, "replace", side_effect=fail_swap_and_rollback):
            code, report = self.run_main("--deploy", "--target-root", str(target), deploy.MODS[0])
        self.assertEqual(deploy.EXIT_ROLLBACK_FAILED, code)
        self.assertEqual("rollback-failed", report["error"]["kind"])
        failure = report["error"]["rollback_failures"][0]
        self.assertIn("retained_stage", failure)
        self.assertIn("retained_backup", failure)

    def test_invalid_utf8_and_unreadable_metadata_are_structured(self) -> None:
        mod_info = self.source / deploy.MODS[0] / "mod.info"
        mod_info.write_bytes(b"\xff")
        code, report = self.run_main("--verify-only", deploy.MODS[0])
        self.assertEqual(deploy.EXIT_DRIFT, code)
        self.assertEqual("invalid-utf8", report["error"]["kind"])
        mod_info.write_text("versionMin=42.0\n", encoding="utf-8")
        with mock.patch.object(Path, "open", side_effect=PermissionError("denied")):
            code, report = self.run_main("--verify-only", deploy.MODS[0])
        self.assertEqual(deploy.EXIT_DRIFT, code)
        self.assertEqual("file-read", report["error"]["kind"])

    def test_file_read_race_checks_ignore_atime_but_detect_stable_identity_changes(self) -> None:
        path = self.source / deploy.MODS[0] / "poster.png"
        real_lstat = deploy._lstat
        original = real_lstat(path)
        self.assertIsNotNone(original)

        def snapshot(**changes: int) -> mock.Mock:
            values = {
                "st_mode": original.st_mode,
                "st_dev": original.st_dev,
                "st_ino": original.st_ino,
                "st_size": original.st_size,
                "st_atime_ns": original.st_atime_ns,
                "st_mtime_ns": original.st_mtime_ns,
                "st_ctime_ns": original.st_ctime_ns,
            }
            values.update(changes)
            return mock.Mock(**values)

        def run_reader(reader: str, after: mock.Mock) -> None:
            calls = 0

            def changing_lstat(candidate: Path, **kwargs: object) -> os.stat_result | mock.Mock | None:
                nonlocal calls
                if candidate == path:
                    calls += 1
                    return snapshot() if calls == 1 else after
                return real_lstat(candidate, **kwargs)

            with mock.patch.object(deploy, "_lstat", side_effect=changing_lstat):
                if reader == "copy":
                    stage = self.root / f"stage-race-{after.st_dev}-{after.st_ino}-{after.st_size}-{after.st_mtime_ns}-{after.st_ctime_ns}"
                    writer = deploy._StageWriter(stage)
                    try:
                        writer.copy(path, Path("poster.png"))
                    finally:
                        writer.close()
                elif reader == "sha256":
                    deploy.sha256(path)
                else:
                    deploy.entry(path)

        atime_only = snapshot(st_atime_ns=original.st_atime_ns + 1)
        failures = {
            "content mutation": snapshot(st_mtime_ns=original.st_mtime_ns + 1, st_ctime_ns=original.st_ctime_ns + 1),
            "size change": snapshot(st_size=original.st_size + 1),
            "same-size replacement": snapshot(st_dev=original.st_dev + 1, st_ino=original.st_ino + 1),
        }
        for reader in ("copy", "sha256", "entry"):
            with self.subTest(reader=reader, change="atime only"):
                run_reader(reader, atime_only)
            for change, changed in failures.items():
                with self.subTest(reader=reader, change=change):
                    with self.assertRaises(deploy.DeployError) as raised:
                        run_reader(reader, changed)
                    self.assertEqual("file-race", raised.exception.kind)

    def test_hash_race_is_structured(self) -> None:
        real_snapshot = deploy._stable_stat_snapshot
        calls = 0

        def changed(value: os.stat_result) -> tuple[int, int, int, int, int]:
            nonlocal calls
            calls += 1
            result = real_snapshot(value)
            if calls == 2:
                return (*result[:3], result[3] + 1, result[4] + 1)
            return result

        with mock.patch.object(deploy, "_stable_stat_snapshot", side_effect=changed):
            code, report = self.run_main("--verify-only", deploy.MODS[0])
        self.assertEqual(deploy.EXIT_DRIFT, code)
        self.assertEqual("file-race", report["error"]["kind"])

    def test_hostile_stage_and_backup_collisions_are_never_reused(self) -> None:
        target = self.make_target(old=True)
        name = deploy.MODS[0]
        token = "fixed"
        stage = target / f".{name}.stage-{token}"
        backup = target / f".{name}.backup-{token}"
        stage.mkdir()
        backup.mkdir()
        (stage / "hostile").write_text("keep", encoding="utf-8")
        with mock.patch.object(deploy.uuid, "uuid4", return_value=mock.Mock(hex=token)):
            code, report = self.run_main("--deploy", "--target-root", str(target), name)
        self.assertEqual(deploy.EXIT_DEPLOY_FAILED, code)
        self.assertEqual("artifact-collision", report["error"]["kind"])
        self.assertEqual("keep", (stage / "hostile").read_text(encoding="utf-8"))
        self.assertTrue(backup.is_dir())

    def test_visibility_gap_is_explicit_contract(self) -> None:
        target = self.make_target(old=True)
        code, report = self.run_main("--deploy", "--target-root", str(target), deploy.MODS[0])
        self.assertEqual(deploy.EXIT_OK, code)
        self.assertIs(report["results"][0]["visibility_gap"], True)

    def test_manifest_enforces_metadata_layout_and_drift(self) -> None:
        mod = self.source / deploy.MODS[0]
        expected, issues = deploy.source_manifest(mod)
        self.assertEqual([], issues)
        self.assertIn("mod.info", expected)
        self.assertIn("42.0/mod.info", expected)
        self.assertTrue(any(path.startswith("42.0/media/") for path in expected))
        (mod / "mod.info").write_text("versionMin=42\n", encoding="utf-8")
        _, issues = deploy.source_manifest(mod)
        self.assertTrue(any("must be 42.0" in issue for issue in issues))


def stat_mode_file() -> int:
    return stat.S_IFREG | 0o644

if __name__ == "__main__":
    unittest.main()
