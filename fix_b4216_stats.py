"""
B42.16 Stats API Migration Script
Replaces removed named stat getters/setters with generic CharacterStat-based API.

Migration map:
  stats:getPanic()       → stats:get(CharacterStat.PANIC)
  stats:setPanic(v)      → stats:set(CharacterStat.PANIC, v)
  stats:getStress()      → stats:get(CharacterStat.STRESS)
  stats:setStress(v)     → stats:set(CharacterStat.STRESS, v)
  stats:getFatigue()     → stats:get(CharacterStat.FATIGUE)
  stats:setFatigue(v)    → stats:set(CharacterStat.FATIGUE, v)
  stats:getHunger()      → stats:get(CharacterStat.HUNGER)
  stats:setHunger(v)     → stats:set(CharacterStat.HUNGER, v)
  stats:getThirst()      → stats:get(CharacterStat.THIRST)
  stats:setThirst(v)     → stats:set(CharacterStat.THIRST, v)
  stats:getBoredom()     → stats:get(CharacterStat.BOREDOM)
  stats:setBoredom(v)    → stats:set(CharacterStat.BOREDOM, v)
  stats:getEndurance()   → stats:get(CharacterStat.ENDURANCE)
  stats:setEndurance(v)  → stats:set(CharacterStat.ENDURANCE, v)
  stats:getDrunkenness() → stats:get(CharacterStat.INTOXICATION)
  stats:setDrunkenness(v)→ stats:set(CharacterStat.INTOXICATION, v)
  stats:getUnhappiness() → stats:get(CharacterStat.UNHAPPINESS)
  stats:setUnhappiness(v)→ stats:set(CharacterStat.UNHAPPINESS, v)
  stats:getPain()        → stats:get(CharacterStat.PAIN)
  stats:setPain(v)       → stats:set(CharacterStat.PAIN, v)

  player:isSleeping()    → player:isAsleep()

  bodyDamage:getInfectionLevel()    → bodyDamage:getApparentInfectionLevel()
  bodyDamage:setInfectionLevel(v)   → (use stats-based approach)

  bd:getWetness()        → stats:get(CharacterStat.WETNESS)
  bd:setWetness(v)       → stats:set(CharacterStat.WETNESS, v)
  (where bd = player:getBodyDamage())

  body:getUnhappinessLevel()    → stats:get(CharacterStat.UNHAPPINESS)
  body:setUnhappinessLevel(v)   → stats:set(CharacterStat.UNHAPPINESS, v)

  bodyDamage:getPanicLevel()    → stats:get(CharacterStat.PANIC)

  stats:getMaxEndurance()       → CharacterStat.ENDURANCE:getMaximumValue()
"""

import re
import os
import glob

TRAITS_DIR = os.path.join("UniversalTraits", "media", "lua", "shared", "UniversalTraits", "traits")
UTCORE_DIR = os.path.join("UT_CORE", "media", "lua", "shared", "UTCore")

# Simple getter replacements: any_var:getXX() → any_var:get(CharacterStat.YY)
GETTER_MAP = {
    "getPanic":       "CharacterStat.PANIC",
    "getStress":      "CharacterStat.STRESS",
    "getFatigue":     "CharacterStat.FATIGUE",
    "getHunger":      "CharacterStat.HUNGER",
    "getThirst":      "CharacterStat.THIRST",
    "getBoredom":     "CharacterStat.BOREDOM",
    "getEndurance":   "CharacterStat.ENDURANCE",
    "getDrunkenness": "CharacterStat.INTOXICATION",
    "getUnhappiness": "CharacterStat.UNHAPPINESS",
    "getPain":        "CharacterStat.PAIN",
}

# Simple setter replacements: any_var:setXX(val) → any_var:set(CharacterStat.YY, val)
SETTER_MAP = {
    "setPanic":       "CharacterStat.PANIC",
    "setStress":      "CharacterStat.STRESS",
    "setFatigue":     "CharacterStat.FATIGUE",
    "setHunger":      "CharacterStat.HUNGER",
    "setThirst":      "CharacterStat.THIRST",
    "setBoredom":     "CharacterStat.BOREDOM",
    "setEndurance":   "CharacterStat.ENDURANCE",
    "setDrunkenness": "CharacterStat.INTOXICATION",
    "setUnhappiness": "CharacterStat.UNHAPPINESS",
    "setPain":        "CharacterStat.PAIN",
}


def replace_stat_getters(line):
    """Replace stats:getXX() with stats:get(CharacterStat.XX)"""
    for old_method, stat_const in GETTER_MAP.items():
        # Match any_var:getXX() — the () must be empty
        pattern = r'(\w+):' + old_method + r'\(\)'
        replacement = r'\1:get(' + stat_const + ')'
        line = re.sub(pattern, replacement, line)
    return line


