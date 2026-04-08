#!/usr/bin/env python3
"""
PZ API Surface Verifier — Offline codebase comparison.

Scans all UT mod Lua files for PZ API method calls (object:method()),
then verifies each call exists in the actual decompiled PZ Java/Lua codebase.

Reports:
  FAIL  — Method missing entirely from the Java/Lua class (will crash at runtime)
  WARN  — Method exists but parameter count differs (may crash depending on overloads)
  OK    — Method confirmed present with matching signature

Usage:
    python tools/verify_pz_api.py
    python tools/verify_pz_api.py --verbose
    python tools/verify_pz_api.py --json  # machine-readable summary
    python tools/verify_pz_api.py --inventory-out reports/pz_api_inventory.json
"""

import argparse
import re
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass
from typing import Optional

# ============================================================
# CONFIGURATION
# ============================================================

SCRIPT_DIR = Path(__file__).resolve().parent
UTMODS_ROOT = SCRIPT_DIR.parent
PZ_CODEBASE = UTMODS_ROOT.parent / "PZCodebase"
PZ_JAVA_ROOT = PZ_CODEBASE / "Java" / "source"
PZ_LUA_ROOT = PZ_CODEBASE / "Lua"
DEFAULT_BASELINE_FILE = SCRIPT_DIR / "pz_api_baseline.json"

# Mod source directories to scan
MOD_LUA_DIRS = [
    UTMODS_ROOT / "UniversalTraits" / "media" / "lua",
    UTMODS_ROOT / "UT_CORE" / "media" / "lua",
]

# ============================================================
# RECEIVER → JAVA CLASS MAPPING
#
# Maps Lua variable names (as used in our mod code) to the Java
# classes whose public methods they can call. Order matters for
# multi-class receivers (checked first → last).
# ============================================================

# Java class files: relative to PZ_JAVA_ROOT
JAVA_CLASS_FILES = {
    "GameTime": "zombie/GameTime.java",
    "IsoGameCharacter": "zombie/characters/IsoGameCharacter.java",
    "IsoPlayer": "zombie/characters/IsoPlayer.java",
    "IsoZombie": "zombie/characters/IsoZombie.java",
    "Stats": "zombie/characters/Stats.java",
    "CharacterStat": "zombie/characters/CharacterStat.java",
    "BodyDamage": "zombie/characters/BodyDamage/BodyDamage.java",
    "BodyPart": "zombie/characters/BodyDamage/BodyPart.java",
    "Nutrition": "zombie/characters/BodyDamage/Nutrition.java",
    "InventoryItem": "zombie/inventory/InventoryItem.java",
    "ItemContainer": "zombie/inventory/ItemContainer.java",
    "Food": "zombie/inventory/types/Food.java",
    "HandWeapon": "zombie/inventory/types/HandWeapon.java",
    "BaseVehicle": "zombie/vehicles/BaseVehicle.java",
    "IsoGridSquare": "zombie/iso/IsoGridSquare.java",
    "IsoObject": "zombie/iso/IsoObject.java",
    "IsoMovingObject": "zombie/iso/IsoMovingObject.java",
    "IsoLivingCharacter": "zombie/characters/IsoLivingCharacter.java",
    "Clothing": "zombie/inventory/types/Clothing.java",
    "ClimateManager": "zombie/iso/weather/ClimateManager.java",
    "Literature": "zombie/inventory/types/Literature.java",
    "WornItems": "zombie/characters/WornItems/WornItems.java",
    "WornItem": "zombie/characters/WornItems/WornItem.java",
    "PerkFactory": "zombie/characters/skills/PerkFactory.java",
}

# PZ Lua source files that define methods our mod overrides/calls
PZ_LUA_FILES = {
    "ISEatFoodAction": "shared/TimedActions/ISEatFoodAction.lua",
    "ISDrinkFluidAction": "shared/TimedActions/ISDrinkFluidAction.lua",
    "ISFitnessAction": "shared/TimedActions/ISFitnessAction.lua",
    "CharacterCreationProfession": None,  # Java-side, handled via class map
}

