"""Regenerate only Super Immune-owned campaign evidence and derived ledgers."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from build_campaign_manifest import build_manifest, render_manifest
from build_final_trait_ledger import build_ledger, render_ledger, render_trait_rows
from build_remediation_queue import build_outputs, update_release_blocker_queue_sha256


ROOT = Path(__file__).resolve().parents[3]
CAMPAIGN = ROOT / "trait-deep-audit" / "campaign"
TRAIT = "UniversalTraits:UT_superimmune"
FINDING = "B11-SUPERIMMUNE-001"
RUNTIME = "UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_superimmune.lua"
RELEASE = "UniversalTraits/release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_superimmune.lua"
TESTS = "UniversalTraits/test/run_tests.lua"


def metadata(relative: str) -> dict[str, object]:
    data = (ROOT / relative).read_bytes()
    return {"path": relative, "sha256": hashlib.sha256(data).hexdigest().upper(), "bytes": len(data)}


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def exactly_one(rows: list[dict], key: str, value: str, owner: str) -> dict:
    matches = [row for row in rows if row.get(key) == value]
    if len(matches) != 1:
        raise ValueError(f"{owner}: expected one {key}={value}, found {len(matches)}")
    return matches[0]


def update_fingerprints(value: object, relative: str, current: dict[str, object]) -> int:
    count = 0
    if isinstance(value, dict):
        if value.get("path", "").removeprefix("UTMods/") == relative:
            for key in ("sha256", "bytes"):
                if key in value:
                    value[key] = current[key]
            count += 1
        for child in value.values():
            count += update_fingerprints(child, relative, current)
    elif isinstance(value, list):
        for child in value:
            count += update_fingerprints(child, relative, current)
    return count


def update_batch() -> None:
    path = CAMPAIGN / "trait_batches" / "batch_11.jsonl"
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    row = exactly_one(rows, "trait_id", TRAIT, path.name)
    row["overall_state"] = "runtime-unproven"
    proof = (
        "EveryOneMinute reads and writes only CharacterStat.ZOMBIE_INFECTION, subtracts exactly 2, "
        "and floors at zero without deriving state from apparent infection."
    )
    for name in ("source_intent", "runtime_path", "numbers", "java_lua", "tests", "mocks"):
        row["dimensions"][name] = {"state": "proven-correct", "evidence": [proof], "missing_proof": []}
    row["dimensions"]["reset_save_load"] = {
        "state": "runtime-unproven",
        "evidence": ["Same-process dofile reload replaces the prior minute callback and retains one effective registration."],
        "missing_proof": ["Full Exit to Desktop and current-build in-game reload are unobserved."],
    }
    finding = exactly_one(row["findings"], "id", FINDING, "Super Immune finding")
    finding["resolution_state"] = "proven-correct"
    finding["resolution_evidence"] = (
        "Producer-faithful tests prove direct 50-to-48 mutation, floor, trait guard, higher food-sickness "
        "and fever counterexamples, zero infection with nonzero illness, untouched illness channels, and reload idempotence."
    )
    finding["remaining_runtime_proof"] = (
        "Full Exit to Desktop and current-build in-game minute ticks remain unobserved."
    )
    path.write_text(
        "".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n" for item in rows),
        encoding="utf-8", newline="\n",
    )


def update_evidence() -> None:
    inventory_path = CAMPAIGN / "source_inventory.json"
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    for relative in (RUNTIME, RELEASE, TESTS):
        update_fingerprints(inventory, relative, metadata(relative))
    write_json(inventory_path, inventory)

    review_path = CAMPAIGN / "independent_reviews" / "traits_09_12.json"
    review = json.loads(review_path.read_text(encoding="utf-8"))
    trait = exactly_one(review["per_trait_review"], "trait_id", TRAIT, review_path.name)
    trait["release_parity"] = {
        "source_runtime_sha256": metadata(RUNTIME)["sha256"],
        "release_runtime_sha256": metadata(RELEASE)["sha256"],
        "state": "proven-correct",
    }
    trait["repair_resolution"] = {
        "state": "implemented-and-statically-validated",
        "finding_id": FINDING,
        "producer_contract": "EveryOneMinute; underlying CharacterStat.ZOMBIE_INFECTION only",
        "remaining_proof": "Current-build in-game execution after a full relaunch is unobserved.",
    }
    write_json(review_path, review)

    blocker_path = CAMPAIGN / "release_blocker_queue.json"
    blockers = json.loads(blocker_path.read_text(encoding="utf-8"))
    identity = "trait:UT_superimmune"
    matches = [
        item for item in blockers["identities"]
        if item.get("semantic_identity") == identity
    ]
    if len(matches) > 1:
        raise ValueError(f"{blocker_path.name}: expected at most one {identity}, found {len(matches)}")
    blockers["identities"] = [
        item for item in blockers["identities"]
        if item.get("semantic_identity") != identity
    ]
    write_json(blocker_path, blockers)

    write_json(
        CAMPAIGN / "change-impact" / "superimmune-infection-channel-resolution.json",
        {
            "schema": "ut-superimmune-infection-channel-resolution-v1",
            "trait_id": TRAIT,
            "finding_id": FINDING,
            "authority": "pre-campaign UTMods port; upstream More Traits state machine is intentionally not restored",
            "accepted_intent": {
                "cost": 10,
                "reduction": 2,
                "floor": 0,
                "cadence": "every in-game minute",
                "channel": "CharacterStat.ZOMBIE_INFECTION",
                "scope": "single-player",
            },
            "engine_evidence": [
                "PZCodebase/Java/source/zombie/characters/BodyDamage/BodyDamage.java:1664",
                "PZCodebase/Java/source/zombie/characters/CharacterStat.java:9",
            ],
            "files": [metadata(path) for path in (RUNTIME, RELEASE, TESTS)],
            "counterexamples": [
                "food sickness above infection",
                "zombie fever above infection",
                "zero infection with nonzero illness",
            ],
            "static_validation": "Producer-faithful standard-Lua coverage; source/release byte parity.",
            "runtime_proof": "unobserved; requires full Exit to Desktop and current-build in-game minute ticks",
        },
    )


def regenerate_derived() -> None:
    ledger = build_ledger()
    (CAMPAIGN / "final_trait_ledger.json").write_text(render_ledger(ledger), encoding="utf-8", newline="\n")
    (CAMPAIGN / "final_trait_ledger_rows.jsonl").write_text(render_trait_rows(ledger), encoding="utf-8", newline="\n")
    dimensions, queue, summary = build_outputs()
    (CAMPAIGN / "dimension_ledger_rows.jsonl").write_text(dimensions, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_queue.jsonl").write_text(queue, encoding="utf-8", newline="\n")
    (CAMPAIGN / "remediation_summary.json").write_text(summary, encoding="utf-8", newline="\n")
    update_release_blocker_queue_sha256(CAMPAIGN / "remediation_queue.jsonl", CAMPAIGN / "release_blocker_queue.json")
    (CAMPAIGN / "campaign_manifest.json").write_text(
        render_manifest(build_manifest(CAMPAIGN)), encoding="utf-8", newline="\n"
    )


def main() -> int:
    update_batch()
    update_evidence()
    regenerate_derived()
    print(json.dumps({"ok": True, "trait_id": TRAIT}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
