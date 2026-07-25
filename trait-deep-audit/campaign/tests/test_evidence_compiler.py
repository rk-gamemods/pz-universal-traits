from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CAMPAIGN = Path(__file__).resolve().parents[1]
TOOLS = CAMPAIGN / "tools"
sys.path.insert(0, str(TOOLS))

from evidence_compiler.atomic import AtomicWriteError, commit_files
from evidence_compiler.catalog import (
    build_catalog,
    render_catalog_csv,
    render_catalog_json,
)
from evidence_compiler.graph import affected_nodes, load_graph, recommended_tests
from evidence_compiler.status import _git_provenance, build_status
from run_campaign_tests import RunnerError, select_tests


class CatalogTests(unittest.TestCase):
    def test_current_catalog_is_closed_and_complete(self) -> None:
        catalog = build_catalog()
        counts = catalog["counts"]
        self.assertEqual(counts["definitions"], counts["rows"])
        self.assertEqual(counts["registrations"], counts["rows"])
        self.assertEqual(counts["audit_rows"], counts["rows"])
        self.assertEqual(counts["translation_keys"], counts["rows"] * 2)
        self.assertEqual([], catalog["integrity_errors"])
        self.assertEqual(
            sorted(row["trait_id"] for row in catalog["traits"]),
            [row["trait_id"] for row in catalog["traits"]],
        )
        self.assertEqual(
            {"dedicated-file", "no-dedicated-file"},
            {row["runtime_discovery"] for row in catalog["traits"]},
        )

    def test_catalog_rendering_is_byte_deterministic(self) -> None:
        catalog = build_catalog()
        self.assertEqual(render_catalog_json(catalog), render_catalog_json(catalog))
        self.assertEqual(render_catalog_csv(catalog), render_catalog_csv(catalog))
        self.assertTrue(render_catalog_json(catalog).endswith(b"\n"))
        self.assertTrue(render_catalog_csv(catalog).endswith(b"\n"))

    def test_csv_is_an_abbreviated_review_view(self) -> None:
        header = render_catalog_csv(build_catalog()).splitlines()[0].decode("utf-8")
        self.assertIn("trait_id", header)
        self.assertIn("cost", header)
        self.assertIn("description", header)
        self.assertIn("audit_state", header)
        self.assertIn("release_blockers", header)


