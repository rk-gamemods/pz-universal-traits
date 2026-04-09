#!/usr/bin/env python3
"""
Generate UT_SmokePings.lua from the PZ API inventory.

Reads pz_api_inventory.json and writes a Lua file containing one unguarded
call per unique API surface. When loaded in-game at OnGameStart, any broken
API surface triggers PZ's native error handler immediately.
"""

import argparse
import json
import sys
from pathlib import Path
from collections import defaultdict

SCRIPT_DIR = Path(__file__).resolve().parent
UTMODS_ROOT = SCRIPT_DIR.parent
DEFAULT_INVENTORY = SCRIPT_DIR / "pz_api_inventory.json"
DEFAULT_OUTPUT = (
    UTMODS_ROOT
    / "UniversalTraits"
    / "media"
    / "lua"
    / "shared"
    / "UniversalTraits"
    / "UT_SmokePings.lua"
)

# How to obtain each receiver variable at OnGameStart time.
# Key: receiver name from the inventory.
# Value: Lua expression that yields the receiver, or None to skip.
#
# "chain" entries are obtained by calling a method on a parent receiver.
# They don't need a root expression — the generator builds the chain.
RECEIVER_ROOTS = {
    # Player object — the main root for most pings
    "player":     "getPlayer()",
    "character":  "getPlayer()",
    "attacker":   "getPlayer()",
    "target":     "getPlayer()",

    # Chained from player
    "stats":       None,  # player:getStats()
    "bodyDamage":  None,  # player:getBodyDamage()
    "bd":          None,  # player:getBodyDamage()
    "nutrition":   None,  # player:getBodyDamage():getNutrition()
    "inv":         None,  # player:getInventory()
    "inventory":   None,  # player:getInventory()
    "container":   None,  # player:getInventory()
    "pack":        None,  # player:getInventory()
    "wornItems":   None,  # player:getWornItems()
    "wornItem":    None,  # requires wornItems:getItemByIndex(0)
    "ENDURANCE":   None,  # player:getStats():getEndurance()

    # Items — need getPrimaryHandItem() which can be nil
    "weapon":      None,  # player:getPrimaryHandItem()
    "primary":     None,  # player:getPrimaryHandItem()
    "secondary":   None,  # player:getSecondaryHandItem()
    "item":        None,  # generic item — skip at startup (needs game context)
    "food":        None,  # Food subclass — skip at startup
    "sourceItem":  None,  # skip

    # Body parts — chained from bodyDamage
    "part":        None,
    "head":        None,

    # Environment globals
    "vehicle":     None,  # no vehicle at startup — skip
    "square":      None,  # player:getCurrentSquare()
    "sq":          None,  # player:getCurrentSquare()
    "cm":          "getClimateManager()",
    "gt":          "getGameTime()",

    # Zombie — no zombie at startup
    "zombie":      None,
    "chr":         None,

    # Lua PZ globals (table access, not method calls)
    "ISEatFoodAction":    None,  # handled in Lua globals section
    "ISDrinkFluidAction": None,  # handled in Lua globals section
    "ISFitnessAction":    None,  # handled in Lua globals section,

    # Java collections — chained from other calls
    "spottedList": None,

    # Skip receivers (not PZ API — modData, strings, etc.)
    "obj":         None,
    "containerObj": None,
    "key":         None,
    "wtype":       None,
    "action":      None,
    "actionName":  None,
    "actionType":  None,
    "cats":        None,
    "trait":       None,
    "traitDefinition": None,
    "CharacterCreationProfession": None,
    "tree":        None,
    "md":          None,
    "fish":        None,
}

# Receivers that should be skipped entirely (no way to get them at startup,
# or they're not PZ API surfaces).
SKIP_RECEIVERS = {
    "obj", "key", "wtype", "action", "actionName", "actionType", "cats",
    "trait", "traitDefinition", "CharacterCreationProfession", "tree", "md",
    "fish", "containerObj",
}

# How to obtain chained receivers from a parent.
# (receiver_name, parent_receiver, method_on_parent)
CHAIN_SETUP = [
    # From player
    ("_stats",      "player",      "getStats()"),
    ("_bd",         "player",      "getBodyDamage()"),
    ("_nutrition",  "player",      "getNutrition()"),
    ("_inv",        "player",      "getInventory()"),
    ("_wornItems",  "player",      "getWornItems()"),
    ("_square",     "player",      "getCurrentSquare()"),
    # Body parts from BodyDamage (getBodyPart takes a BodyPartType enum)
    # Use getBodyParts():get(0) for a generic part ping
    ("_parts",      "_bd",         "getBodyParts()"),
]

# Maps inventory receivers to the local variable name used in the generated Lua.
RECEIVER_TO_LOCAL = {
    "player":     "player",
    "character":  "player",
    "attacker":   "player",
    "target":     "player",
    "stats":      "_stats",
    "bodyDamage": "_bd",
    "bd":         "_bd",
    "nutrition":  "_nutrition",
    "inv":        "_inv",
    "inventory":  "_inv",
    "container":  "_inv",
    "pack":       "_inv",
    "wornItems":  "_wornItems",
    "square":     "_square",
    "sq":         "_square",
    "cm":         "_cm",
    "gt":         "_gt",
    "ISEatFoodAction":    None,  # handled in Lua globals section
    "ISDrinkFluidAction": None,  # handled in Lua globals section
    "ISFitnessAction":    None,  # handled in Lua globals section
    "ENDURANCE":  None,  # CharacterStat enum constant, not the Stats object
    "spottedList": None,  # handled in ArrayList section,
    "part":       None,  # handled specially via _parts
    "head":       None,  # handled specially via _bd
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate UT_SmokePings.lua from PZ API inventory"
    )
    parser.add_argument(
        "--inventory",
        type=Path,
        default=DEFAULT_INVENTORY,
        help=f"Inventory JSON path (default: {DEFAULT_INVENTORY})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output Lua file path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated Lua to stdout instead of writing file",
    )
    return parser.parse_args()


