#!/usr/bin/env python3
"""Stable entry point for the UTMods evidence catalog and focused QA planner."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN_TOOLS = ROOT / "trait-deep-audit/campaign/tools"
sys.path.insert(0, str(CAMPAIGN_TOOLS))

from evidence_compiler.cli import main  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(main())
