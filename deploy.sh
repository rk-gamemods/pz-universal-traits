#!/usr/bin/env bash
# Thin compatibility wrapper. Python owns all verification and mutation logic.
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec py -3 "$SCRIPT_DIR/deploy.py" "$@"
