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
    python tools/verify_pz_api.py --json  # machine-readable output
"""

import os
import re
import json
import sys
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from typing import Optional

# ============================================================
# CONFIGURATION
# ============================================================

SCRIPT_DIR = Path(__file__).resolve().parent
UTMODS_ROOT = SCRIPT_DIR.parent
PZ_CODEBASE = UTMODS_ROOT.parent / "PZCodebase"
PZ_JAVA_ROOT = PZ_CODEBASE / "Java" / "source"
PZ_LUA_ROOT = PZ_CODEBASE / "Lua"

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

    # Item hierarchy
    "item":        ["Literature", "InventoryItem", "Food", "HandWeapon", "Clothing"],
    "food":        ["Food", "InventoryItem"],
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

    # Vehicle
    "vehicle":     ["BaseVehicle"],

    # Square/environment
    "square":      ["IsoGridSquare"],
    "sq":          ["IsoGridSquare"],

    # Climate
    "cm":          ["ClimateManager"],

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
    "gt":          ["__skip"],   # trait object
    "trait":       ["__skip"],   # trait definition
    "traitDefinition": ["__skip"],
    "CharacterCreationProfession": ["__skip"],
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


def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    json_output = "--json" in sys.argv

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
                    "file": make_relative(r.call.file),
                    "line": r.call.line_num,
                    "detail": r.detail,
                }
                for r in fails
            ],
            "warns": [
                {
                    "receiver": r.call.receiver,
                    "method": r.call.method,
                    "file": make_relative(r.call.file),
                    "line": r.call.line_num,
                    "detail": r.detail,
                    "matched_class": r.matched_class,
                }
                for r in warns
            ],
        }
        print(json.dumps(output, indent=2))
        sys.exit(1 if fails else 0)

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
    print()

    if fails:
        print(f"EXIT CODE: 1 -- {len(fails)} FAILURES require attention")
        sys.exit(1)
    elif warns:
        print(f"EXIT CODE: 0 -- {len(warns)} warnings (review recommended)")
        sys.exit(0)
    else:
        print("EXIT CODE: 0 -- All API calls verified against PZ codebase")
        sys.exit(0)


if __name__ == "__main__":
    main()