# Receiver variable → candidate Java classes (checked in order)
# The verifier assigns calls to the first class that has the method.
RECEIVER_MAP = {
    # Player objects (most common)
    "player":     ["IsoPlayer", "IsoGameCharacter", "IsoLivingCharacter", "IsoMovingObject", "IsoObject"],
    "character":  ["IsoPlayer", "IsoGameCharacter", "IsoLivingCharacter", "IsoMovingObject"],
    "chr":        ["IsoZombie", "IsoPlayer", "IsoGameCharacter", "IsoLivingCharacter"],
    "attacker":   ["IsoGameCharacter", "IsoPlayer"],
    "target":     ["IsoGameCharacter", "IsoZombie"],

    # Return-type receivers (method return → new class)
    "stats":       ["Stats"],
    "bodyDamage":  ["BodyDamage"],
    "bd":          ["BodyDamage"],
    "nutrition":   ["Nutrition"],
    "inv":         ["ItemContainer"],
    "inventory":   ["ItemContainer"],
    "container":   ["ItemContainer"],
    "containerObj": ["IsoObject"],

    # Item hierarchy
    "item":        ["Literature", "InventoryItem", "Food", "HandWeapon", "Clothing"],
    "food":        ["Food", "InventoryItem"],
    "fish":        ["Food", "InventoryItem"],
    "sourceItem":  ["InventoryItem"],
    "weapon":      ["HandWeapon", "InventoryItem"],
    "primary":     ["HandWeapon", "InventoryItem"],
    "secondary":   ["HandWeapon", "InventoryItem"],
    # wornItem is WornItem (singular — the element type from wornItems:get(i))
    "wornItem":    ["WornItem"],

    # Body parts
    "part":        ["BodyPart"],
    "armL":        ["BodyPart"],
    "armR":        ["BodyPart"],
    "head":        ["BodyPart"],
    "torsoLower":  ["BodyPart"],

    # Collections (Java ArrayList/list returns)
    "items":       ["__java_list"],
    "parts":       ["__java_list"],
    "spottedList": ["__java_list"],
    "mutexList":   ["__java_list"],
    "backpacks":   ["__java_list"],

    # Vehicle
    "vehicle":     ["BaseVehicle"],

    # Square/environment
    "square":      ["IsoGridSquare"],
    "sq":          ["IsoGridSquare"],

    # Climate
    "cm":          ["ClimateManager"],
    "gt":          ["GameTime"],
    "gti":         ["GameTime"],

    # Zombie
    "zombie":      ["IsoZombie", "IsoGameCharacter"],

    # Lua-side PZ classes (override targets)
    "ISEatFoodAction":   ["__lua:ISEatFoodAction"],
    "ISDrinkFluidAction": ["__lua:ISDrinkFluidAction"],
    "ISFitnessAction":   ["__lua:ISFitnessAction"],

    # Worn items container
    "pack":        ["ItemContainer"],

    # WornItems (from player:getWornItems())
    "wornItems":   ["WornItems"],

    # Generic moddata/misc - skip verification
    "obj":         ["__skip"],
    "md":          ["__skip"],
    "key":         ["__skip"],   # string methods
    "wtype":       ["__skip"],   # string methods
    "action":      ["__skip"],
    "actionName":  ["__skip"],
    "actionType":  ["__skip"],
    "cats":        ["__skip"],
    "trait":       ["__skip"],   # trait definition
    "traitDefinition": ["__skip"],
    "CharacterCreationProfession": ["__skip"],
    "ENDURANCE":   ["CharacterStat"],
}

# Methods that are Lua built-ins or PZ global utilities, not class methods
KNOWN_SAFE_METHODS = {
    # Java list methods (ArrayList exposed to Lua)
    "__java_list": {"get", "size", "contains", "add", "remove", "getItemByIndex"},
    # Lua string methods
    "__string": {"find", "sub", "match", "gmatch", "format", "len", "upper", "lower"},
}

# CharacterStat field/method names (accessed as CharacterStat.PANIC:getMaximumValue etc)
CHARACTERSTAT_METHODS = {
    "getMaximumValue", "getMinimumValue", "getDefaultValue", "clamp",
}

# ============================================================
# DATA CLASSES
# ============================================================

@dataclass
class MethodCall:
    """A single method call found in mod source code."""
    file: str
    line_num: int
    receiver: str
    method: str
    arg_count: int
    line_text: str


@dataclass
class JavaMethod:
    """A public method found in a Java class file."""
    name: str
    param_count: int
    return_type: str
    file: str
    line_num: int
    is_static: bool = False


@dataclass
class LuaMethod:
    """A method defined in a PZ Lua source file."""
    name: str
    param_count: int
    file: str
    line_num: int


@dataclass
class VerifyResult:
    """Result of verifying a single method call."""
    status: str  # "OK", "WARN", "FAIL"
    call: MethodCall
    matched_class: Optional[str] = None
    matched_method: Optional[str] = None
    detail: str = ""


# ============================================================
# JAVA METHOD EXTRACTION
# ============================================================

# Regex for public method declarations in decompiled Java
# Handles: public Type methodName(params) {
# Also: public static Type methodName(params)
# Also: public final Type methodName(params)
JAVA_METHOD_RE = re.compile(
    r'^\s+public\s+'
    r'(?:(?:static|final|synchronized|abstract|native)\s+)*'
    r'(\S+)\s+'           # return type
    r'(\w+)\s*'           # method name
    r'\(([^)]*)\)',        # parameters
    re.MULTILINE
)

# Also match constructors
JAVA_CONSTRUCTOR_RE = re.compile(
    r'^\s+public\s+(\w+)\s*\(([^)]*)\)',
    re.MULTILINE
)


def extract_java_methods(filepath: Path) -> list[JavaMethod]:
    """Extract all public methods from a Java source file."""
    if not filepath.exists():
        return []

    text = filepath.read_text(encoding="utf-8", errors="replace")
    methods = []

    for m in JAVA_METHOD_RE.finditer(text):
        return_type = m.group(1)
        name = m.group(2)
        params = m.group(3).strip()
        param_count = 0 if not params else len(params.split(","))
        line_num = text[:m.start()].count("\n") + 1
        is_static = "static" in m.group(0)
        methods.append(JavaMethod(
            name=name,
            param_count=param_count,
            return_type=return_type,
            file=str(filepath),
            line_num=line_num,
            is_static=is_static,
        ))

    return methods


