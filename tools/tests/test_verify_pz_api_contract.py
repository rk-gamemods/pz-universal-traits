import hashlib
import importlib.util
import json
import sys
from argparse import Namespace
from datetime import date
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).parents[1] / "verify_pz_api.py"
SPEC = importlib.util.spec_from_file_location("verify_pz_api", MODULE_PATH)
verifier = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = verifier
SPEC.loader.exec_module(verifier)

META_BASE = {"game_build": "42.1.0", "layer_hashes": {"java": "j", "lua": "l", "media": "m"}}


def source_manifest(source_hash="source-a", verifier_hash="tool-a", evidence_hash="evidence-a"):
    source_hash = hashlib.sha256(source_hash.encode()).hexdigest()
    verifier_hash = hashlib.sha256(verifier_hash.encode()).hexdigest()
    evidence_hash = hashlib.sha256(evidence_hash.encode()).hexdigest()
    files = [
        {"path": "PZCodebase/Java/source/zombie/Foo.java", "sha256": source_hash, "size": 10},
        {"path": "UTMods/tools/verify_pz_api.py", "sha256": verifier_hash, "size": 20},
        {"path": "UTMods/tools/tests/evidence.txt", "sha256": evidence_hash, "size": 30},
        {"path": "UTMods/tools/custom-baseline.json", "sha256": "b" * 64, "size": 40},
        {"path": "UTMods/tools/custom-allowlist.json", "sha256": "a" * 64, "size": 50},
    ]
    policy_files = {
        "baseline": "UTMods/tools/custom-baseline.json",
        "allowlist": "UTMods/tools/custom-allowlist.json",
    }
    payload = {"schema_version": 1, "files": files, "policy_files": policy_files}
    binding_payload = {"schema_version": 1, "files": files[:3]}
    return {
        **payload,
        "manifest_hash": hashlib.sha256(verifier.canonical_json(payload).encode()).hexdigest(),
        "binding_hash": hashlib.sha256(verifier.canonical_json(binding_payload).encode()).hexdigest(),
        "errors": [],
    }


def surface(status="OK", receiver="player", method="getStats", occurrences=1):
    return {
        "surface_name": "IsoPlayer", "receiver": receiver, "method": method,
        "verification_kind": "method_call", "statuses": [status],
        "owners": ["trait:fixture"], "files": ["fixture.lua"],
        "occurrence_count": occurrences,
    }


def callsite(receiver="player", method="getStats", arg_count=0, line=1, status="OK"):
    return {
        "id": f"fixture.lua:{line}:{receiver}:{method}",
        "relative_file": "fixture.lua", "line": line, "receiver": receiver,
        "method": method, "arg_count": arg_count, "status": status,
        "surface_name": "IsoPlayer", "verification_kind": "method_call",
        "matched_class": "IsoPlayer", "matched_method": method, "detail": "fixture",
        "line_text": f"{receiver}:{method}()", "verification_source": "pz_api_scan",
        "owner": {"kind": "trait", "id": "fixture", "file": "fixture.lua"},
    }


def inventory(surfaces=None, calls=None, version="42.1.0", hashes=None, manifest=None):
    manifest = manifest or source_manifest()
    return {
        "pzc_version": version,
        "pzc_layer_hashes": META_BASE["layer_hashes"] if hashes is None else hashes,
        "source_manifest_hash": manifest["binding_hash"],
        "input_manifest_hash": manifest["manifest_hash"],
        "source_manifest": manifest,
        "unique_surfaces": [surface()] if surfaces is None else surfaces,
        "call_sites": [callsite()] if calls is None else calls,
    }


def baseline(surfaces=None, version="42.1.0", hashes=None, manifest_hash=None):
    return {
        "pzc_version": version,
        "pzc_layer_hashes": META_BASE["layer_hashes"] if hashes is None else hashes,
        "source_manifest_hash": manifest_hash or source_manifest()["binding_hash"],
        "unique_surfaces": [surface()] if surfaces is None else surfaces,
    }


def evaluate(inv=None, base=None, allow=None):
    inv = inv or inventory()
    meta = {**META_BASE, "source_manifest_hash": inv.get("source_manifest_hash")}
    return verifier.evaluate_strict_contract(
        inv, meta, baseline(manifest_hash=inv.get("source_manifest_hash")) if base is None else base,
        {"schema_version": 1, "exceptions": []} if allow is None else allow,
        date(2026, 7, 19),
    )


