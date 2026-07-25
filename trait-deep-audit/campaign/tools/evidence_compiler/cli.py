"""Command line interface for the UTMods evidence workflow."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .atomic import AtomicWriteError, commit_files
from .catalog import build_catalog, render_catalog_csv, render_catalog_json
from .graph import affected_nodes, load_graph, recommended_tests
from .paths import CATALOG_CSV_PATH, CATALOG_JSON_PATH
from .status import build_status


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Build and navigate the compact UTMods evidence index."
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    catalog = subcommands.add_parser(
        "catalog", help="build or verify the generated trait catalog"
    )
    action = catalog.add_mutually_exclusive_group()
    action.add_argument("--write", action="store_true")
    action.add_argument("--check", action="store_true")

    plan = subcommands.add_parser(
        "plan", help="show the smallest affected evidence and test closure"
    )
    plan.add_argument("--changed-file", action="append", required=True)
    plan.add_argument("--json", action="store_true")

    status = subcommands.add_parser(
        "status", help="show named audit, queue, and release counts"
    )
    status.add_argument("--json", action="store_true")

    release = subcommands.add_parser(
        "release-gate", help="evaluate the current single-player release profile"
    )
    release.add_argument("--json", action="store_true")
    return parser


def _print_status(value: dict[str, object]) -> None:
    counts = value["counts"]
    print(f"release_ready: {str(value['release_ready']).lower()}")
    print(f"traits: {counts['traits']}")
    print(f"trait_states: {json.dumps(counts['trait_states'], sort_keys=True)}")
    print(f"open_queue_records: {counts['open_queue_records']}")
    print(
        "open_queue_states: "
        + json.dumps(counts["open_queue_states"], sort_keys=True)
    )
    print(f"release_blocker_identities: {counts['release_blocker_identities']}")
    print(f"catalog_integrity_errors: {counts['catalog_integrity_errors']}")
    failed = [item for item in value["gate_checks"] if not item["passed"]]
    for item in failed:
        print(f"not_ready: {item['id']}: {item['detail']}")


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "catalog":
            catalog = build_catalog()
            rendered = {
                CATALOG_JSON_PATH: render_catalog_json(catalog),
                CATALOG_CSV_PATH: render_catalog_csv(catalog),
            }
            if args.check:
                stale = [
                    path
                    for path, data in rendered.items()
                    if not path.is_file() or path.read_bytes() != data
                ]
                result = {
                    "ok": not stale and not catalog["integrity_errors"],
                    "rows": catalog["counts"]["rows"],
                    "integrity_errors": catalog["integrity_errors"],
                    "stale_outputs": [str(path) for path in stale],
                }
                print(json.dumps(result, indent=2, sort_keys=True))
                return 0 if result["ok"] else 1
            if args.write:
                changed = commit_files(rendered)
                print(
                    json.dumps(
                        {
                            "ok": not catalog["integrity_errors"],
                            "rows": catalog["counts"]["rows"],
                            "changed": [str(path) for path in changed],
                            "integrity_errors": catalog["integrity_errors"],
                        },
                        indent=2,
                        sort_keys=True,
                    )
                )
                return 0 if not catalog["integrity_errors"] else 1
            print(
                json.dumps(
                    {
                        "rows": catalog["counts"]["rows"],
                        "counts": catalog["counts"],
                        "integrity_errors": catalog["integrity_errors"],
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0 if not catalog["integrity_errors"] else 1

        if args.command == "plan":
            graph = load_graph()
            value = {
                "changed_files": args.changed_file,
                "affected_nodes": affected_nodes(args.changed_file, graph),
                "recommended_campaign_tests": recommended_tests(
                    args.changed_file, graph
                ),
            }
            if args.json:
                print(json.dumps(value, indent=2, sort_keys=True))
            else:
                print("affected_nodes: " + ", ".join(value["affected_nodes"]))
                print(
                    "recommended_campaign_tests: "
                    + ", ".join(value["recommended_campaign_tests"])
                )
            return 0

        value = build_status()
        if args.json:
            print(json.dumps(value, indent=2, sort_keys=True))
        else:
            _print_status(value)
        return 0 if args.command == "status" or value["release_ready"] else 1
    except (AtomicWriteError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