def build_java_api_index() -> dict[str, dict[str, list[JavaMethod]]]:
    """
    Build index: class_name → {method_name → [JavaMethod, ...]}.
    Multiple entries per method name handle overloads.
    """
    index = {}
    for class_name, rel_path in JAVA_CLASS_FILES.items():
        filepath = PZ_JAVA_ROOT / rel_path
        if not filepath.exists():
            print(f"  WARNING: Java class file not found: {filepath}", file=sys.stderr)
            continue
        methods = extract_java_methods(filepath)
        method_map = defaultdict(list)
        for m in methods:
            method_map[m.name].append(m)
        index[class_name] = dict(method_map)
    return index


# ============================================================
# LUA METHOD EXTRACTION (PZ Lua source)
# ============================================================

# Matches: function ClassName:methodName(params)
LUA_METHOD_RE = re.compile(
    r'^\s*function\s+(\w+):(\w+)\s*\(([^)]*)\)',
    re.MULTILINE
)

# Matches: function ClassName.methodName(params) (static-style)
LUA_STATIC_RE = re.compile(
    r'^\s*function\s+(\w+)\.(\w+)\s*\(([^)]*)\)',
    re.MULTILINE
)


def extract_lua_methods(filepath: Path) -> dict[str, list[LuaMethod]]:
    """Extract methods from a PZ Lua source file."""
    if not filepath.exists():
        return {}

    text = filepath.read_text(encoding="utf-8", errors="replace")
    methods = defaultdict(list)

    for m in LUA_METHOD_RE.finditer(text):
        class_name = m.group(1)
        method_name = m.group(2)
        params = m.group(3).strip()
        # In Lua instance methods, 'self' is implicit, so don't count it
        param_count = 0 if not params else len([p for p in params.split(",") if p.strip() != "self"])
        line_num = text[:m.start()].count("\n") + 1
        methods[class_name].append(LuaMethod(
            name=method_name,
            param_count=param_count,
            file=str(filepath),
            line_num=line_num,
        ))

    for m in LUA_STATIC_RE.finditer(text):
        class_name = m.group(1)
        method_name = m.group(2)
        params = m.group(3).strip()
        param_count = 0 if not params else len(params.split(","))
        line_num = text[:m.start()].count("\n") + 1
        methods[class_name].append(LuaMethod(
            name=method_name,
            param_count=param_count,
            file=str(filepath),
            line_num=line_num,
        ))

    return dict(methods)


def build_lua_api_index() -> dict[str, dict[str, list[LuaMethod]]]:
    """Build index: class_name → {method_name → [LuaMethod, ...]}."""
    index = {}
    for class_name, rel_path in PZ_LUA_FILES.items():
        if rel_path is None:
            continue
        filepath = PZ_LUA_ROOT / rel_path
        if not filepath.exists():
            print(f"  WARNING: PZ Lua file not found: {filepath}", file=sys.stderr)
            continue
        file_methods = extract_lua_methods(filepath)
        if class_name in file_methods:
            method_map = defaultdict(list)
            for m in file_methods[class_name]:
                method_map[m.name].append(m)
            index[class_name] = dict(method_map)
    return index


# ============================================================
# MOD LUA CALL EXTRACTION
# ============================================================

# Match: receiver:method(args)
# Captures receiver, method, and everything inside parens (for arg counting)
MOD_CALL_RE = re.compile(
    r'(\w+):(\w+)\s*\('
)


def count_args_from_position(line: str, paren_start: int) -> int:
    """Count arguments by tracking parentheses depth from the opening paren.
    
    Returns -1 if the call spans multiple lines (closing paren not found on
    this line) — callers should skip arg-count checks in that case.
    """
    depth = 1
    i = paren_start + 1
    arg_count = 0
    has_content = False

    while i < len(line) and depth > 0:
        ch = line[i]
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                break
        elif ch == ',' and depth == 1:
            arg_count += 1
        elif ch == '"' or ch == "'":
            # Skip string literals
            quote = ch
            i += 1
            while i < len(line) and line[i] != quote:
                if line[i] == '\\':
                    i += 1
                i += 1
        if ch not in (' ', '\t', '\n', '\r'):
            has_content = True
        i += 1

    if has_content:
        arg_count += 1  # last arg (no trailing comma)

    # If depth > 0, the closing paren was never found on this line (multiline call)
    if depth > 0:
        return -1
    return arg_count


def extract_mod_calls(filepath: Path) -> list[MethodCall]:
    """Extract all object:method() calls from a mod Lua file."""
    calls = []
    text = filepath.read_text(encoding="utf-8", errors="replace")

    for line_num, line in enumerate(text.splitlines(), 1):
        # Skip comments
        stripped = line.strip()
        if stripped.startswith("--"):
            continue
        # Remove inline comments
        comment_pos = line.find("--")
        if comment_pos >= 0:
            line_clean = line[:comment_pos]
        else:
            line_clean = line

        for m in MOD_CALL_RE.finditer(line_clean):
            receiver = m.group(1)
            method = m.group(2)
            paren_pos = m.end() - 1  # position of '('
            arg_count = count_args_from_position(line_clean, paren_pos)

            calls.append(MethodCall(
                file=str(filepath),
                line_num=line_num,
                receiver=receiver,
                method=method,
                arg_count=arg_count,
                line_text=stripped,
            ))

    return calls


def scan_all_mod_calls() -> list[MethodCall]:
    """Scan all mod Lua files for API calls."""
    all_calls = []
    for lua_dir in MOD_LUA_DIRS:
        if not lua_dir.exists():
            print(f"  WARNING: Mod Lua dir not found: {lua_dir}", file=sys.stderr)
            continue
        for lua_file in sorted(lua_dir.rglob("*.lua")):
            all_calls.extend(extract_mod_calls(lua_file))
    return all_calls


