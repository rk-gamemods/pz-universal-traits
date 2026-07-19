"""Shared fail-closed CLI contract for single-purpose campaign commands."""

from __future__ import annotations

import sys
from collections.abc import Sequence


def no_arg_command(argv: Sequence[str], usage: str) -> int | None:
    """Return None to run, 0 after help, or 2 for unsupported arguments."""
    arguments = list(argv[1:])
    if not arguments:
        return None
    if arguments in (["--help"], ["-h"]):
        print(usage)
        return 0
    print(f"ERROR: this command accepts no arguments: {' '.join(arguments)}", file=sys.stderr)
    print(usage, file=sys.stderr)
    return 2
