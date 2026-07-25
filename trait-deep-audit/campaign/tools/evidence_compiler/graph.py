"""Dependency-aware planning for focused UTMods evidence work."""

from __future__ import annotations

import fnmatch
import json
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

from .paths import ARTIFACT_GRAPH_PATH


def _normalized(path: str | Path) -> str:
    return str(path).replace("\\", "/").lstrip("./")


def load_graph(path: Path = ARTIFACT_GRAPH_PATH) -> dict[str, Any]:
    graph = json.loads(path.read_text(encoding="utf-8"))
    nodes = graph.get("nodes")
    if graph.get("schema_version") != "utmods.artifact_graph.v1" or not isinstance(
        nodes, list
    ):
        raise ValueError("artifact graph has an unsupported schema")
    by_id: dict[str, dict[str, Any]] = {}
    for node in nodes:
        node_id = node.get("id")
        if not isinstance(node_id, str) or not node_id or node_id in by_id:
            raise ValueError(f"artifact graph has an invalid node id: {node_id!r}")
        by_id[node_id] = node
    for node_id, node in by_id.items():
        for dependency in node.get("depends_on", []):
            if dependency not in by_id:
                raise ValueError(f"{node_id} has unknown dependency {dependency}")
            if by_id[dependency].get("terminal"):
                raise ValueError(
                    f"{node_id} depends on terminal node {dependency}"
                )

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node_id: str) -> None:
        if node_id in visiting:
            raise ValueError(f"artifact graph cycle includes {node_id}")
        if node_id in visited:
            return
        visiting.add(node_id)
        for dependency in by_id[node_id].get("depends_on", []):
            visit(dependency)
        visiting.remove(node_id)
        visited.add(node_id)

    for node_id in by_id:
        visit(node_id)
    return graph


def affected_nodes(
    changed_paths: list[str | Path], graph: dict[str, Any] | None = None
) -> list[str]:
    graph = graph or load_graph()
    nodes = {node["id"]: node for node in graph["nodes"]}
    direct: set[str] = set()
    normalized_paths = [_normalized(path) for path in changed_paths]
    for node_id, node in nodes.items():
        patterns = [_normalized(pattern) for pattern in node.get("direct_inputs", [])]
        outputs = {_normalized(path) for path in node.get("outputs", [])}
        if any(
            path in outputs
            or any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
            for path in normalized_paths
        ):
            direct.add(node_id)

    dependents: dict[str, set[str]] = defaultdict(set)
    for node_id, node in nodes.items():
        for dependency in node.get("depends_on", []):
            dependents[dependency].add(node_id)
    affected = set(direct)
    queue = deque(sorted(direct))
    while queue:
        current = queue.popleft()
        for dependent in sorted(dependents[current]):
            if dependent not in affected:
                affected.add(dependent)
                queue.append(dependent)

    order: list[str] = []
    temporary: set[str] = set()
    permanent: set[str] = set()

    def append_after_dependencies(node_id: str) -> None:
        if node_id in permanent:
            return
        if node_id in temporary:
            raise ValueError(f"artifact graph cycle includes {node_id}")
        temporary.add(node_id)
        for dependency in nodes[node_id].get("depends_on", []):
            if dependency in affected:
                append_after_dependencies(dependency)
        temporary.remove(node_id)
        permanent.add(node_id)
        order.append(node_id)

    for node in graph["nodes"]:
        if node["id"] in affected:
            append_after_dependencies(node["id"])
    return order


def recommended_tests(
    changed_paths: list[str | Path], graph: dict[str, Any] | None = None
) -> list[str]:
    graph = graph or load_graph()
    affected = set(affected_nodes(changed_paths, graph))
    tests = {
        test
        for node in graph["nodes"]
        if node["id"] in affected
        for test in node.get("tests", [])
    }
    for raw_path in changed_paths:
        name = Path(_normalized(raw_path)).name
        if name.startswith("regenerate_") and name.endswith(".py"):
            tests.add(f"test_{name}")
        elif name.startswith("test_") and name.endswith(".py"):
            tests.add(name)
    return sorted(tests)
