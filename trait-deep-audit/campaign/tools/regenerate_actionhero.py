"""Regenerate the deterministic Action Hero campaign resolution surfaces."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

from build_campaign_manifest import build_manifest, render_manifest


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRACE = CAMPAIGN / "runtime-traces" / "wave-01-single" / "UT_actionhero.json"
RESOLUTION = CAMPAIGN / "change-impact" / "actionhero-handler-lifecycle-resolution.json"
MANIFEST = CAMPAIGN / "campaign_manifest.json"

RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_actionhero.lua"
RUNTIME_RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_actionhero.lua"
CORE = "UT_CORE/media/lua/shared/UTCore/UTCore_TickDispatch.lua"
CORE_RELEASE = "UT_CORE/release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_TickDispatch.lua"
MOCKS = "UniversalTraits/test/UTTestMocks.lua"
TESTS = "UniversalTraits/test/run_tests.lua"


def metadata(relative: str) -> dict[str, object]:
    data = (ROOT / relative).read_bytes()
    return {
        "path": relative,
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
    }


def render(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def write_if_changed(path: Path, data: bytes) -> bool:
    if path.exists() and path.read_bytes() == data:
        return False
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)
    return True


def build_resolution() -> dict[str, object]:
    return {
        "schema": "ut-actionhero-handler-lifecycle-resolution-v1",
        "trait_id": "UniversalTraits:UT_actionhero",
        "accepted_intent": {
            "cost": 8,
            "cadence_player_update_dispatches": 30,
            "living_enemy_threshold": 3,
            "range_tiles_inclusive": 10,
            "critical_chance_bonus_percentage_points": 15,
            "displayed_critical_chance_cap": 100,
            "both_equipped_eligible_weapons": True,
            "same_object_deduplicated": True,
            "mundane_suppresses": True,
        },
        "resolution": {
            "registration": "Action Hero unregisters prior callbacks before replacement and retains exactly one callback.",
            "cleanup_order": "Every unregister invokes teardown before removing the handler or active snapshot entry.",
            "restoration": "Teardown, trait deactivation, Mundane suppression, invalid/dead player, swap, and unequip restore every tracked weapon by identity.",
            "mock_contract": "Focused dispatch invokes every registered matching handler, so duplicates cannot be hidden by first-match dispatch.",
            "persistence_boundary": "No UT_ahBaseCrit modData is read or written; current-version in-game save/reload remains unproven.",
        },
        "files": [metadata(path) for path in (RUNTIME, RUNTIME_RELEASE, CORE, CORE_RELEASE, MOCKS, TESTS)],
        "validation_contract": [
            "focused Action Hero tests",
            "UT_CORE suite",
            "UniversalTraits suite with unrelated failures classified",
            "31 campaign tests and validator",
            "JSON parse and source/release parity",
            "two-pass regeneration fixed point",
        ],
        "remaining_proof": [
            "full Exit to Desktop and current-build in-game reload",
            "Java bridge critical-chance and sharpness behavior in game",
            "active/inactive/Mundane/swap/save/reload lifecycle in game",
        ],
    }


def update_trace() -> dict[str, object]:
    trace = json.loads(TRACE.read_text(encoding="utf-8"))
    trace["decision"]["status"] = "implemented-and-statically-validated"
    trace["resolution"].update({
        "handler_lifecycle": "Opt-in teardown restores tracked weapons before unregister; Action Hero reload replaces all prior callbacks and leaves one registration.",
        "deactivation_cleanup": "Active-set removal and invalid/dead-player teardown restore all outstanding Action Hero modifications.",
        "mock_dispatch": "The focused mock dispatches every matching registered handler and asserts callback counts.",
    })
    trace["test_plan"]["executed"] = True
    trace["test_plan"].pop("reason_not_executed", None)
    trace["test_plan"]["written_unexecuted_cases"] = []
    trace["test_plan"]["direct_byte_hashes"] = {
        TESTS: metadata(TESTS)["sha256"],
        MOCKS: metadata(MOCKS)["sha256"],
    }
    trace["test_plan"]["focused_anchors"] = [
        "UniversalTraits/test/run_tests.lua:727-1025",
        "UniversalTraits/test/UTTestMocks.lua:548-790",
    ]
    trace["test_plan"]["executed_cases"] = [
        "count/range boundaries, +15/cap, sharpness/raw domains",
        "same-object deduplication, swap/unequip, Mundane restoration",
        "list/size/get/isDead/DistTo atomic failures",
        "all-handler mock dispatch, handler counts, duplicate load/reload",
        "cleanup before removal, trait deactivation, invalid-player teardown",
        "no stale UT_ahBaseCrit modData assumption",
    ]
    trace["validation"]["commands_or_tests_run"] = [
        "UniversalTraits/test/run_tests.lua",
        "UT_CORE/test/run_tests.lua",
        "trait-deep-audit/campaign/tests/test_campaign_tools.py",
        "trait-deep-audit/campaign/tools/validate_campaign.py",
    ]
    trace["source_snapshot"]["runtime_source"] = metadata(RUNTIME)
    trace["source_snapshot"]["runtime_release"] = metadata(RUNTIME_RELEASE)
    return trace


def main() -> int:
    changed: list[str] = []
    if write_if_changed(TRACE, render(update_trace())):
        changed.append(str(TRACE.relative_to(ROOT)))
    if write_if_changed(RESOLUTION, render(build_resolution())):
        changed.append(str(RESOLUTION.relative_to(ROOT)))
    manifest = render_manifest(build_manifest(CAMPAIGN)).encode("utf-8")
    if write_if_changed(MANIFEST, manifest):
        changed.append(str(MANIFEST.relative_to(ROOT)))
    print(json.dumps({"changed": changed}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