# ============================================================
# VERIFICATION ENGINE
# ============================================================

def verify_call(
    call: MethodCall,
    java_index: dict[str, dict[str, list[JavaMethod]]],
    lua_index: dict[str, dict[str, list[LuaMethod]]],
) -> VerifyResult:
    """Verify a single method call against the PZ codebase."""

    receiver = call.receiver
    method = call.method

    # Look up receiver mapping
    class_candidates = RECEIVER_MAP.get(receiver)

    if class_candidates is None:
        # Unknown receiver — could be a local variable, skip with note
        return VerifyResult(
            status="SKIP",
            call=call,
            detail=f"Unknown receiver '{receiver}' — not in RECEIVER_MAP",
        )

    # Check for skip markers
    if class_candidates == ["__skip"]:
        return VerifyResult(
            status="SKIP",
            call=call,
            detail=f"Receiver '{receiver}' is marked as skip (non-PZ-API)",
        )

    # Check Java list methods
    if class_candidates == ["__java_list"]:
        if method in KNOWN_SAFE_METHODS.get("__java_list", set()):
            return VerifyResult(
                status="OK",
                call=call,
                matched_class="java.util.ArrayList",
                matched_method=method,
                detail="Java collection method",
            )
        else:
            return VerifyResult(
                status="WARN",
                call=call,
                detail=f"Unknown Java list method '{method}'",
            )

    # Try each candidate class
    for class_name in class_candidates:
        # Check Lua-side classes
        if class_name.startswith("__lua:"):
            lua_class = class_name[6:]
            if lua_class in lua_index:
                lua_methods = lua_index[lua_class]
                if method in lua_methods:
                    lua_m = lua_methods[method][0]
                    return VerifyResult(
                        status="OK",
                        call=call,
                        matched_class=lua_class,
                        matched_method=method,
                        detail=f"PZ Lua method (L{lua_m.line_num} in {Path(lua_m.file).name})",
                    )
            continue

        # Check Java class
        if class_name not in java_index:
            continue

        java_methods = java_index[class_name]
        if method in java_methods:
            overloads = java_methods[method]
            # If arg_count == -1 the call spans multiple lines; skip arg check
            if call.arg_count == -1:
                return VerifyResult(
                    status="OK",
                    call=call,
                    matched_class=class_name,
                    matched_method=method,
                    detail=f"Method exists (multiline call — arg count not checked)",
                )
            # Check if any overload matches our arg count
            matching = [m for m in overloads if m.param_count == call.arg_count]
            any_overload = overloads[0]

            if matching:
                return VerifyResult(
                    status="OK",
                    call=call,
                    matched_class=class_name,
                    matched_method=method,
                    detail=f"Exact match ({any_overload.return_type}, {len(overloads)} overload(s))",
                )
            else:
                # Method exists but arg count doesn't match any overload
                expected = sorted(set(m.param_count for m in overloads))
                return VerifyResult(
                    status="WARN",
                    call=call,
                    matched_class=class_name,
                    matched_method=method,
                    detail=f"Arg count mismatch: mod passes {call.arg_count}, Java expects {expected}",
                )

    # Method not found in any candidate class
    searched = [c for c in class_candidates if not c.startswith("__")]
    return VerifyResult(
        status="FAIL",
        call=call,
        detail=f"Method '{method}' NOT FOUND in: {', '.join(searched)}",
    )


# ============================================================
# INHERITANCE RESOLUTION
# ============================================================

# Java inheritance chain (child → parents)
# When a method isn't found on a child class, we search parent classes.
JAVA_INHERITANCE = {
    "IsoPlayer": ["IsoGameCharacter", "IsoLivingCharacter", "IsoMovingObject", "IsoObject"],
    "IsoGameCharacter": ["IsoLivingCharacter", "IsoMovingObject", "IsoObject"],
    "IsoLivingCharacter": ["IsoMovingObject", "IsoObject"],
    "IsoZombie": ["IsoGameCharacter", "IsoLivingCharacter", "IsoMovingObject", "IsoObject"],
    "IsoMovingObject": ["IsoObject"],
    "Food": ["InventoryItem"],
    "HandWeapon": ["InventoryItem"],
    "Clothing": ["InventoryItem"],
    "Literature": ["InventoryItem"],
    "BaseVehicle": ["IsoMovingObject", "IsoObject"],
    # WornItem and WornItems are standalone (not in InventoryItem hierarchy)
    "WornItem": [],
    "WornItems": [],
}


def resolve_java_index_with_inheritance(
    raw_index: dict[str, dict[str, list[JavaMethod]]]
) -> dict[str, dict[str, list[JavaMethod]]]:
    """
    Build a resolved index where each class includes inherited methods.
    """
    resolved = {}
    for class_name, methods in raw_index.items():
        merged = dict(methods)  # start with own methods
        parents = JAVA_INHERITANCE.get(class_name, [])
        for parent in parents:
            if parent in raw_index:
                for mn, ml in raw_index[parent].items():
                    if mn not in merged:
                        merged[mn] = ml
        resolved[class_name] = merged
    return resolved


# ============================================================
# SCRIPT TRAIT VERIFICATION (XPBoosts perk names)
# ============================================================