def load_inventory(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


# Method prefixes that are safe to call at startup (read-only / no side effects).
# Anything not matching these prefixes is skipped to avoid mutating game state.
SAFE_METHOD_PREFIXES = (
    "get", "is", "has", "num", "size",
)


def _zero_arg_surfaces(inventory: dict) -> set[tuple[str, str]]:
    """Return (receiver, method) pairs that have at least one real zero-arg call site."""
    zero_arg: set[tuple[str, str]] = set()
    for cs in inventory.get("call_sites", []):
        # Exclude SmokePings' own entries (they always emit 0 args)
        if "UT_SmokePings" in cs.get("relative_file", ""):
            continue
        if cs.get("arg_count", 1) == 0:
            zero_arg.add((cs["receiver"], cs["method"]))
    return zero_arg


def build_ping_groups(inventory: dict) -> dict[str, list[str]]:
    """Group unique surfaces by receiver, returning {receiver: [method, ...]}.

    Only includes methods that have at least one real (non-SmokePings) call
    site with zero arguments, avoiding runtime crashes from calling setters
    or methods that require parameters.
    """
    zero_arg = _zero_arg_surfaces(inventory)
    groups: dict[str, list[str]] = defaultdict(list)
    for surface in inventory.get("unique_surfaces", []):
        if surface["verification_kind"] == "script_xpboosts":
            continue
        receiver = surface["receiver"]
        if receiver in SKIP_RECEIVERS:
            continue
        method = surface["method"]
        if (receiver, method) not in zero_arg:
            continue
        # Only ping read-only methods to avoid mutating game state at startup
        if not method.startswith(SAFE_METHOD_PREFIXES):
            continue
        groups[receiver].append(method)
    # Sort methods within each group for stable output
    return {r: sorted(set(methods)) for r, methods in groups.items()}


def generate_lua(ping_groups: dict[str, list[str]]) -> str:
    """Generate the Lua source for UT_SmokePings.lua."""
    lines = [
        "-- UT_SmokePings.lua",
        "-- Auto-generated by tools/generate_smoke_pings.py -- do not hand-edit.",
        "-- Fires every PZ API surface used by UniversalTraits at startup.",
        "-- If any call hits nil, PZ's error handler reports it immediately.",
        "",
        "local function runPings()",
        "    local player = getPlayer()",
        "    local _",
        "",
    ]

    # Set up chain roots
    lines.append("    -- Chain roots")
    for local_name, parent, method in CHAIN_SETUP:
        lines.append(f"    local {local_name} = {parent}:{method}")
    lines.append("")

    # Set up global roots
    lines.append("    -- Global roots")
    lines.append("    local _cm = getClimateManager()")
    lines.append("    local _gt = getGameTime()")
    lines.append("")

    # Group pings by the local variable they call on
    # Build a mapping: local_var -> [(method, comment), ...]
    var_pings: dict[str, list[tuple[str, str]]] = defaultdict(list)

    for receiver, methods in sorted(ping_groups.items()):
        local_var = RECEIVER_TO_LOCAL.get(receiver)
        if local_var is None:
            # Skip receivers we can't obtain at startup
            continue
        for method in methods:
            var_pings[local_var].append((method, receiver))

    # Emit pings grouped by local variable
    for local_var in sorted(var_pings.keys()):
        pings = var_pings[local_var]
        # Get a representative surface name for the comment
        receivers = sorted(set(p[1] for p in pings))
        lines.append(f"    -- {local_var} (receivers: {', '.join(receivers)})")
        for method, _receiver in sorted(pings):
            lines.append(f"    _ = {local_var}:{method}()")
        lines.append("")

    # Lua global existence checks (ISEatFoodAction etc.)
    lua_globals = []
    for receiver in sorted(ping_groups.keys()):
        if receiver in ("ISEatFoodAction", "ISDrinkFluidAction", "ISFitnessAction"):
            lua_globals.append(receiver)

    if lua_globals:
        lines.append("    -- Lua PZ globals")
        for g in lua_globals:
            methods = ping_groups[g]
            lines.append(f"    _ = {g}")
            for method in methods:
                lines.append(f"    _ = {g}.{method}")
        lines.append("")

    # ArrayList pings (spottedList etc.) via _parts
    if "spottedList" in ping_groups:
        lines.append("    -- Java collection interop (ArrayList)")
        for method in ping_groups["spottedList"]:
            lines.append(f"    _ = _parts:{method}()")
        lines.append("")

    lines.append("end")
    lines.append("")
    lines.append("Events.OnGameStart.Add(runPings)")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    inventory = load_inventory(args.inventory)
    ping_groups = build_ping_groups(inventory)

    lua_source = generate_lua(ping_groups)

    if args.dry_run:
        print(lua_source)
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(lua_source, encoding="utf-8")

    # Count pings
    ping_count = sum(len(methods) for methods in ping_groups.values())
    receiver_count = len(ping_groups)
    print(f"Generated {args.output}")
    print(f"  {ping_count} pings across {receiver_count} receivers")


if __name__ == "__main__":
    main()
