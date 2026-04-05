#!/usr/bin/env bash
# deploy.sh — sync release folders then do a clean deploy to Zomboid mods
# Usage: bash deploy.sh
# Always deletes the existing mod folder before copying to avoid stale file accumulation.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODS_DIR="C:/Users/Admin/Zomboid/mods"

sync_and_deploy() {
    local name="$1"
    local src_media="$SCRIPT_DIR/$name/media"
    local release_media="$SCRIPT_DIR/$name/release/$name/42/media"
    local release_root="$SCRIPT_DIR/$name/release/$name"
    local mod_info="$SCRIPT_DIR/$name/mod.info"
    local dest="$MODS_DIR/$name"

    echo "--- $name ---"

    # Sync release folder from source
    cp -r "$src_media/." "$release_media/"
    cp "$mod_info" "$release_root/"
    cp "$mod_info" "$release_root/42/"

    # Clean deploy: delete old, copy fresh
    rm -rf "$dest"
    cp -r "$release_root/." "$dest/"

    echo "$name deployed to $dest"
}

sync_and_deploy "UniversalTraits"
sync_and_deploy "UT_CORE"

echo ""
echo "Done."
