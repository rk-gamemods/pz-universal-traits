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
import hashlib
import re
import json
import sys
from datetime import date, datetime, timezone
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
DEFAULT_ALLOWLIST_FILE = SCRIPT_DIR / "pz_api_allowlist.json"
CONTRACT_SCHEMA_VERSION = 1
MAX_REPORT_ISSUES = 100
EXIT_OK = 0
EXIT_BLOCKED = 1
EXIT_INTERNAL_ERROR = 2
KNOWN_STATUSES = {"OK", "WARN", "FAIL", "SKIP", "BLOCK"}
WAIVABLE_CATEGORIES = {"warn", "fail", "skip"}
FOUNDATIONAL_CATEGORIES = {
    "allowlist-shape", "baseline-missing", "baseline-shape", "inventory-shape",
    "inventory-stale", "required-input-missing", "source-integrity",
    "unknown-status", "verifier-defect", "version-hash-mismatch",
}
ALLOWLIST_ROOT_FIELDS = {"schema_version", "exceptions"}
ALLOWLIST_ENTRY_FIELDS = {
    "id", "surface", "status", "reason", "evidence", "owner", "reviewed_on",
    "expires_on", "pzc_version", "pzc_layer_hashes", "source_manifest_hash",
    "call_sites",
}
ALLOWLIST_EVIDENCE_FIELDS = {"path", "sha256"}
CALLSITE_IDENTITY_FIELDS = {"relative_file", "line", "receiver", "method", "arg_count"}
INVENTORY_CALLSITE_FIELDS = {
    "id", "relative_file", "line", "receiver", "method", "arg_count", "status",
    "matched_class", "surface_name", "matched_method", "detail", "line_text", "owner",
    "verification_source", "verification_kind",
}
ALLOWLIST_SURFACE_FIELDS = {"surface_name", "receiver", "method", "verification_kind", "statuses", "owners", "files"}

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
    "IAnimationVariableSource": "zombie/core/skinnedmodel/advancedanimation/IAnimationVariableSource.java",
    "IAnimationVariableMap": "zombie/core/skinnedmodel/advancedanimation/IAnimationVariableMap.java",
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
    "cats":        ["__java_hash_set"],
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

JAVA_INTERFACE_METHOD_RE = re.compile(
    r'^\s*'
    r'(?:(?:public|default|static|abstract)\s+)*'
    r'(?:<[^>\n]+>\s+)?'
    r'(\S+)\s+'           # return type
    r'(\w+)\s*'           # method name
    r'\(([^)]*)\)\s*'     # parameters
    r'(?:\{|;)',
    re.MULTILINE,
)


def extract_java_methods(filepath: Path) -> list[JavaMethod]:
    """Extract all public methods from a Java source file."""
    if not filepath.exists():
        return []

    text = filepath.read_text(encoding="utf-8", errors="replace")
    methods = []

    matches = list(JAVA_METHOD_RE.finditer(text))
    if re.search(r'\binterface\s+\w+', text):
        matches.extend(JAVA_INTERFACE_METHOD_RE.finditer(text))

    seen = set()
    for m in sorted(matches, key=lambda item: item.start()):
        return_type = m.group(1)
        name = m.group(2)
        params = m.group(3).strip()
        param_count = 0 if not params else len(params.split(","))
        line_num = text[:m.start()].count("\n") + 1
        identity = (name, param_count, line_num)
        if identity in seen:
            continue
        seen.add(identity)
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


def count_args_from_position(text: str, paren_start: int) -> int:
    """Count arguments in masked Lua source; return -1 on unsafe syntax."""
    stack = ["("]
    closing = {")": "(", "}": "{", "]": "["}
    i = paren_start + 1
    arg_count = 0
    has_content = False

    while i < len(text) and stack:
        ch = text[i]
        if ch in "({[":
            stack.append(ch)
        elif ch in ")}]":
            if not stack or stack[-1] != closing[ch]:
                return -1
            stack.pop()
            if not stack:
                break
        elif ch == ',' and len(stack) == 1:
            arg_count += 1
        if ch not in (' ', '\t', '\n', '\r'):
            has_content = True
        i += 1

    if has_content:
        arg_count += 1  # last arg (no trailing comma)

    return -1 if stack else arg_count


def mask_lua_non_code(text: str) -> tuple[str, Optional[str]]:
    """Mask strings/comments while preserving offsets; reject unknown syntax."""
    chars = list(text)
    i = 0
    while i < len(text):
        if text.startswith("--", i):
            long_match = re.match(r"--\[(=*)\[", text[i:])
            if long_match:
                marker = "]" + long_match.group(1) + "]"
                end = text.find(marker, i + len(long_match.group(0)))
                if end < 0:
                    return "".join(chars), f"unterminated long comment at offset {i}"
                stop = end + len(marker)
            else:
                newline = text.find("\n", i)
                stop = len(text) if newline < 0 else newline
            for pos in range(i, stop):
                if chars[pos] != "\n":
                    chars[pos] = " "
            i = stop
            continue
        long_match = re.match(r"\[(=*)\[", text[i:])
        if long_match:
            marker = "]" + long_match.group(1) + "]"
            end = text.find(marker, i + len(long_match.group(0)))
            if end < 0:
                return "".join(chars), f"unterminated long string at offset {i}"
            stop = end + len(marker)
            for pos in range(i, stop):
                if chars[pos] != "\n":
                    chars[pos] = " "
            chars[i] = "x"
            i = stop
            continue
        if text[i] in {'"', "'"}:
            quote = text[i]
            start = i
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                if text[i] == "\n":
                    return "".join(chars), f"unterminated quoted string at offset {start}"
                i += 1
            else:
                return "".join(chars), f"unterminated quoted string at offset {start}"
            for pos in range(start, i):
                if chars[pos] != "\n":
                    chars[pos] = " "
            chars[start] = "x"
            continue
        i += 1
    return "".join(chars), None