def extract_perk_names_from_java(codebase_root: Path) -> set[str]:
    """Extract valid Perk enum names from PZ Java source (PerkFactory.Perks)."""
    perks = set()

    perks_file = codebase_root / "Java" / "source" / "zombie" / "characters" / "skills" / "PerkFactory.java"
    if not perks_file.exists():
        print(f"  WARNING: PerkFactory.java not found", file=sys.stderr)
        return perks

    text = perks_file.read_text(encoding="utf-8", errors="replace")

    # Match: public static final PerkFactory.Perk NAME = new PerkFactory.Perk("NAME");
    # or:   public static final Perk NAME = ...
    for m in re.finditer(
        r'public\s+static\s+final\s+(?:PerkFactory\.)?Perk\s+(\w+)\s*=',
        text
    ):
        name = m.group(1)
        # Skip meta-entries
        if name not in ("None", "MAX"):
            perks.add(name)

    return perks


def verify_xpboosts(
    script_file: Path,
    valid_perks: set[str],
) -> list[VerifyResult]:
    """Verify all Perk names in XPBoosts entries of UT script file."""
    results = []
    if not script_file.exists():
        return results

    text = script_file.read_text(encoding="utf-8", errors="replace")
    for line_num, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("XPBoosts"):
            continue
        # Parse: XPBoosts = PerkName=N;PerkName=N;
        eq_pos = stripped.find("=")
        if eq_pos < 0:
            continue
        boosts_str = stripped[eq_pos + 1:].strip().rstrip(",")
        for entry in boosts_str.split(";"):
            entry = entry.strip()
            if not entry or "=" not in entry:
                continue
            perk_name = entry.split("=")[0].strip()
            if perk_name in valid_perks:
                results.append(VerifyResult(
                    status="OK",
                    call=MethodCall(
                        file=str(script_file),
                        line_num=line_num,
                        receiver="XPBoosts",
                        method=perk_name,
                        arg_count=0,
                        line_text=stripped,
                    ),
                    matched_class="Perks",
                    matched_method=perk_name,
                    detail="Valid perk name",
                ))
            else:
                results.append(VerifyResult(
                    status="FAIL",
                    call=MethodCall(
                        file=str(script_file),
                        line_num=line_num,
                        receiver="XPBoosts",
                        method=perk_name,
                        arg_count=0,
                        line_text=stripped,
                    ),
                    detail=f"Perk name '{perk_name}' NOT FOUND in Perks.java",
                ))

    return results


# ============================================================
# MAIN
# ============================================================

def make_relative(filepath: str) -> str:
    """Make a path relative to UTMODS_ROOT for display."""
    try:
        return str(Path(filepath).relative_to(UTMODS_ROOT))
    except ValueError:
        return filepath


def normalize_rel_path(filepath: str) -> str:
    """Make a path relative to UTMODS_ROOT using forward slashes."""
    return make_relative(filepath).replace("\\", "/")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify UT mod API usage against the decompiled PZ codebase."
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Show extra output")
    parser.add_argument("--json", dest="json_output", action="store_true", help="Emit machine-readable summary JSON")
    parser.add_argument(
        "--inventory-json",
        action="store_true",
        help="Include the full machine-readable inventory payload in JSON output",
    )
    parser.add_argument(
        "--inventory-out",
        type=Path,
        help="Write the full machine-readable inventory payload to a JSON file",
    )
    parser.add_argument(
        "--baseline-file",
        type=Path,
        default=DEFAULT_BASELINE_FILE,
        help=f"Baseline snapshot path (default: {DEFAULT_BASELINE_FILE})",
    )
    parser.add_argument(
        "--compare-baseline",
        action="store_true",
        help="Compare the current inventory against the stored baseline snapshot",
    )
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="Write the current green inventory as the baseline snapshot",
    )
    args = parser.parse_args()
    if args.inventory_json and not args.json_output:
        parser.error("--inventory-json requires --json")
    return args