def exception_for(inv, issue, **overrides):
    manifest = inv["source_manifest"]
    entry = {
        "id": issue["id"], "surface": issue["surface"], "status": issue["category"],
        "reason": "Reviewed dynamic fixture receiver", "owner": "api-reviewers",
        "reviewed_on": "2026-07-19", "expires_on": "2026-12-31",
        "evidence": {"path": "UTMods/tools/tests/evidence.txt", "sha256": manifest["files"][2]["sha256"]},
        "pzc_version": "42.1.0", "pzc_layer_hashes": META_BASE["layer_hashes"],
        "source_manifest_hash": inv["source_manifest_hash"],
        "call_sites": [verifier._callsite_identity(call) for call in inv["call_sites"]],
    }
    entry.update(overrides)
    return entry


def test_clean_exact_snapshot_is_update_safe():
    result = evaluate()
    assert result["update_safe"] is True
    assert verifier.contract_exit_code(result) == verifier.EXIT_OK == 0


@pytest.mark.parametrize("status", ["SKIP", "WARN", "FAIL", "MAYBE", "BLOCK"])
def test_non_green_and_unknown_statuses_fail_closed(status):
    inv = inventory([surface(status)], [callsite(status=status)])
    assert evaluate(inv, baseline([surface(status)], manifest_hash=inv["source_manifest_hash"]))["update_safe"] is False


def test_source_bytes_changed_with_version_unchanged_blocks():
    before = source_manifest("source-a")
    after = source_manifest("source-b")
    inv = inventory(manifest=after)
    result = evaluate(inv, baseline(manifest_hash=before["binding_hash"]))
    assert result["update_safe"] is False
    assert "version-hash-mismatch" in {issue["category"] for issue in result["issues"]}


def test_missing_and_corrupt_required_inputs_are_foundational():
    inv = inventory()
    inv["source_manifest"]["errors"] = [{"path": "missing.lua", "error": "missing_or_not_file"}]
    assert evaluate(inv)["update_safe"] is False
    assert verifier.evaluate_strict_contract(inv, {**META_BASE, "source_manifest_hash": inv["source_manifest_hash"]}, None, None)["update_safe"] is False


def test_foundational_failures_cannot_be_waived():
    inv = inventory(version="old")
    raw = evaluate(inv)
    issue = next(item for item in raw["issues"] if item["category"] == "inventory-stale")
    attempted = exception_for(inv, issue)
    assert evaluate(inv, allow={"schema_version": 1, "exceptions": [attempted]})["update_safe"] is False


def test_exact_callsite_bounded_exception_is_approved():
    inv = inventory([surface("SKIP")], [callsite(status="SKIP")])
    raw = evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]))
    issue = next(item for item in raw["issues"] if item["category"] == "skip")
    entry = exception_for(inv, issue)
    result = evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]), {"schema_version": 1, "exceptions": [entry]})
    assert result["update_safe"] is True


@pytest.mark.parametrize("mutation", ["extra_call", "different_arity", "different_line"])
def test_exception_does_not_cover_additional_occurrence_arity_or_callsite(mutation):
    inv = inventory([surface("SKIP")], [callsite(status="SKIP")])
    raw = evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]))
    entry = exception_for(inv, next(item for item in raw["issues"] if item["category"] == "skip"))
    if mutation == "extra_call":
        inv["call_sites"].append(callsite(line=2, status="SKIP"))
    elif mutation == "different_arity":
        inv["call_sites"][0]["arg_count"] = 1
    else:
        inv["call_sites"][0]["line"] = 99
    assert evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]), {"schema_version": 1, "exceptions": [entry]})["update_safe"] is False