def extract_mod_calls(filepath: Path) -> list[MethodCall]:
    """Extract calls from Lua source, blocking on syntax we cannot parse safely."""
    calls = []
    text = filepath.read_text(encoding="utf-8", errors="replace")
    masked, parser_error = mask_lua_non_code(text)
    if parser_error:
        return [MethodCall(str(filepath), 1, "__parser__", "unknown_syntax", -1, parser_error)]
    # A method declaration contains the same ``receiver:method(`` token shape as
    # a call. Mask declarations before scanning so definitions never inflate the
    # consumed-call inventory.
    declaration_mask = list(masked)
    for declaration in LUA_METHOD_RE.finditer(masked):
        for position in range(declaration.start(), declaration.end()):
            if declaration_mask[position] != "\n":
                declaration_mask[position] = " "
    masked = "".join(declaration_mask)
    source_lines = text.splitlines()
    for m in MOD_CALL_RE.finditer(masked):
        line_num = masked.count("\n", 0, m.start()) + 1
        arg_count = count_args_from_position(masked, m.end() - 1)
        calls.append(MethodCall(
            file=str(filepath), line_num=line_num, receiver=m.group(1), method=m.group(2),
            arg_count=arg_count,
            line_text=source_lines[line_num - 1].strip() if line_num <= len(source_lines) else "",
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

    if receiver == "__parser__" or call.arg_count < 0:
        return VerifyResult(
            status="BLOCK", call=call,
            detail=f"Parser could not prove call identity/arity: {call.line_text}",
        )

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

    if class_candidates == ["__java_hash_set"]:
        if method == "isEmpty" and call.arg_count == 0:
            return VerifyResult(
                status="OK",
                call=call,
                matched_class="HashSet",
                matched_method=method,
                detail="Java HashSet method",
            )
        return VerifyResult(
            status="WARN",
            call=call,
            detail=f"Unknown Java HashSet method '{method}'",
        )

    matches = []
    arity_mismatches = []
    candidate_space = [
        class_name for class_name in class_candidates
        if (class_name.startswith("__lua:") and class_name[6:] in lua_index)
        or (not class_name.startswith("__") and class_name in java_index)
    ]
    # Inspect every candidate. Choosing the first match is unsafe when receiver
    # data flow permits multiple unrelated runtime classes.
    for class_name in class_candidates:
        # Check Lua-side classes
        if class_name.startswith("__lua:"):
            lua_class = class_name[6:]
            if lua_class in lua_index:
                lua_methods = lua_index[lua_class]
                if method in lua_methods:
                    exact = [item for item in lua_methods[method] if item.param_count == call.arg_count]
                    if exact:
                        provenance = tuple(sorted((item.file, item.line_num, item.param_count) for item in exact))
                        matches.append((lua_class, method, f"PZ Lua method ({len(exact)} exact overload(s))", provenance))
                    else:
                        arity_mismatches.append((lua_class, sorted({item.param_count for item in lua_methods[method]})))
            continue

        # Check Java class
        if class_name not in java_index:
            continue

        java_methods = java_index[class_name]
        if method in java_methods:
            overloads = java_methods[method]
            # Check if any overload matches our arg count
            matching = [m for m in overloads if m.param_count == call.arg_count]
            if matching:
                provenance = tuple(sorted((m.file, m.line_num, m.param_count) for m in matching))
                matches.append((class_name, method, f"Exact match ({len(overloads)} overload(s))", provenance))
            else:
                arity_mismatches.append((class_name, sorted({m.param_count for m in overloads})))

    unique_provenance = {item[3] for item in matches}
    matched_candidates = {item[0] for item in matches}
    normalized_candidate_space = {item[6:] if item.startswith("__lua:") else item for item in candidate_space}
    if matches and matched_candidates != normalized_candidate_space:
        return VerifyResult(
            "BLOCK", call,
            detail="Receiver data flow is not proven for every candidate; exact="
            + ", ".join(sorted(matched_candidates)) + "; candidates=" + ", ".join(sorted(normalized_candidate_space)),
        )
    if matches and len(unique_provenance) == 1:
        class_name, matched_method, detail, _ = matches[0]
        return VerifyResult("OK", call, class_name, matched_method, detail)
    if len(unique_provenance) > 1:
        return VerifyResult(
            "BLOCK", call,
            detail="Ambiguous receiver data flow; exact matches in: " + ", ".join(item[0] for item in matches),
        )
    if arity_mismatches:
        return VerifyResult(
            "WARN", call,
            detail=f"Arg count mismatch: mod passes {call.arg_count}; candidates={arity_mismatches}",
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
    "IsoGameCharacter": ["IsoLivingCharacter", "IsoMovingObject", "IsoObject", "IAnimationVariableMap"],
    "IAnimationVariableMap": ["IAnimationVariableSource"],
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

    def resolve(class_name: str, visiting: set[str]) -> dict[str, list[JavaMethod]]:
        if class_name in resolved:
            return resolved[class_name]
        if class_name in visiting:
            chain = " -> ".join((*sorted(visiting), class_name))
            raise ValueError(f"Java inheritance cycle: {chain}")

        visiting.add(class_name)
        merged = dict(raw_index.get(class_name, {}))
        for parent in JAVA_INHERITANCE.get(class_name, []):
            if parent not in raw_index:
                continue
            for method_name, methods in resolve(parent, visiting).items():
                if method_name not in merged:
                    merged[method_name] = methods
        visiting.remove(class_name)
        resolved[class_name] = merged
        return merged

    for class_name in raw_index:
        resolve(class_name, set())
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


class StrictArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        payload = internal_error_payload("ArgumentError", message)
        self._print_message(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n", sys.stderr)
        raise SystemExit(EXIT_INTERNAL_ERROR)


def parse_args() -> argparse.Namespace:
    parser = StrictArgumentParser(
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
        "--mode",
        choices=("strict", "advisory"),
        default="strict",
        help="Strict is the update-safe gate; advisory is report-only and never claims clean/update-safe",
    )
    parser.add_argument(
        "--allowlist-file",
        type=Path,
        default=DEFAULT_ALLOWLIST_FILE,
        help=f"Machine-readable exception allowlist (default: {DEFAULT_ALLOWLIST_FILE})",
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
        raise FileNotFoundError(f"required input missing: {version_file}")
    try:
        value = json.loads(version_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid VERSION.json: {exc}") from exc
    if not _exact_object(value, {"game_build", "decompiled_at", "game_path", "decompiler_launcher", "java_runtime", "layer_hashes"}, {"game_build", "layer_hashes"}):
        raise ValueError("VERSION.json schema is incomplete or has unknown fields")
    scalar_fields = {
        "game_build", "decompiled_at", "game_path", "decompiler_launcher", "java_runtime",
    }
    if any(field in value and (not isinstance(value[field], str) or not value[field]) for field in scalar_fields):
        raise ValueError("VERSION.json scalar field types are invalid")
    layer_hashes = value.get("layer_hashes")
    if (
        not isinstance(layer_hashes, dict)
        or set(layer_hashes) != {"java", "lua", "media"}
        or any(not isinstance(layer_hashes[key], str) or not layer_hashes[key] for key in ("java", "lua", "media"))
    ):
        raise ValueError("VERSION.json layer_hashes must contain exactly non-empty string java/lua/media hashes")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def required_input_paths(baseline_file: Path, allowlist_file: Path) -> list[Path]:
    """Return the closed-world set of bytes consumed by a strict verification."""
    paths = [Path(__file__).resolve(), PZ_CODEBASE / "VERSION.json", baseline_file.resolve(), allowlist_file.resolve()]
    paths.extend((PZ_JAVA_ROOT / rel_path).resolve() for rel_path in JAVA_CLASS_FILES.values())
    paths.extend((PZ_LUA_ROOT / rel_path).resolve() for rel_path in PZ_LUA_FILES.values() if rel_path)
    for lua_dir in MOD_LUA_DIRS:
        if lua_dir.is_dir():
            paths.extend(path.resolve() for path in lua_dir.rglob("*.lua"))
    paths.append((UTMODS_ROOT / "UniversalTraits" / "media" / "scripts" / "UT_character_traits.txt").resolve())
    return sorted(set(paths), key=lambda item: item.as_posix().casefold())


def build_source_manifest(paths: list[Path], baseline_file: Path, allowlist_file: Path) -> dict:
    workspace_root = UTMODS_ROOT.parent.resolve()
    entries = []
    errors = []
    for path in paths:
        resolved = path.resolve()
        try:
            relative = resolved.relative_to(workspace_root).as_posix()
        except ValueError:
            errors.append({"path": str(resolved), "error": "outside_workspace"})
            continue
        if not resolved.is_file():
            errors.append({"path": relative, "error": "missing_or_not_file"})
            continue
        entries.append({"path": relative, "sha256": sha256_file(resolved), "size": resolved.stat().st_size})
    policy_files = {}
    for role, path in (("baseline", baseline_file), ("allowlist", allowlist_file)):
        resolved = path.resolve()
        try:
            policy_files[role] = resolved.relative_to(workspace_root).as_posix()
        except ValueError:
            policy_files[role] = str(resolved)
    payload = {"schema_version": 1, "files": entries, "policy_files": policy_files}
    excluded = set(policy_files.values())
    binding_files = [entry for entry in entries if entry["path"] not in excluded]
    return {
        **payload,
        "manifest_hash": hashlib.sha256(canonical_json(payload).encode("utf-8")).hexdigest(),
        "binding_hash": hashlib.sha256(canonical_json({"schema_version": 1, "files": binding_files}).encode("utf-8")).hexdigest(),
        "errors": errors,
    }


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


def build_inventory(results: list[VerifyResult], pz_metadata: dict, source_manifest: Optional[dict] = None) -> dict:
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
        "pzc_version": pz_metadata.get("game_build"),
        "pzc_decompiled_at": pz_metadata.get("decompiled_at"),
        "pzc_layer_hashes": pz_metadata.get("layer_hashes") or {},
        "source_manifest_hash": (source_manifest or {}).get("binding_hash"),
        "input_manifest_hash": (source_manifest or {}).get("manifest_hash"),
        "source_manifest": source_manifest or {},
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
    path.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_baseline_snapshot(inventory: dict, pz_metadata: dict) -> dict:
    return {
        "pzc_version": pz_metadata.get("game_build"),
        "pzc_decompiled_at": pz_metadata.get("decompiled_at"),
        "pzc_layer_hashes": pz_metadata.get("layer_hashes") or {},
        "source_manifest_hash": inventory.get("source_manifest_hash"),
        "summary": inventory.get("summary", {}),
        "unique_surfaces": inventory.get("unique_surfaces", []),
    }


def write_baseline(path: Path, baseline: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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


def canonical_json(value: object) -> str:
    """Return deterministic JSON, excluding only explicitly volatile fields."""
    volatile = {"generated_at", "pzc_decompiled_at", "line", "line_text", "occurrence_count"}

    def clean(item: object) -> object:
        if isinstance(item, dict):
            return {key: clean(item[key]) for key in sorted(item) if key not in volatile}
        if isinstance(item, list):
            cleaned = [clean(child) for child in item]
            return sorted(cleaned, key=lambda child: json.dumps(child, sort_keys=True, separators=(",", ":")))
        return item

    return json.dumps(clean(value), sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def stable_issue_id(category: str, surface: Optional[dict] = None, detail: object = None) -> str:
    identity = {"category": category, "surface": simplify_surface(surface) if surface else None, "detail": detail}
    digest = hashlib.sha256(canonical_json(identity).encode("utf-8")).hexdigest()[:16]
    return f"pzapi-{category}-{digest}"


def load_allowlist(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"required strict allowlist missing: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("allowlist root must be an object")
    return value


def emit_internal_error(kind: str, message: str, json_output: bool) -> None:
    payload = internal_error_payload(kind, message)
    stream = sys.stdout if json_output else sys.stderr
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")), file=stream)


def internal_error_payload(kind: str, message: str) -> dict:
    return {"schema_version": CONTRACT_SCHEMA_VERSION, "status": "internal_error", "error": {"kind": str(kind), "message": str(message)}, "exit_code": EXIT_INTERNAL_ERROR}


def contract_exit_code(report: dict) -> int:
    return EXIT_OK if report.get("update_safe") is True else EXIT_BLOCKED


def _issue(category: str, classification: str, detail: object, surface: Optional[dict] = None) -> dict:
    return {
        "id": stable_issue_id(category, surface, detail),
        "category": category,
        "classification": classification,
        "surface": simplify_surface(surface) if surface else None,
        "detail": detail,
    }


def _exact_object(value: object, fields: set[str], required: set[str]) -> bool:
    return isinstance(value, dict) and set(value) <= fields and required <= set(value)


def _nullable_string(value: object) -> bool:
    return value is None or isinstance(value, str)


def _string_list(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def _valid_surface(surface: object, fields: set[str], include_occurrences: bool) -> bool:
    if not _exact_object(surface, fields, fields):
        return False
    assert isinstance(surface, dict)
    valid = (
        _nullable_string(surface.get("surface_name"))
        and all(isinstance(surface.get(field), str) for field in ("receiver", "method", "verification_kind"))
        and all(_string_list(surface.get(field)) for field in ("statuses", "owners", "files"))
    )
    return valid and (not include_occurrences or (type(surface.get("occurrence_count")) is int and surface["occurrence_count"] > 0))


def _callsite_identity(call: dict) -> dict:
    return {field: call.get(field) for field in sorted(CALLSITE_IDENTITY_FIELDS)}


def _surface_calls(inventory: dict, surface: Optional[dict]) -> list[dict]:
    if not surface:
        return []
    wanted = surface_key(surface)
    calls = [
        _callsite_identity(call) for call in inventory.get("call_sites", [])
        if isinstance(call, dict) and surface_key({
            "surface_name": call.get("surface_name"), "receiver": call.get("receiver"),
            "method": call.get("method"), "verification_kind": call.get("verification_kind", "method_call"),
        }) == wanted
    ]
    return sorted(calls, key=canonical_json)


def _allowlist_entry_error(entry: object, manifest_files: dict[str, str]) -> Optional[str]:
    if not _exact_object(entry, ALLOWLIST_ENTRY_FIELDS, ALLOWLIST_ENTRY_FIELDS):
        return "entry fields must exactly match the strict schema"
    assert isinstance(entry, dict)
    scalar_strings = ("id", "status", "reason", "owner", "reviewed_on", "expires_on", "pzc_version", "source_manifest_hash")
    if any(not isinstance(entry.get(field), str) or not entry[field].strip() for field in scalar_strings):
        return "required string field is missing or empty"
    if not isinstance(entry.get("surface"), dict) or not isinstance(entry.get("pzc_layer_hashes"), dict):
        return "surface and pzc_layer_hashes must be objects"
    surface = entry["surface"]
    if not _exact_object(surface, ALLOWLIST_SURFACE_FIELDS, ALLOWLIST_SURFACE_FIELDS):
        return "surface fields must exactly match the strict schema"
    if not _valid_surface(surface, ALLOWLIST_SURFACE_FIELDS, False):
        return "surface field types are invalid"
    if set(entry["pzc_layer_hashes"]) != {"java", "lua", "media"} or not all(isinstance(value, str) and value for value in entry["pzc_layer_hashes"].values()):
        return "pzc_layer_hashes must contain exactly non-empty java/lua/media hashes"
    if not isinstance(entry.get("call_sites"), list) or not entry["call_sites"]:
        return "call_sites must be a non-empty list"
    if any(not _exact_object(call, CALLSITE_IDENTITY_FIELDS, CALLSITE_IDENTITY_FIELDS) for call in entry["call_sites"]):
        return "call-site identity has missing or unknown fields"
    if any(not isinstance(call["relative_file"], str) or not isinstance(call["receiver"], str) or not isinstance(call["method"], str) or type(call["line"]) is not int or type(call["arg_count"]) is not int for call in entry["call_sites"]):
        return "call-site identity types are invalid"
    evidence = entry.get("evidence")
    if not _exact_object(evidence, ALLOWLIST_EVIDENCE_FIELDS, ALLOWLIST_EVIDENCE_FIELDS):
        return "evidence must contain exactly path and sha256"
    assert isinstance(evidence, dict)
    if not all(isinstance(evidence.get(field), str) and evidence[field] for field in ALLOWLIST_EVIDENCE_FIELDS) or re.fullmatch(r"[0-9a-f]{64}", evidence["sha256"]) is None:
        return "evidence path/hash types are invalid"
    if manifest_files.get(evidence.get("path")) != evidence.get("sha256"):
        return "evidence identity/hash is absent from or drifted against the source manifest"
    try:
        reviewed = date.fromisoformat(entry["reviewed_on"])
        expires = date.fromisoformat(entry["expires_on"])
        if reviewed > expires:
            return "reviewed_on is after expires_on"
    except ValueError:
        return "review/expiry dates must be ISO dates"
    return None


def evaluate_strict_contract(
    inventory: dict,
    pz_metadata: dict,
    baseline: Optional[dict],
    allowlist: Optional[dict] = None,
    today: Optional[date] = None,
) -> dict:
    """Evaluate the fail-closed update-safe contract without filesystem access."""
    issues = []
    today = today or datetime.now(timezone.utc).date()
    if not isinstance(inventory, dict):
        issues.append(_issue("inventory-shape", "verifier_defect", "inventory root must be an object"))
        inventory = {}
    if not isinstance(pz_metadata, dict):
        issues.append(_issue("source-integrity", "verifier_defect", "PZ metadata root must be an object"))
        pz_metadata = {}
    inventory_fields = {"pzc_version", "pzc_decompiled_at", "pzc_layer_hashes", "source_manifest_hash", "input_manifest_hash", "source_manifest", "summary", "call_sites", "unique_surfaces"}
    inventory_required = {"pzc_version", "pzc_layer_hashes", "source_manifest_hash", "input_manifest_hash", "source_manifest", "call_sites", "unique_surfaces"}
    if not _exact_object(inventory, inventory_fields, inventory_required) or not isinstance(inventory.get("call_sites"), list) or not isinstance(inventory.get("unique_surfaces"), list):
        issues.append(_issue("inventory-shape", "verifier_defect", "inventory schema is incomplete, corrupt, or has unknown fields"))
    if not isinstance(inventory.get("pzc_version"), str) or not _nullable_string(inventory.get("pzc_decompiled_at")) or not all(isinstance(inventory.get(field), str) for field in ("source_manifest_hash", "input_manifest_hash")):
        issues.append(_issue("inventory-shape", "verifier_defect", "inventory scalar field types are invalid"))
    summary = inventory.get("summary")
    summary_fields = {"call_sites", "unique_surfaces", "ok", "warn", "fail", "skip"}
    if summary is not None and (not _exact_object(summary, summary_fields, summary_fields) or any(type(summary.get(field)) is not int or summary[field] < 0 for field in summary_fields)):
        issues.append(_issue("inventory-shape", "verifier_defect", "inventory summary field types are invalid"))
    layer_hashes = inventory.get("pzc_layer_hashes")
    if not isinstance(layer_hashes, dict) or set(layer_hashes) != {"java", "lua", "media"} or not all(isinstance(value, str) and value for value in layer_hashes.values()):
        issues.append(_issue("inventory-shape", "verifier_defect", "pzc_layer_hashes must contain exactly non-empty java/lua/media hashes"))
    surface_fields = {"surface_name", "receiver", "method", "verification_kind", "statuses", "owners", "files", "occurrence_count"}
    valid_surfaces = []
    for index, surface in enumerate(inventory.get("unique_surfaces", []) if isinstance(inventory.get("unique_surfaces"), list) else []):
        valid = _valid_surface(surface, surface_fields, True)
        if valid:
            valid_surfaces.append(surface)
        else:
            issues.append(_issue("inventory-shape", "verifier_defect", {"invalid_surface_index": index}))
    valid_calls = []
    for index, call in enumerate(inventory.get("call_sites", []) if isinstance(inventory.get("call_sites"), list) else []):
        owner = call.get("owner") if isinstance(call, dict) else None
        if _exact_object(call, INVENTORY_CALLSITE_FIELDS, INVENTORY_CALLSITE_FIELDS) and type(call.get("line")) is int and type(call.get("arg_count")) is int and all(isinstance(call.get(field), str) for field in ("id", "relative_file", "receiver", "method", "status", "detail", "line_text", "verification_source", "verification_kind")) and all(_nullable_string(call.get(field)) for field in ("surface_name", "matched_class", "matched_method")) and _exact_object(owner, {"kind", "id", "file"}, {"kind", "id", "file"}) and all(isinstance(owner.get(field), str) for field in ("kind", "id", "file")):
            valid_calls.append(call)
        else:
            issues.append(_issue("inventory-shape", "verifier_defect", {"invalid_callsite_index": index}))
    inventory = {**inventory, "unique_surfaces": valid_surfaces, "call_sites": valid_calls}
    for surface in valid_surfaces:
        matching_calls = [call for call in valid_calls if surface_key({"surface_name": call.get("surface_name"), "receiver": call["receiver"], "method": call["method"], "verification_kind": call["verification_kind"]}) == surface_key(surface)]
        actual_occurrences = len(matching_calls)
        aggregate_matches = (
            sorted(set(call["status"] for call in matching_calls)) == sorted(surface["statuses"])
            and sorted(set(f"{call['owner']['kind']}:{call['owner']['id']}" for call in matching_calls)) == sorted(surface["owners"])
            and sorted(set(call["relative_file"] for call in matching_calls)) == sorted(surface["files"])
        )
        if surface["occurrence_count"] != actual_occurrences or not aggregate_matches:
            issues.append(_issue("inventory-shape", "verifier_defect", {
                "surface": simplify_surface(surface),
                "declared_occurrence_count": surface["occurrence_count"],
                "actual_call_sites": actual_occurrences,
                "aggregate_matches": aggregate_matches,
            }))

    manifest = inventory.get("source_manifest") if isinstance(inventory.get("source_manifest"), dict) else {}
    manifest_files_list = manifest.get("files") if isinstance(manifest.get("files"), list) else []
    policy_files = manifest.get("policy_files")
    manifest_payload = {"schema_version": manifest.get("schema_version"), "files": manifest_files_list, "policy_files": policy_files}
    computed_manifest_hash = hashlib.sha256(canonical_json(manifest_payload).encode("utf-8")).hexdigest()
    excluded_policy_files = set(policy_files.values()) if _exact_object(policy_files, {"baseline", "allowlist"}, {"baseline", "allowlist"}) and all(isinstance(value, str) for value in policy_files.values()) else set()
    binding_payload = {"schema_version": manifest.get("schema_version"), "files": [item for item in manifest_files_list if isinstance(item, dict) and item.get("path") not in excluded_policy_files]}
    computed_binding_hash = hashlib.sha256(canonical_json(binding_payload).encode("utf-8")).hexdigest()
    valid_manifest_entries = [
        item for item in manifest_files_list
        if _exact_object(item, {"path", "sha256", "size"}, {"path", "sha256", "size"})
        and isinstance(item.get("path"), str) and isinstance(item.get("sha256"), str)
        and re.fullmatch(r"[0-9a-f]{64}", item["sha256"]) is not None
        and type(item.get("size")) is int and item["size"] >= 0
    ]
    manifest_files = {item["path"]: item["sha256"] for item in valid_manifest_entries}
    manifest_invalid = (
        not _exact_object(manifest, {"schema_version", "files", "policy_files", "manifest_hash", "binding_hash", "errors"}, {"schema_version", "files", "policy_files", "manifest_hash", "binding_hash", "errors"})
        or type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1
        or not isinstance(manifest.get("errors"), list) or manifest.get("errors") != []
        or not all(isinstance(manifest.get(field), str) for field in ("manifest_hash", "binding_hash"))
        or len(excluded_policy_files) != 2 or not excluded_policy_files <= set(manifest_files)
        or len(valid_manifest_entries) != len(manifest_files_list)
        or len(manifest_files) != len(valid_manifest_entries)
        or inventory.get("input_manifest_hash") != computed_manifest_hash
        or inventory.get("source_manifest_hash") != computed_binding_hash
    )
    if manifest_invalid:
        issues.append(_issue("source-integrity", "verifier_defect", "source manifest is missing, corrupt, incomplete, or self-inconsistent"))

    if inventory.get("pzc_version") != pz_metadata.get("game_build") or (
        inventory.get("pzc_layer_hashes") or {}
    ) != (pz_metadata.get("layer_hashes") or {}) or inventory.get("source_manifest_hash") != pz_metadata.get("source_manifest_hash"):
        issues.append(_issue("inventory-stale", "inventory_stale", {
            "inventory_version": inventory.get("pzc_version"),
            "current_version": pz_metadata.get("game_build"),
            "inventory_hashes": inventory.get("pzc_layer_hashes") or {},
            "current_hashes": pz_metadata.get("layer_hashes") or {},
            "inventory_manifest_hash": inventory.get("source_manifest_hash"),
            "current_manifest_hash": pz_metadata.get("source_manifest_hash"),
        }))

    if baseline is None:
        issues.append(_issue("baseline-missing", "inventory_stale", "baseline is required in strict mode"))
    elif not _exact_object(baseline, {"generated_at", "pzc_version", "pzc_decompiled_at", "pzc_layer_hashes", "source_manifest_hash", "summary", "unique_surfaces"}, {"pzc_version", "pzc_layer_hashes", "source_manifest_hash", "unique_surfaces"}) or ("generated_at" in baseline and not isinstance(baseline["generated_at"], str)) or not isinstance(baseline.get("pzc_version"), str) or not _nullable_string(baseline.get("pzc_decompiled_at")) or not isinstance(baseline.get("source_manifest_hash"), str) or not isinstance(baseline.get("unique_surfaces"), list) or not isinstance(baseline.get("pzc_layer_hashes"), dict) or set(baseline.get("pzc_layer_hashes", {})) != {"java", "lua", "media"} or not all(isinstance(value, str) and value for value in baseline.get("pzc_layer_hashes", {}).values()) or ("summary" in baseline and (not _exact_object(baseline["summary"], summary_fields, summary_fields) or any(type(baseline["summary"].get(field)) is not int or baseline["summary"][field] < 0 for field in summary_fields))) or any(not _valid_surface(surface, surface_fields, True) for surface in baseline.get("unique_surfaces", [])):
        issues.append(_issue("baseline-shape", "verifier_defect", "baseline schema is incomplete or changed"))
    else:
        comparison = compare_to_baseline(inventory, pz_metadata, baseline)
        if baseline.get("pzc_version") != pz_metadata.get("game_build") or comparison["pz_shape_changed"] or baseline.get("source_manifest_hash") != inventory.get("source_manifest_hash"):
            issues.append(_issue("version-hash-mismatch", "inventory_stale", {
                "baseline_version": baseline.get("pzc_version"),
                "current_version": pz_metadata.get("game_build"),
                "baseline_hashes": baseline.get("pzc_layer_hashes") or {},
                "current_hashes": pz_metadata.get("layer_hashes") or {},
                "baseline_manifest_hash": baseline.get("source_manifest_hash"),
                "current_manifest_hash": inventory.get("source_manifest_hash"),
            }))
        for field, category in (("new_surfaces", "new-surface"), ("removed_surfaces", "removed-surface")):
            for surface in comparison[field]:
                issues.append(_issue(category, "inventory_stale", field, surface))
        for change in comparison["status_changes"]:
            issues.append(_issue("status-change", "inventory_stale", {"before": change["before"], "after": change["after"]}, change["surface"]))

    for surface in inventory.get("unique_surfaces", []):
        for status in sorted(set(surface.get("statuses", []))):
            if status not in KNOWN_STATUSES:
                issues.append(_issue("unknown-status", "verifier_defect", status, surface))
            elif status in {"WARN", "FAIL", "SKIP", "BLOCK"}:
                classification = "engine_absence" if status == "FAIL" and surface.get("surface_name") else "mod_only_dynamic_surface" if status == "SKIP" else "verifier_defect"
                category = "verifier-defect" if status == "BLOCK" else status.lower()
                issues.append(_issue(category, classification, status, surface))

    for call in inventory.get("call_sites", []):
        if call.get("arg_count") == -1:
            surface = {
                "surface_name": call.get("surface_name"), "receiver": call.get("receiver"),
                "method": call.get("method"), "verification_kind": call.get("verification_kind", "method_call"),
                "statuses": [call.get("status")], "owners": [f"{call.get('owner', {}).get('kind')}:{call.get('owner', {}).get('id')}"],
                "files": [call.get("relative_file")],
            }
            issues.append(_issue("unresolved-multiline-arity", "verifier_defect", "argument count unresolved", surface))

    if allowlist is None:
        issues.append(_issue("required-input-missing", "verifier_defect", "strict allowlist is required"))
        allowlist = {}
    entries = allowlist.get("exceptions", []) if isinstance(allowlist, dict) else []
    malformed = not _exact_object(allowlist, ALLOWLIST_ROOT_FIELDS, ALLOWLIST_ROOT_FIELDS) or type(allowlist.get("schema_version")) is not int or allowlist.get("schema_version") != CONTRACT_SCHEMA_VERSION or not isinstance(entries, list)
    if malformed:
        issues.append(_issue("allowlist-shape", "verifier_defect", "unsupported allowlist schema"))
        entries = []
    entry_errors = {}
    for index, entry in enumerate(entries):
        error = _allowlist_entry_error(entry, manifest_files)
        if error:
            entry_errors[index] = error
            issues.append(_issue("allowlist-shape", "verifier_defect", {"index": index, "error": error}))
    by_id = {entry.get("id"): entry for index, entry in enumerate(entries) if isinstance(entry, dict) and index not in entry_errors}
    entry_ids = [entry.get("id") for entry in entries if isinstance(entry, dict)]
    duplicate_ids = sorted({entry_id for entry_id in entry_ids if entry_id is not None and entry_ids.count(entry_id) > 1})
    for entry_id in duplicate_ids:
        issues.append(_issue("allowlist-duplicate", "verifier_defect", {"entry_id": entry_id}))
    used = set()
    unresolved = []
    approved = []
    for issue in issues:
        entry = by_id.get(issue["id"])
        expected_calls = _surface_calls(inventory, issue.get("surface"))
        valid = bool(
            issue["category"] in WAIVABLE_CATEGORIES and issue["category"] not in FOUNDATIONAL_CATEGORIES and issue["classification"] != "verifier_defect" and entry
            and entry.get("surface") == issue["surface"] and entry.get("status") == issue["category"]
            and entry.get("pzc_version") == pz_metadata.get("game_build")
            and entry.get("pzc_layer_hashes") == (pz_metadata.get("layer_hashes") or {})
            and entry.get("source_manifest_hash") == inventory.get("source_manifest_hash")
            and sorted(entry.get("call_sites", []), key=canonical_json) == expected_calls
        )
        try:
            valid = valid and date.fromisoformat(entry.get("reviewed_on", "")) <= today <= date.fromisoformat(entry.get("expires_on", ""))
        except (TypeError, ValueError):
            valid = False
        if valid:
            used.add(issue["id"])
            approved.append({**issue, "classification": "approved_exception", "reason": entry["reason"], "evidence": entry["evidence"], "owner": entry["owner"]})
        else:
            unresolved.append(issue)
    stale = sorted(entry_id for entry_id in by_id if entry_id not in used)
    for entry_id in stale:
        unresolved.append(_issue("allowlist-unused", "verifier_defect", {"entry_id": entry_id}))

    unresolved.sort(key=lambda item: item["id"])
    approved.sort(key=lambda item: item["id"])
    return {
        "schema_version": CONTRACT_SCHEMA_VERSION,
        "mode": "strict",
        "update_safe": not unresolved,
        "status": "update_safe" if not unresolved else "blocked",
        "counts": {"issues": len(issues), "unapproved": len(unresolved), "approved": len(approved), "unused_allowlist": len(stale)},
        "issue_ids": [item["id"] for item in unresolved[:MAX_REPORT_ISSUES]],
        "issues": unresolved[:MAX_REPORT_ISSUES],
        "approved_exceptions": approved[:MAX_REPORT_ISSUES],
        "truncated": len(unresolved) > MAX_REPORT_ISSUES or len(approved) > MAX_REPORT_ISSUES,
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


def _run(args: argparse.Namespace) -> None:
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
        emit_internal_error("FileNotFoundError", f"PZ codebase not found at {PZ_CODEBASE}", json_output)
        sys.exit(EXIT_INTERNAL_ERROR)

    try:
        pz_metadata = load_pzcodebase_metadata()
        source_manifest = build_source_manifest(
            required_input_paths(args.baseline_file, args.allowlist_file),
            args.baseline_file,
            args.allowlist_file,
        )
        for required_dir in [PZ_JAVA_ROOT, PZ_LUA_ROOT, *MOD_LUA_DIRS]:
            if not required_dir.is_dir():
                source_manifest["errors"].append({"path": str(required_dir), "error": "missing_or_not_directory"})
        pz_metadata = {**pz_metadata, "source_manifest_hash": source_manifest["binding_hash"]}
    except (OSError, ValueError, TypeError) as exc:
        emit_internal_error(type(exc).__name__, str(exc), json_output)
        sys.exit(EXIT_INTERNAL_ERROR)

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

    final_manifest = build_source_manifest(
        required_input_paths(args.baseline_file, args.allowlist_file),
        args.baseline_file,
        args.allowlist_file,
    )
    if final_manifest["manifest_hash"] != source_manifest["manifest_hash"]:
        source_manifest["errors"].append({"error": "inputs_changed_during_verification"})

    inventory = build_inventory(results, pz_metadata, source_manifest)

    baseline_result = None
    baseline = None
    if args.compare_baseline or args.mode == "strict":
        try:
            baseline = load_baseline(args.baseline_file)
        except (OSError, json.JSONDecodeError, ValueError, TypeError) as exc:
            emit_internal_error(type(exc).__name__, f"invalid baseline: {exc}", json_output)
            sys.exit(EXIT_INTERNAL_ERROR)
        baseline_result = compare_to_baseline(inventory, pz_metadata, baseline)

    contract_report = None
    if args.mode == "strict":
        try:
            allowlist = load_allowlist(args.allowlist_file)
            contract_report = evaluate_strict_contract(inventory, pz_metadata, baseline, allowlist)
        except (OSError, json.JSONDecodeError, ValueError, TypeError) as exc:
            emit_internal_error(type(exc).__name__, f"invalid allowlist: {exc}", json_output)
            sys.exit(EXIT_INTERNAL_ERROR)

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
        if args.mode != "strict" or contract_report is None or not contract_report["update_safe"]:
            print("BLOCKED: refusing to write baseline unless the strict contract is update-safe", file=sys.stderr)
            sys.exit(EXIT_BLOCKED)
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
        if contract_report is not None:
            output["contract"] = contract_report
        else:
            output["contract"] = {"mode": "advisory", "update_safe": False, "status": "report_only"}
        if args.inventory_json:
            output["inventory"] = inventory
        print(json.dumps(output, indent=2, sort_keys=True))
        should_fail = not contract_report["update_safe"] if contract_report is not None else bool(fails)
        if args.mode == "advisory" and args.compare_baseline and baseline_result and baseline_result["status"] in {"baseline_missing", "tracked_api_breakage"}:
            should_fail = True
        sys.exit(EXIT_BLOCKED if should_fail else EXIT_OK)

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
    print(f"  Mode:                      {args.mode}")
    if contract_report is not None:
        print(f"  Update-safe:               {contract_report['update_safe']}")
        print(f"  Contract issues:           {contract_report['counts']['unapproved']}")
    else:
        print("  Gate status:               report-only (not update-safe)")
    if args.inventory_out:
        print(f"  Inventory file:            {args.inventory_out}")
    print()

    if contract_report is not None and not contract_report["update_safe"]:
        print(f"EXIT CODE: 1 -- strict API contract blocked by {contract_report['counts']['unapproved']} issue(s)")
        sys.exit(1)
    elif contract_report is not None:
        print("EXIT CODE: 0 -- strict API contract is update-safe")
        sys.exit(0)
    elif fails:
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
        print("EXIT CODE: 0 -- advisory report completed (not an update-safe determination)")
        sys.exit(0)


def main() -> None:
    """Normalize every unexpected failure after successful argument parsing."""
    args = parse_args()
    try:
        _run(args)
    except SystemExit:
        raise
    except Exception as exc:
        emit_internal_error(type(exc).__name__, str(exc), args.json_output)
        raise SystemExit(EXIT_INTERNAL_ERROR) from None


if __name__ == "__main__":
    main()