def load_pzcodebase_metadata() -> dict:
    version_file = PZ_CODEBASE / "VERSION.json"
    if not version_file.exists():
        return {}
    try:
        return json.loads(version_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def classify_owner(rel_path: str) -> dict:
    path = Path(rel_path)
    stem = path.stem

    if rel_path.startswith("UT_CORE/media/lua/shared/UTCore/"):
        return {"kind": "ut_core_module", "id": stem, "file": rel_path}
    if rel_path.startswith("UniversalTraits/media/lua/shared/UniversalTraits/traits/"):
        return {"kind": "trait", "id": stem, "file": rel_path}
    if rel_path == "UniversalTraits/media/registries.lua":
        return {"kind": "registration", "id": "registries", "file": rel_path}
    if rel_path == "UniversalTraits/media/scripts/UT_character_traits.txt":
        return {"kind": "script_definition", "id": "UT_character_traits", "file": rel_path}
    if rel_path.endswith("/UT_MET.lua"):
        return {"kind": "runtime_support", "id": "UT_MET", "file": rel_path}
    if rel_path.startswith("UniversalTraits/media/lua/shared/UniversalTraits/"):
        return {"kind": "runtime_support", "id": stem, "file": rel_path}
    return {"kind": "source_file", "id": stem, "file": rel_path}


def infer_surface_name(result: VerifyResult) -> Optional[str]:
    if result.matched_class:
        return result.matched_class

    candidates = RECEIVER_MAP.get(result.call.receiver, [])
    for candidate in candidates:
        if not candidate.startswith("__"):
            return candidate
    return None


def build_inventory_entry(result: VerifyResult) -> dict:
    rel_file = normalize_rel_path(result.call.file)
    owner = classify_owner(rel_file)
    verification_source = "script_xpboosts" if result.call.receiver == "XPBoosts" else "pz_api_scan"
    verification_kind = "script_xpboosts" if result.call.receiver == "XPBoosts" else "method_call"

    return {
        "id": f"{rel_file}:{result.call.line_num}:{result.call.receiver}:{result.call.method}",
        "relative_file": rel_file,
        "line": result.call.line_num,
        "receiver": result.call.receiver,
        "method": result.call.method,
        "arg_count": result.call.arg_count,
        "status": result.status,
        "matched_class": result.matched_class,
        "surface_name": infer_surface_name(result),
        "matched_method": result.matched_method,
        "detail": result.detail,
        "line_text": result.call.line_text,
        "owner": owner,
        "verification_source": verification_source,
        "verification_kind": verification_kind,
    }


def build_inventory(results: list[VerifyResult], pz_metadata: dict) -> dict:
    call_sites = [build_inventory_entry(result) for result in results]

    unique_surfaces = {}
    for entry in call_sites:
        key = (
            entry.get("surface_name") or entry["receiver"],
            entry["method"],
            entry["verification_kind"],
        )
        aggregate = unique_surfaces.setdefault(
            key,
            {
                "surface_name": entry.get("surface_name"),
                "receiver": entry["receiver"],
                "method": entry["method"],
                "verification_kind": entry["verification_kind"],
                "statuses": set(),
                "owners": set(),
                "files": set(),
                "occurrence_count": 0,
            },
        )
        aggregate["statuses"].add(entry["status"])
        aggregate["owners"].add(f"{entry['owner']['kind']}:{entry['owner']['id']}")
        aggregate["files"].add(entry["relative_file"])
        aggregate["occurrence_count"] += 1

    unique_surface_list = []
    for aggregate in unique_surfaces.values():
        unique_surface_list.append(
            {
                "surface_name": aggregate["surface_name"],
                "receiver": aggregate["receiver"],
                "method": aggregate["method"],
                "verification_kind": aggregate["verification_kind"],
                "statuses": sorted(aggregate["statuses"]),
                "owners": sorted(aggregate["owners"]),
                "files": sorted(aggregate["files"]),
                "occurrence_count": aggregate["occurrence_count"],
            }
        )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pzc_version": pz_metadata.get("game_build"),
        "pzc_decompiled_at": pz_metadata.get("decompiled_at"),
        "summary": {
            "call_sites": len(call_sites),
            "unique_surfaces": len(unique_surface_list),
            "ok": sum(1 for entry in call_sites if entry["status"] == "OK"),
            "warn": sum(1 for entry in call_sites if entry["status"] == "WARN"),
            "fail": sum(1 for entry in call_sites if entry["status"] == "FAIL"),
            "skip": sum(1 for entry in call_sites if entry["status"] == "SKIP"),
        },
        "call_sites": call_sites,
        "unique_surfaces": sorted(unique_surface_list, key=lambda item: (item["surface_name"] or item["receiver"], item["method"])),
    }


def write_inventory(path: Path, inventory: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(inventory, indent=2), encoding="utf-8")


def build_baseline_snapshot(inventory: dict, pz_metadata: dict) -> dict:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pzc_version": pz_metadata.get("game_build"),
        "pzc_decompiled_at": pz_metadata.get("decompiled_at"),
        "pzc_layer_hashes": pz_metadata.get("layer_hashes") or {},
        "summary": inventory.get("summary", {}),
        "unique_surfaces": inventory.get("unique_surfaces", []),
    }


def write_baseline(path: Path, baseline: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(baseline, indent=2), encoding="utf-8")


def load_baseline(path: Path) -> Optional[dict]:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def surface_key(surface: dict) -> tuple[str, str, str]:
    return (
        surface.get("surface_name") or surface["receiver"],
        surface["method"],
        surface["verification_kind"],
    )


def simplify_surface(surface: dict) -> dict:
    return {
        "surface_name": surface.get("surface_name"),
        "receiver": surface["receiver"],
        "method": surface["method"],
        "verification_kind": surface["verification_kind"],
        "statuses": surface.get("statuses", []),
        "owners": surface.get("owners", []),
        "files": surface.get("files", []),
    }