def replace_stat_setters(line):
    """Replace stats:setXX(val) with stats:set(CharacterStat.XX, val)
    
    Handle nested parens by finding the matching close paren.
    """
    for old_method, stat_const in SETTER_MAP.items():
        # Find occurrences of var:setXX(
        search = ':' + old_method + '('
        idx = 0
        while True:
            pos = line.find(search, idx)
            if pos == -1:
                break
            # Find the variable name before the colon
            colon_pos = pos
            var_start = colon_pos - 1
            while var_start >= 0 and (line[var_start].isalnum() or line[var_start] in ('_', ')', ']')):
                # Handle chained calls like player:getStats():setXX(...)
                if line[var_start] == ')':
                    # Walk back to find matching (
                    depth = 1
                    var_start -= 1
                    while var_start >= 0 and depth > 0:
                        if line[var_start] == ')': depth += 1
                        elif line[var_start] == '(': depth -= 1
                        var_start -= 1
                    continue
                var_start -= 1
            var_start += 1
            
            # Extract the variable + colon
            var_name = line[var_start:colon_pos]
            
            # Find the argument by matching parens
            arg_start = pos + len(search)
            depth = 1
            i = arg_start
            while i < len(line) and depth > 0:
                if line[i] == '(': depth += 1
                elif line[i] == ')': depth -= 1
                i += 1
            arg_end = i - 1  # position of closing )
            arg = line[arg_start:arg_end]
            
            # Build replacement
            old_text = line[var_start:i]
            new_text = var_name + ':set(' + stat_const + ', ' + arg + ')'
            line = line[:var_start] + new_text + line[i:]
            idx = var_start + len(new_text)
    return line


def replace_sleeping(line):
    """Replace :isSleeping() with :isAsleep()"""
    return line.replace(':isSleeping()', ':isAsleep()')


def replace_getmaxendurance(line):
    """Replace stats:getMaxEndurance() with CharacterStat.ENDURANCE:getMaximumValue()"""
    return re.sub(r'\w+:getMaxEndurance\(\)', 'CharacterStat.ENDURANCE:getMaximumValue()', line)


def replace_infection_level(line):
    """Replace bodyDamage:getInfectionLevel() → bodyDamage:getApparentInfectionLevel()"""
    line = re.sub(r'(\w+):getInfectionLevel\(\)', r'\1:getApparentInfectionLevel()', line)
    # setInfectionLevel is trickier — it doesn't exist anymore.
    # Flag these for manual review.
    if 'setInfectionLevel' in line:
        line = line.rstrip() + '  -- FIXME: setInfectionLevel removed in B42.16, use stats:set(CharacterStat.ZOMBIE_INFECTION, v)\n'
    return line


def replace_bd_wetness(content):
    """
    Replace bd:getWetness()/bd:setWetness() where bd is from player:getBodyDamage().
    These need to use stats:get(CharacterStat.WETNESS) instead.
    
    This is context-dependent, so we handle it per-file.
    """
    # Pattern: local wetness = bd:getWetness()  →  local wetness = stats:get(CharacterStat.WETNESS)
    # But we need to know what 'bd' is. We'll look for the pattern where bd is from getBodyDamage.
    # For now, just do the simple replacement since all our usages follow the same pattern.
    content = re.sub(r'(\w+):getWetness\(\)', r'stats:get(CharacterStat.WETNESS)', content)
    content = re.sub(r'(\w+):setWetness\(([^)]+)\)', r'stats:set(CharacterStat.WETNESS, \2)', content)
    return content


def replace_unhappiness_level(content):
    """Replace body:getUnhappinessLevel() / body:setUnhappinessLevel(v)
    These were on BodyDamage, now use stats:get/set(CharacterStat.UNHAPPINESS)"""
    content = re.sub(r'(\w+):getUnhappinessLevel\(\)', r'stats:get(CharacterStat.UNHAPPINESS)', content)
    content = re.sub(r'(\w+):setUnhappinessLevel\(([^)]+)\)', r'stats:set(CharacterStat.UNHAPPINESS, \2)', content)
    return content


def replace_panic_level(content):
    """Replace bodyDamage:getPanicLevel() → stats:get(CharacterStat.PANIC)"""
    content = re.sub(r'(\w+):getPanicLevel\(\)', r'stats:get(CharacterStat.PANIC)', content)
    return content


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()
    
    lines = original.split('\n')
    new_lines = []
    for line in lines:
        line = replace_stat_getters(line)
        line = replace_stat_setters(line)
        line = replace_sleeping(line)
        line = replace_getmaxendurance(line)
        line = replace_infection_level(line)
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    
    # Context-dependent replacements on full content
    content = replace_bd_wetness(content)
    content = replace_unhappiness_level(content)
    content = replace_panic_level(content)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False


def main():
    changed = []
    skipped = []
    
    # Process all trait files
    trait_files = glob.glob(os.path.join(TRAITS_DIR, "*.lua"))
    for f in sorted(trait_files):
        if process_file(f):
            changed.append(f)
        else:
            skipped.append(f)
    
    # Process UTCore files
    utcore_files = glob.glob(os.path.join(UTCORE_DIR, "*.lua"))
    for f in sorted(utcore_files):
        if process_file(f):
            changed.append(f)
        else:
            skipped.append(f)
    
    print(f"\n=== B42.16 Stats Migration Complete ===")
    print(f"Changed: {len(changed)} files")
    print(f"Unchanged: {len(skipped)} files")
    
    if changed:
        print("\nModified files:")
        for f in changed:
            print(f"  {f}")
    
    # Check for FIXME markers (manual review needed)
    fixme_files = []
    for f in changed:
        with open(f, 'r', encoding='utf-8') as fh:
            if 'FIXME: setInfectionLevel' in fh.read():
                fixme_files.append(f)
    
    if fixme_files:
        print(f"\n⚠ Files needing manual review (setInfectionLevel):")
        for f in fixme_files:
            print(f"  {f}")


if __name__ == '__main__':
    main()