@pytest.mark.parametrize("change", [
    {"unknown": True},
    {"owner": 7},
    {"reviewed_on": "not-a-date"},
    {"expires_on": "2026-01-01"},
    {"evidence": {"path": "UTMods/tools/tests/evidence.txt", "sha256": "drift"}},
    {"source_manifest_hash": "drift"},
    {"pzc_layer_hashes": {"java": "drift"}},
])
def test_malformed_allowlist_entries_and_evidence_drift_block(change):
    inv = inventory([surface("SKIP")], [callsite(status="SKIP")])
    raw = evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]))
    entry = exception_for(inv, next(item for item in raw["issues"] if item["category"] == "skip"))
    entry.update(change)
    assert evaluate(inv, baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"]), {"schema_version": 1, "exceptions": [entry]})["update_safe"] is False


def test_wrong_receiver_ambiguity_blocks_instead_of_first_match():
    call = verifier.MethodCall("fixture.lua", 1, "player", "sameMethod", 0, "player:sameMethod()")
    method_a = verifier.JavaMethod("sameMethod", 0, "void", "A.java", 1)
    method_b = verifier.JavaMethod("sameMethod", 0, "void", "B.java", 1)
    result = verifier.verify_call(call, {"IsoPlayer": {"sameMethod": [method_a]}, "IsoGameCharacter": {"sameMethod": [method_b]}}, {})
    assert result.status == "BLOCK"


def test_partial_candidate_match_blocks_wrong_receiver_flow():
    call = verifier.MethodCall("fixture.lua", 1, "player", "childOnly", 0, "player:childOnly()")
    method = verifier.JavaMethod("childOnly", 0, "void", "Child.java", 1)
    result = verifier.verify_call(call, {"IsoPlayer": {"childOnly": [method]}, "IsoGameCharacter": {}}, {})
    assert result.status == "BLOCK"


@pytest.mark.parametrize("text", [
    "player:getStats(\n  nested(1, 2)\n)",
    "-- player:fake()\nplayer:getStats('a,b')",
    "local x = [=[player:fake()]=]\nplayer:getStats()",
])
def test_parser_handles_multiline_strings_and_comments(tmp_path, text):
    path = tmp_path / "fixture.lua"
    path.write_text(text, encoding="utf-8")
    calls = verifier.extract_mod_calls(path)
    assert [(call.receiver, call.method) for call in calls] == [("player", "getStats")]
    assert calls[0].arg_count >= 0


def test_forage_categories_is_empty_is_one_hash_set_surface(tmp_path, monkeypatch):
    relative_path = Path(
        "UniversalTraits/media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua"
    )
    path = tmp_path / relative_path
    path.parent.mkdir(parents=True)
    path.write_text(
        "local function isWildPlantItem(item)\n"
        "    -- cats:isEmpty() is documentation, not a call\n"
        "    local example = 'cats:isEmpty()'\n"
        "    local ok, cats = pcall(function() return item:getScriptItem():getForageFocusCategories() end)\n"
        "    return ok and cats ~= nil and not cats:isEmpty()\n"
        "end\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(verifier, "UTMODS_ROOT", tmp_path)
    calls = [call for call in verifier.extract_mod_calls(path)
             if call.receiver == "cats" and call.method == "isEmpty"]
    results = [verifier.verify_call(call, {}, {}) for call in calls]
    entries = [verifier.build_inventory_entry(result) for result in results]
    inventory_result = verifier.build_inventory(results, META_BASE)
    assert len(calls) == 1

    assert results[0].status == "OK"
    assert entries[0]["surface_name"] == "HashSet"
    assert inventory_result["unique_surfaces"] == [{
        "surface_name": "HashSet",
        "receiver": "cats",
        "method": "isEmpty",
        "verification_kind": "method_call",
        "statuses": ["OK"],
        "owners": ["runtime_support:UT_ItemConsumptionHooks"],
        "files": [relative_path.as_posix()],
        "occurrence_count": 1,
    }]


def test_unknown_parser_syntax_blocks(tmp_path):
    path = tmp_path / "fixture.lua"
    path.write_text("player:getStats([=[unterminated)", encoding="utf-8")
    call = verifier.extract_mod_calls(path)[0]
    assert verifier.verify_call(call, {}, {}).status == "BLOCK"


def test_schema_corruption_and_unknown_fields_block_without_throwing():
    inv = inventory()
    inv["unknown"] = True
    inv["unique_surfaces"][0]["statuses"] = "OK"
    result = evaluate(inv)
    assert result["update_safe"] is False
    assert "inventory-shape" in {issue["category"] for issue in result["issues"]}


def test_unknown_cli_flags_have_exact_internal_exit(monkeypatch):
    monkeypatch.setattr(sys, "argv", [str(MODULE_PATH), "--unknown-flag"])
    with pytest.raises(SystemExit) as exc:
        verifier.parse_args()
    assert exc.value.code == verifier.EXIT_INTERNAL_ERROR == 2


def test_reports_and_internal_errors_are_deterministic_and_bounded():
    surfaces = [surface("SKIP", receiver=f"dynamic{i}", method="call") for i in range(150)]
    calls = [callsite(receiver=f"dynamic{i}", method="call", status="SKIP") for i in range(150)]
    first = evaluate(inventory(surfaces, calls))
    second = evaluate(inventory(list(reversed(surfaces)), list(reversed(calls))))
    assert len(first["issues"]) == verifier.MAX_REPORT_ISSUES
    assert first["truncated"] is True
    assert first["issue_ids"] == second["issue_ids"]
    assert verifier.contract_exit_code(first) == verifier.EXIT_BLOCKED == 1
    assert verifier.internal_error_payload("ValueError", "bad") == {
        "schema_version": 1, "status": "internal_error",
        "error": {"kind": "ValueError", "message": "bad"}, "exit_code": 2,
    }


def test_custom_policy_paths_are_manifested_but_not_self_bound(tmp_path, monkeypatch):
    workspace = tmp_path / "workspace"
    utmods = workspace / "UTMods"
    monkeypatch.setattr(verifier, "UTMODS_ROOT", utmods)
    baseline_path = utmods / "policy" / "renamed-snapshot.json"
    allowlist_path = utmods / "policy" / "renamed-exceptions.json"
    source_path = utmods / "media" / "pz_api_baseline.json"
    for path, text in ((baseline_path, "baseline"), (allowlist_path, "allowlist"), (source_path, "source")):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    manifest = verifier.build_source_manifest(
        [baseline_path, allowlist_path, source_path], baseline_path, allowlist_path,
    )
    assert manifest["policy_files"] == {
        "baseline": "UTMods/policy/renamed-snapshot.json",
        "allowlist": "UTMods/policy/renamed-exceptions.json",
    }
    bound = {"schema_version": 1, "files": [
        item for item in manifest["files"] if item["path"] == "UTMods/media/pz_api_baseline.json"
    ]}
    assert manifest["binding_hash"] == hashlib.sha256(verifier.canonical_json(bound).encode()).hexdigest()


@pytest.mark.parametrize("field", ["surface_name", "matched_class", "matched_method"])
@pytest.mark.parametrize("wrong_value", [False, 0, [], {}])
def test_every_nullable_callsite_field_rejects_wrong_types(field, wrong_value):
    inv = inventory()
    inv["call_sites"][0][field] = wrong_value
    result = evaluate(inv)
    assert result["update_safe"] is False
    assert "inventory-shape" in {issue["category"] for issue in result["issues"]}


@pytest.mark.parametrize("wrong_value", [False, 0, [], {}])
def test_nullable_inventory_surface_name_rejects_wrong_types(wrong_value):
    inv = inventory()
    inv["unique_surfaces"][0]["surface_name"] = wrong_value
    assert evaluate(inv)["update_safe"] is False


@pytest.mark.parametrize("wrong_value", [False, 0, [], {}])
def test_nullable_allowlist_surface_name_rejects_wrong_types(wrong_value):
    inv = inventory([surface("SKIP")], [callsite(status="SKIP")])
    base = baseline([surface("SKIP")], manifest_hash=inv["source_manifest_hash"])
    raw = evaluate(inv, base)
    entry = exception_for(inv, next(item for item in raw["issues"] if item["category"] == "skip"))
    entry["surface"]["surface_name"] = wrong_value
    result = evaluate(inv, base, {"schema_version": 1, "exceptions": [entry]})
    assert result["update_safe"] is False
    assert "allowlist-shape" in {issue["category"] for issue in result["issues"]}


@pytest.mark.parametrize("field", ["line", "arg_count"])
def test_bool_is_not_accepted_as_inventory_integer(field):
    inv = inventory()
    inv["call_sites"][0][field] = True
    assert evaluate(inv)["update_safe"] is False


@pytest.mark.parametrize("field", [
    "game_build", "decompiled_at", "game_path", "decompiler_launcher", "java_runtime",
])
@pytest.mark.parametrize("wrong_value", [None, False, 7, [], {}])
def test_version_metadata_rejects_every_wrong_scalar_field_type(tmp_path, monkeypatch, field, wrong_value):
    codebase = tmp_path / "PZCodebase"
    codebase.mkdir()
    value = {
        "game_build": "42.1.0", "decompiled_at": "2026-07-19T00:00:00Z",
        "game_path": "C:/PZ", "decompiler_launcher": "launcher", "java_runtime": "java",
        "layer_hashes": {"java": "j", "lua": "l", "media": "m"},
    }
    value[field] = wrong_value
    (codebase / "VERSION.json").write_text(json.dumps(value), encoding="utf-8")
    monkeypatch.setattr(verifier, "PZ_CODEBASE", codebase)
    with pytest.raises(ValueError, match="scalar field types"):
        verifier.load_pzcodebase_metadata()


@pytest.mark.parametrize("layer_hashes", [
    None,
    False,
    [],
    {"java": "j", "lua": "l"},
    {"java": "j", "lua": "l", "media": "m", "extra": "x"},
    {"java": False, "lua": "l", "media": "m"},
    {"java": "j", "lua": None, "media": "m"},
    {"java": "j", "lua": "l", "media": 7},
])
def test_version_metadata_rejects_malformed_layer_hash_schema(tmp_path, monkeypatch, layer_hashes):
    codebase = tmp_path / "PZCodebase"
    codebase.mkdir()
    value = {"game_build": "42.1.0", "layer_hashes": layer_hashes}
    (codebase / "VERSION.json").write_text(json.dumps(value), encoding="utf-8")
    monkeypatch.setattr(verifier, "PZ_CODEBASE", codebase)
    with pytest.raises(ValueError, match="layer_hashes"):
        verifier.load_pzcodebase_metadata()


def _install_real_run_fixture(monkeypatch, tmp_path, json_output, phase):
    codebase = tmp_path / "PZCodebase"
    codebase.mkdir()
    monkeypatch.setattr(verifier, "PZ_CODEBASE", codebase)
    manifest = source_manifest()
    inv = inventory(surfaces=[], calls=[], manifest=manifest)
    meta = {**META_BASE, "source_manifest_hash": manifest["binding_hash"]}
    base = baseline([], manifest_hash=manifest["binding_hash"])
    report = {
        "schema_version": 1, "mode": "strict", "update_safe": True,
        "status": "update_safe", "counts": {"issues": 0, "unapproved": 0, "approved": 0, "unused_allowlist": 0},
        "issue_ids": [], "issues": [], "approved_exceptions": [], "truncated": False,
    }
    args = Namespace(
        verbose=False, json_output=json_output, inventory_json=False,
        inventory_out=(tmp_path / "inventory.json") if phase in {"inventory-serialization", "inventory-write"} else None,
        baseline_file=tmp_path / "baseline.json", compare_baseline=False, mode="strict",
        allowlist_file=tmp_path / "allowlist.json", write_baseline=phase in {"baseline-construction", "baseline-write"},
    )
    monkeypatch.setattr(verifier, "parse_args", lambda: args)
    monkeypatch.setattr(verifier, "load_pzcodebase_metadata", lambda: META_BASE)
    monkeypatch.setattr(verifier, "required_input_paths", lambda *_: [])
    manifest_calls = {"count": 0}

    def manifest_phase(*_args):
        manifest_calls["count"] += 1
        if phase == "final-manifest" and manifest_calls["count"] == 2:
            raise RuntimeError("final-manifest failed")
        return manifest

    monkeypatch.setattr(verifier, "build_source_manifest", manifest_phase)
    monkeypatch.setattr(verifier, "build_java_api_index", lambda: {})
    monkeypatch.setattr(verifier, "resolve_java_index_with_inheritance", lambda index: index)
    monkeypatch.setattr(verifier, "build_lua_api_index", lambda: {})
    monkeypatch.setattr(verifier, "scan_all_mod_calls", lambda: [])
    monkeypatch.setattr(verifier, "extract_perk_names_from_java", lambda _path: set())
    monkeypatch.setattr(verifier, "verify_xpboosts", lambda *_: [])
    monkeypatch.setattr(verifier, "build_inventory", lambda *_: inv)
    monkeypatch.setattr(verifier, "load_baseline", lambda _path: base)
    monkeypatch.setattr(verifier, "load_allowlist", lambda _path: {"schema_version": 1, "exceptions": []})
    monkeypatch.setattr(verifier, "evaluate_strict_contract", lambda *_: report)

    expected_kind = "RuntimeError"
    expected_message = f"{phase} failed"
    if phase == "java-extraction":
        monkeypatch.setattr(verifier, "build_java_api_index", lambda: (_ for _ in ()).throw(RuntimeError("java-extraction failed")))
    elif phase == "lua-extraction":
        monkeypatch.setattr(verifier, "build_lua_api_index", lambda: (_ for _ in ()).throw(RuntimeError("lua-extraction failed")))
    elif phase == "source-scan":
        monkeypatch.setattr(verifier, "scan_all_mod_calls", lambda: (_ for _ in ()).throw(RuntimeError("source-scan failed")))
    elif phase == "call-verification":
        call = verifier.MethodCall("fixture.lua", 1, "player", "getStats", 0, "player:getStats()")
        monkeypatch.setattr(verifier, "scan_all_mod_calls", lambda: [call])
        monkeypatch.setattr(verifier, "verify_call", lambda *_: (_ for _ in ()).throw(RuntimeError("call-verification failed")))
    elif phase == "perk-extraction":
        monkeypatch.setattr(verifier, "extract_perk_names_from_java", lambda *_: (_ for _ in ()).throw(RuntimeError("perk-extraction failed")))
    elif phase == "xpboost-verification":
        monkeypatch.setattr(verifier, "verify_xpboosts", lambda *_: (_ for _ in ()).throw(RuntimeError("xpboost-verification failed")))
    elif phase == "inventory-construction":
        monkeypatch.setattr(verifier, "build_inventory", lambda *_: (_ for _ in ()).throw(RuntimeError("inventory-construction failed")))
    elif phase == "inventory-serialization":
        monkeypatch.setattr(verifier, "build_inventory", lambda *_: {**inv, "unserializable": {"value"}})
        expected_kind = "TypeError"
        expected_message = "Object of type set is not JSON serializable"
    elif phase == "inventory-write":
        monkeypatch.setattr(verifier, "write_inventory", lambda *_: (_ for _ in ()).throw(RuntimeError("inventory-write failed")))
    elif phase == "strict-verification":
        monkeypatch.setattr(verifier, "evaluate_strict_contract", lambda *_: (_ for _ in ()).throw(RuntimeError("strict-verification failed")))
    elif phase == "baseline-construction":
        monkeypatch.setattr(verifier, "build_baseline_snapshot", lambda *_: (_ for _ in ()).throw(RuntimeError("baseline-construction failed")))
    elif phase == "baseline-write":
        monkeypatch.setattr(verifier, "write_baseline", lambda *_: (_ for _ in ()).throw(RuntimeError("baseline-write failed")))
    return args, expected_kind, expected_message


@pytest.mark.parametrize("phase", [
    "java-extraction", "lua-extraction", "source-scan", "call-verification",
    "perk-extraction", "xpboost-verification",
    "inventory-construction", "inventory-serialization", "inventory-write",
    "strict-verification", "final-manifest", "baseline-construction", "baseline-write",
])
@pytest.mark.parametrize("json_output", [False, True])
def test_real_post_manifest_phase_exceptions_have_exact_public_contract(monkeypatch, capsys, tmp_path, phase, json_output):
    args, expected_kind, expected_message = _install_real_run_fixture(monkeypatch, tmp_path, json_output, phase)
    with pytest.raises(SystemExit) as exc:
        verifier.main()
    captured = capsys.readouterr()
    error_stream = captured.out if json_output else captured.err
    other_stream = captured.err if json_output else captured.out
    payloads = [json.loads(line) for line in error_stream.splitlines() if line.startswith("{")]
    assert exc.value.code == verifier.EXIT_INTERNAL_ERROR == 2
    assert len(payloads) == 1
    expected_payload = verifier.internal_error_payload(expected_kind, expected_message)
    assert payloads[0] == expected_payload
    assert "Traceback" not in captured.out + captured.err
    if json_output:
        assert captured.err == ""
        assert captured.out == json.dumps(expected_payload, sort_keys=True, separators=(",", ":")) + "\n"
    else:
        assert captured.err == json.dumps(expected_payload, sort_keys=True, separators=(",", ":")) + "\n"
        assert "internal_error" not in other_stream
    assert not args.inventory_out or not args.inventory_out.exists()
    assert not args.baseline_file.exists()


def test_inventory_and_json_serialization_are_byte_deterministic(tmp_path):
    manifest = source_manifest()
    inv1 = verifier.build_inventory([], META_BASE, manifest)
    inv2 = verifier.build_inventory([], META_BASE, manifest)
    assert inv1 == inv2
    first_path = tmp_path / "first.json"
    second_path = tmp_path / "second.json"
    verifier.write_inventory(first_path, inv1)
    verifier.write_inventory(second_path, inv2)
    assert first_path.read_bytes() == second_path.read_bytes()
    assert json.dumps({"inventory": inv1}, indent=2, sort_keys=True).encode() == json.dumps({"inventory": inv2}, indent=2, sort_keys=True).encode()


def test_method_declarations_are_not_counted_as_call_occurrences(tmp_path):
    path = tmp_path / "fixture.lua"
    path.write_text(
        "function player:getStats(value)\n  return value\nend\nplayer:getStats(1)\n",
        encoding="utf-8",
    )
    calls = verifier.extract_mod_calls(path)
    assert [(call.receiver, call.method, call.line_num) for call in calls] == [("player", "getStats", 4)]