def compare_to_baseline(inventory: dict, pz_metadata: dict, baseline: Optional[dict]) -> dict:
    current_hashes = pz_metadata.get("layer_hashes") or {}

    if baseline is None:
        return {
            "status": "baseline_missing",
            "baseline_file_present": False,
            "pz_shape_changed": False,
            "new_breakages": [],
            "removed_breakages": [],
            "new_surfaces": [],
            "removed_surfaces": [],
            "status_changes": [],
        }

    baseline_surfaces = {surface_key(surface): surface for surface in baseline.get("unique_surfaces", [])}
    current_surfaces = {surface_key(surface): surface for surface in inventory.get("unique_surfaces", [])}

    new_keys = sorted(current_surfaces.keys() - baseline_surfaces.keys())
    removed_keys = sorted(baseline_surfaces.keys() - current_surfaces.keys())

    status_changes = []
    for key in sorted(current_surfaces.keys() & baseline_surfaces.keys()):
        current = current_surfaces[key]
        previous = baseline_surfaces[key]
        if sorted(current.get("statuses", [])) != sorted(previous.get("statuses", [])):
            status_changes.append({
                "key": key,
                "before": previous.get("statuses", []),
                "after": current.get("statuses", []),
                "surface": simplify_surface(current),
            })

    def breakage_keys(surface_map: dict) -> set[tuple[str, str, str]]:
        return {
            key
            for key, surface in surface_map.items()
            if "FAIL" in surface.get("statuses", []) or "WARN" in surface.get("statuses", [])
        }

    current_breakages = breakage_keys(current_surfaces)
    baseline_breakages = breakage_keys(baseline_surfaces)

    new_breakages = sorted(current_breakages - baseline_breakages)
    removed_breakages = sorted(baseline_breakages - current_breakages)
    pz_shape_changed = (baseline.get("pzc_layer_hashes") or {}) != current_hashes

    if new_breakages:
        status = "tracked_api_breakage"
    elif not pz_shape_changed and not new_keys and not removed_keys and not status_changes:
        status = "no_game_shape_change"
    elif pz_shape_changed and not new_keys and not removed_keys and not status_changes:
        status = "shape_change_no_mod_exposure"
    elif not pz_shape_changed:
        status = "mod_surface_change"
    else:
        status = "shape_change_with_mod_surface_change"

    return {
        "status": status,
        "baseline_file_present": True,
        "pz_shape_changed": pz_shape_changed,
        "baseline_pzc_version": baseline.get("pzc_version"),
        "current_pzc_version": pz_metadata.get("game_build"),
        "new_breakages": [simplify_surface(current_surfaces[key]) for key in new_breakages],
        "removed_breakages": [simplify_surface(baseline_surfaces[key]) for key in removed_breakages],
        "new_surfaces": [simplify_surface(current_surfaces[key]) for key in new_keys],
        "removed_surfaces": [simplify_surface(baseline_surfaces[key]) for key in removed_keys],
        "status_changes": status_changes,
    }


