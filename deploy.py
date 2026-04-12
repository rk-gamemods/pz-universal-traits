#!/usr/bin/env python3
"""deploy.py — sync release folders and deploy to Zomboid mods directory.

Usage:
    python deploy.py              # deploy both mods
    python deploy.py UT_CORE      # deploy one mod
    python deploy.py --verify     # deploy both, then hash-verify source vs live
"""

import hashlib
import os
import re
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MODS_DIR = Path(r"C:\Users\Admin\Zomboid\mods")
MODS = ["ZZ_ModProfiler", "UniversalTraits", "UT_CORE"]
VERSION_DIR = "42.0"  # Must match versionMin in mod.info


def mirror(src: Path, dst: Path) -> None:
    """Delete dst and replace with a fresh copy of src."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def deploy(mod_name: str) -> None:
    mod_root = SCRIPT_DIR / mod_name
    src_media = mod_root / "media"
    mod_info = mod_root / "mod.info"
    release_root = mod_root / "release" / mod_name
    release_media = release_root / VERSION_DIR / "media"
    live_dir = MODS_DIR / mod_name

    # Validate source exists
    if not src_media.is_dir():
        sys.exit(f"ERROR: source media not found: {src_media}")
    if not mod_info.is_file():
        sys.exit(f"ERROR: mod.info not found: {mod_info}")

    # Validate VERSION_DIR matches versionMin in mod.info
    mod_info_text = mod_info.read_text(encoding="utf-8")
    m = re.search(r"versionMin\s*=\s*(\S+)", mod_info_text)
    if not m:
        sys.exit(f"ERROR: no versionMin found in {mod_info}")
    version_min = m.group(1)
    if version_min != VERSION_DIR:
        sys.exit(
            f"ERROR: VERSION_DIR mismatch! deploy.py uses '{VERSION_DIR}' "
            f"but mod.info says versionMin={version_min}. "
            f"PZ loads from '{version_min}/' — update VERSION_DIR."
        )

    print(f"--- {mod_name} ---")

    # 1. Sync source media -> release/ModName/VERSION_DIR/media
    print(f"  sync media -> release")
    mirror(src_media, release_media)

    # 2. Copy mod.info into release root and VERSION_DIR/
    shutil.copy2(mod_info, release_root / "mod.info")
    shutil.copy2(mod_info, release_root / VERSION_DIR / "mod.info")

    # 3. Deploy release → live (mirror deletes stale content)
    print(f"  deploy -> {live_dir}")
    mirror(release_root, live_dir)

    # 4. Safety: check for stale version dirs that PZ might load instead
    if live_dir.is_dir():
        for d in live_dir.iterdir():
            if d.is_dir() and re.match(r"^\d+(\.\d+)?$", d.name) and d.name != VERSION_DIR:
                sys.exit(
                    f"ERROR: stale version dir '{d.name}' found in {live_dir}! "
                    f"PZ might load it instead of '{VERSION_DIR}'. Delete it manually."
                )

    print(f"  done")


def file_hash(path: Path) -> str:
    h = hashlib.md5()
    h.update(path.read_bytes())
    return h.hexdigest()


def verify(mod_name: str) -> list[str]:
    """Compare source files against live deployed files. Returns list of mismatches."""
    src_media = SCRIPT_DIR / mod_name / "media"
    live_media = MODS_DIR / mod_name / VERSION_DIR / "media"
    mismatches = []

    for src_file in src_media.rglob("*"):
        if not src_file.is_file():
            continue
        rel = src_file.relative_to(src_media)
        live_file = live_media / rel
        if not live_file.exists():
            mismatches.append(f"  MISSING in live: {rel}")
        elif file_hash(src_file) != file_hash(live_file):
            mismatches.append(f"  HASH MISMATCH:   {rel}")

    # Check for extra files in live that aren't in source
    if live_media.is_dir():
        for live_file in live_media.rglob("*"):
            if not live_file.is_file():
                continue
            rel = live_file.relative_to(live_media)
            if not (src_media / rel).exists():
                mismatches.append(f"  EXTRA in live:   {rel}")

    return mismatches


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    do_verify = "--verify" in sys.argv

    targets = args if args else MODS

    for name in targets:
        if name not in MODS:
            sys.exit(f"ERROR: unknown mod '{name}'. Expected one of: {MODS}")

    for name in targets:
        deploy(name)

    if do_verify:
        print("\n=== Verification ===")
        all_ok = True
        for name in targets:
            problems = verify(name)
            if problems:
                all_ok = False
                print(f"{name}: {len(problems)} issue(s)")
                for p in problems:
                    print(p)
            else:
                print(f"{name}: OK — all files match")
        if not all_ok:
            sys.exit(1)

    print("\nDone. Exit to Desktop before testing.")


if __name__ == "__main__":
    main()