class GraphTests(unittest.TestCase):
    def test_trait_source_change_has_exact_downstream_closure(self) -> None:
        changed = ["UniversalTraits/media/scripts/UT_character_traits.txt"]
        affected = affected_nodes(changed)
        self.assertIn("trait-catalog", affected)
        self.assertIn("source-inventory", affected)
        self.assertIn("translation-audit", affected)
        self.assertIn("normalized-ledger", affected)
        self.assertIn("remediation", affected)
        self.assertIn("release-readiness", affected)
        self.assertEqual("campaign-manifest", affected[-1])

    def test_test_change_reaches_manifest_and_its_own_suite(self) -> None:
        affected = affected_nodes(
            ["trait-deep-audit/campaign/tests/test_regenerate_albino.py"]
        )
        self.assertEqual(["campaign-manifest"], affected)
        self.assertEqual(
            ["test_campaign_tools.py", "test_regenerate_albino.py"],
            recommended_tests(
                ["trait-deep-audit/campaign/tests/test_regenerate_albino.py"]
            ),
        )

    def test_generator_change_selects_shared_and_trait_contracts(self) -> None:
        changed = [
            "trait-deep-audit/campaign/tools/regenerate_albino.py"
        ]
        self.assertEqual(
            [
                "normalized-ledger",
                "remediation",
                "trait-catalog",
                "release-readiness",
                "campaign-manifest",
            ],
            affected_nodes(changed),
        )
        self.assertEqual(
            [
                "test_campaign_tools.py",
                "test_evidence_compiler.py",
                "test_regenerate_albino.py",
            ],
            recommended_tests(changed),
        )

    def test_graph_rejects_cycles(self) -> None:
        value = {
            "schema_version": "utmods.artifact_graph.v1",
            "nodes": [
                {
                    "id": "a",
                    "outputs": [],
                    "direct_inputs": [],
                    "depends_on": ["b"],
                    "tests": [],
                    "terminal": False,
                },
                {
                    "id": "b",
                    "outputs": [],
                    "direct_inputs": [],
                    "depends_on": ["a"],
                    "tests": [],
                    "terminal": False,
                },
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "graph.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "cycle"):
                load_graph(path)


class AtomicWriteTests(unittest.TestCase):
    def test_partial_replacement_failure_restores_every_original(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "a.json"
            second = root / "b.json"
            first.write_bytes(b"old-a\n")
            second.write_bytes(b"old-b\n")
            calls = 0

            def fail_second(source, target) -> None:
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("injected replacement failure")
                os.replace(source, target)

            with self.assertRaises(AtomicWriteError):
                commit_files(
                    {first: b"new-a\n", second: b"new-b\n"},
                    replace=fail_second,
                )
            self.assertEqual(b"old-a\n", first.read_bytes())
            self.assertEqual(b"old-b\n", second.read_bytes())
            self.assertEqual([], list(root.glob("*.tmp")))


class StatusAndSelectionTests(unittest.TestCase):
    def test_git_provenance_accepts_a_clean_descendant_and_rejects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*arguments: str) -> str:
                completed = subprocess.run(
                    ["git", *arguments],
                    cwd=root,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=10,
                    check=True,
                )
                return completed.stdout.strip()

            git("init")
            git("config", "user.email", "evidence@example.invalid")
            git("config", "user.name", "Evidence Test")
            source = root / "UniversalTraits/media"
            core = root / "UT_CORE/media"
            source.mkdir(parents=True)
            core.mkdir(parents=True)
            (source / "trait.txt").write_text("baseline\n", encoding="utf-8")
            (core / "service.lua").write_text("baseline\n", encoding="utf-8")
            git("add", "--", "UniversalTraits/media", "UT_CORE/media")
            git("commit", "-m", "source baseline")
            inventory_head = git("rev-parse", "HEAD")

            (root / "audit.txt").write_text("evidence\n", encoding="utf-8")
            git("add", "--", "audit.txt")
            git("commit", "-m", "audit evidence")
            clean = _git_provenance(root, inventory_head)
            self.assertTrue(clean["worktree_clean"])
            self.assertTrue(clean["inventory_is_ancestor"])
            self.assertTrue(clean["source_unchanged"])

            (root / "audit.txt").write_text("dirty\n", encoding="utf-8")
            self.assertFalse(_git_provenance(root, inventory_head)["worktree_clean"])
            git("add", "--", "audit.txt")
            git("commit", "-m", "audit update")

            (source / "trait.txt").write_text("changed\n", encoding="utf-8")
            git("add", "--", "UniversalTraits/media/trait.txt")
            git("commit", "-m", "source change")
            changed = _git_provenance(root, inventory_head)
            self.assertTrue(changed["worktree_clean"])
            self.assertTrue(changed["inventory_is_ancestor"])
            self.assertFalse(changed["source_unchanged"])

    def test_status_names_the_views_without_claiming_release_readiness(self) -> None:
        status = build_status()
        self.assertEqual(
            build_catalog()["counts"]["rows"], status["counts"]["traits"]
        )
        self.assertGreater(status["counts"]["open_queue_records"], 0)
        self.assertFalse(status["release_ready"])
        self.assertTrue(any(not item["passed"] for item in status["gate_checks"]))

    def test_runner_selects_exact_module(self) -> None:
        tests = [Path("test_a.py"), Path("test_b.py")]
        self.assertEqual([Path("test_b.py")], select_tests(tests, ["test_b"]))

    def test_runner_rejects_unknown_explicit_module(self) -> None:
        with self.assertRaises(RunnerError):
            select_tests([Path("test_a.py")], ["test_missing"])

    def test_runner_uses_graph_for_changed_file(self) -> None:
        tests = [Path("test_campaign_tools.py"), Path("test_evidence_compiler.py")]
        selected = select_tests(
            tests,
            changed_files=[
                "trait-deep-audit/campaign/tools/evidence_compiler/catalog.py"
            ],
        )
        self.assertEqual(
            [Path("test_campaign_tools.py"), Path("test_evidence_compiler.py")],
            selected,
        )


if __name__ == "__main__":
    unittest.main()
