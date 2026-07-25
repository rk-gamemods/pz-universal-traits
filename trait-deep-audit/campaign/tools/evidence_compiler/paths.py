"""Canonical paths for the UTMods evidence workflow."""

from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent
TOOLS_ROOT = PACKAGE_ROOT.parent
CAMPAIGN_ROOT = TOOLS_ROOT.parent
UTMODS_ROOT = CAMPAIGN_ROOT.parents[1]

DEFINITION_PATH = UTMODS_ROOT / "UniversalTraits/media/scripts/UT_character_traits.txt"
REGISTRY_PATH = UTMODS_ROOT / "UniversalTraits/media/registries.lua"
TRANSLATION_PATH = (
    UTMODS_ROOT / "UniversalTraits/media/lua/shared/Translate/EN/UI.json"
)
RUNTIME_TRAIT_ROOT = (
    UTMODS_ROOT / "UniversalTraits/media/lua/shared/UniversalTraits/traits"
)

CATALOG_JSON_PATH = CAMPAIGN_ROOT / "trait_catalog.json"
CATALOG_CSV_PATH = CAMPAIGN_ROOT / "trait_catalog.csv"
FINAL_LEDGER_ROWS_PATH = CAMPAIGN_ROOT / "final_trait_ledger_rows.jsonl"
REMEDIATION_QUEUE_PATH = CAMPAIGN_ROOT / "remediation_queue.jsonl"
REMEDIATION_SUMMARY_PATH = CAMPAIGN_ROOT / "remediation_summary.json"
RELEASE_BLOCKER_PATH = CAMPAIGN_ROOT / "release_blocker_queue.json"
RELEASE_PROFILE_PATH = CAMPAIGN_ROOT / "release_profile.json"
SOURCE_INVENTORY_PATH = CAMPAIGN_ROOT / "source_inventory.json"
TRANSLATION_AUDIT_PATH = CAMPAIGN_ROOT / "translation_audit.json"
ARTIFACT_GRAPH_PATH = PACKAGE_ROOT / "artifact_graph.json"