def main():
    args = parse_args()
    verbose = args.verbose
    json_output = args.json_output

    if not json_output:
        print("=" * 70)
        print("PZ API Surface Verifier")
        print("=" * 70)
        print(f"PZ Codebase:  {PZ_CODEBASE}")
        print(f"Mod Root:     {UTMODS_ROOT}")
        print()

    # Validate paths
    if not PZ_CODEBASE.exists():
        print(f"FATAL: PZ codebase not found at {PZ_CODEBASE}", file=sys.stderr)
        sys.exit(2)

    pz_metadata = load_pzcodebase_metadata()

    # Phase 1: Build Java API index
    if not json_output:
        print("Phase 1: Indexing Java API methods...")
    raw_java_index = build_java_api_index()
    java_index = resolve_java_index_with_inheritance(raw_java_index)
    total_java = sum(len(v) for v in java_index.values())
    if not json_output:
        for cn, methods in sorted(java_index.items()):
            own = len(raw_java_index.get(cn, {}))
            inherited = len(methods) - own
            print(f"  {cn}: {own} own + {inherited} inherited = {len(methods)} methods")
        print(f"  Total: {total_java} methods across {len(java_index)} classes")
        print()

    # Phase 2: Build Lua API index
    if not json_output:
        print("Phase 2: Indexing PZ Lua API methods...")
    lua_index = build_lua_api_index()
    for cn, methods in sorted(lua_index.items()):
        if not json_output:
            print(f"  {cn}: {len(methods)} methods")
    if not json_output:
        print()

    # Phase 3: Scan mod source calls
    if not json_output:
        print("Phase 3: Scanning mod Lua files for API calls...")
    all_calls = scan_all_mod_calls()
    if not json_output:
        print(f"  Found {len(all_calls)} method calls across mod files")
        print()

    # Phase 4: Verify each call
    if not json_output:
        print("Phase 4: Verifying calls against PZ codebase...")
        print()

    results = []
    for call in all_calls:
        result = verify_call(call, java_index, lua_index)
        results.append(result)

    # Phase 5: Verify XPBoosts perk names
    if not json_output:
        print("Phase 5: Verifying XPBoosts perk names...")
    valid_perks = extract_perk_names_from_java(PZ_CODEBASE)
    script_file = UTMODS_ROOT / "UniversalTraits" / "media" / "scripts" / "UT_character_traits.txt"
    xp_results = verify_xpboosts(script_file, valid_perks)
    results.extend(xp_results)

    inventory = build_inventory(results, pz_metadata)

    baseline_result = None
    if args.compare_baseline:
        try:
            baseline = load_baseline(args.baseline_file)
        except json.JSONDecodeError as exc:
            print(f"FATAL: invalid baseline JSON: {exc}", file=sys.stderr)
            sys.exit(2)
        baseline_result = compare_to_baseline(inventory, pz_metadata, baseline)

    if args.inventory_out:
        write_inventory(args.inventory_out, inventory)

    # Deduplicate: same (receiver, method, status) only needs one report
    seen_keys = set()
    unique_results = []
    for r in results:
        key = (r.call.receiver, r.call.method, r.status)
        if key not in seen_keys:
            seen_keys.add(key)
            unique_results.append(r)

    # Categorize
    fails = [r for r in unique_results if r.status == "FAIL"]
    warns = [r for r in unique_results if r.status == "WARN"]
    oks = [r for r in unique_results if r.status == "OK"]
    skips = [r for r in unique_results if r.status == "SKIP"]

    # JSON output
    if args.write_baseline:
        if fails:
            print("FATAL: refusing to write baseline with FAIL results", file=sys.stderr)
            sys.exit(2)
        write_baseline(args.baseline_file, build_baseline_snapshot(inventory, pz_metadata))

    if json_output:
        output = {
            "summary": {
                "total_calls": len(all_calls),
                "unique_apis": len(unique_results),
                "ok": len(oks),
                "warn": len(warns),
                "fail": len(fails),
                "skip": len(skips),
            },
            "fails": [
                {
                    "receiver": r.call.receiver,
                    "method": r.call.method,
                    "file": normalize_rel_path(r.call.file),
                    "line": r.call.line_num,
                    "detail": r.detail,
                }
                for r in fails
            ],
            "warns": [
                {
                    "receiver": r.call.receiver,
                    "method": r.call.method,
                    "file": normalize_rel_path(r.call.file),
                    "line": r.call.line_num,
                    "detail": r.detail,
                    "matched_class": r.matched_class,
                }
                for r in warns
            ],
            "skips": [
                {
                    "receiver": r.call.receiver,
                    "method": r.call.method,
                    "file": normalize_rel_path(r.call.file),
                    "line": r.call.line_num,
                    "detail": r.detail,
                }
                for r in skips
            ],
        }
        if baseline_result is not None:
            output["baseline"] = baseline_result
        if args.inventory_json:
            output["inventory"] = inventory
        print(json.dumps(output, indent=2))
        should_fail = bool(fails)
        if args.compare_baseline and baseline_result and baseline_result["status"] in {"baseline_missing", "tracked_api_breakage"}:
            should_fail = True
        sys.exit(1 if should_fail else 0)

    # Text output
    if fails:
        print()
        print("=" * 70)
        print(f"FAILURES ({len(fails)}) — These methods DO NOT EXIST in the PZ codebase")
        print("=" * 70)
        for r in sorted(fails, key=lambda x: (x.call.receiver, x.call.method)):
            rel = make_relative(r.call.file)
            print(f"  FAIL  {r.call.receiver}:{r.call.method}()")
            print(f"        {rel}:{r.call.line_num}")
            print(f"        {r.detail}")
            if verbose:
                print(f"        Line: {r.call.line_text}")
            print()

    if warns:
        print()
        print("=" * 70)
        print(f"WARNINGS ({len(warns)}) — Methods exist but signature may differ")
        print("=" * 70)
        for r in sorted(warns, key=lambda x: (x.call.receiver, x.call.method)):
            rel = make_relative(r.call.file)
            print(f"  WARN  {r.call.receiver}:{r.call.method}()  [{r.matched_class}]")
            print(f"        {rel}:{r.call.line_num}")
            print(f"        {r.detail}")
            if verbose:
                print(f"        Line: {r.call.line_text}")
            print()

    if baseline_result is not None:
        print()
        print("=" * 70)
        print("UPDATE IMPACT")
        print("=" * 70)
        print(f"  Classification:             {baseline_result['status']}")
        print(f"  PZ shape changed:           {baseline_result['pz_shape_changed']}")
        print(f"  New breakages:              {len(baseline_result['new_breakages'])}")
        print(f"  Removed breakages:          {len(baseline_result['removed_breakages'])}")
        print(f"  New surfaces:               {len(baseline_result['new_surfaces'])}")
        print(f"  Removed surfaces:           {len(baseline_result['removed_surfaces'])}")
        print(f"  Status changes:             {len(baseline_result['status_changes'])}")
        if baseline_result["status"] == "baseline_missing":
            print(f"  Baseline file:              {args.baseline_file} (missing)")
        elif baseline_result["new_breakages"]:
            print("  First new breakage:")
            first = baseline_result["new_breakages"][0]
            print(f"    {first['receiver']}:{first['method']} statuses={','.join(first['statuses'])}")

    if verbose and oks:
        print()
        print(f"OK ({len(oks)}) — Verified successfully")
        print("-" * 40)
        for r in sorted(oks, key=lambda x: (x.call.receiver, x.call.method)):
            print(f"  OK    {r.call.receiver}:{r.call.method}()  [{r.matched_class}]")

    # Summary
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"  Total method calls found:  {len(all_calls)}")
    print(f"  Unique API patterns:       {len(unique_results)}")
    print(f"  OK (verified):             {len(oks)}")
    print(f"  WARN (signature diff):     {len(warns)}")
    print(f"  FAIL (missing method):     {len(fails)}")
    print(f"  SKIP (non-PZ receiver):    {len(skips)}")
    if args.inventory_out:
        print(f"  Inventory file:            {args.inventory_out}")
    print()

    if fails:
        print(f"EXIT CODE: 1 -- {len(fails)} FAILURES require attention")
        sys.exit(1)
    elif args.compare_baseline and baseline_result and baseline_result["status"] == "baseline_missing":
        print("EXIT CODE: 1 -- baseline snapshot is missing")
        sys.exit(1)
    elif args.compare_baseline and baseline_result and baseline_result["status"] == "tracked_api_breakage":
        print("EXIT CODE: 1 -- new API breakages relative to baseline")
        sys.exit(1)
    elif warns:
        print(f"EXIT CODE: 0 -- {len(warns)} warnings (review recommended)")
        sys.exit(0)
    else:
        print("EXIT CODE: 0 -- All API calls verified against PZ codebase")
        sys.exit(0)


if __name__ == "__main__":
    main()
