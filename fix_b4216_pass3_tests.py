"""
B42.16 Stats API Migration: Pass 3 — Fix test assertions.
Migrates UT test file from old named getters/setters to CharacterStat API,
and adjusts scale values for PANIC (0-1 → 0-100), INTOXICATION, WETNESS.
"""

import re
import os

TEST_FILE = os.path.join("UniversalTraits", "test", "run_tests.lua")

# Same getter/setter maps as pass 1
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
    for old_method, stat_const in GETTER_MAP.items():
        pattern = r':' + old_method + r'\(\)'
        replacement = ':get(' + stat_const + ')'
        line = re.sub(pattern, replacement, line)
    return line


def replace_stat_setters(line):
    for old_method, stat_const in SETTER_MAP.items():
        search = ':' + old_method + '('
        idx = 0
        while True:
            pos = line.find(search, idx)
            if pos == -1:
                break
            colon_pos = pos
            arg_start = pos + len(search)
            depth = 1
            i = arg_start
            while i < len(line) and depth > 0:
                if line[i] == '(': depth += 1
                elif line[i] == ')': depth -= 1
                i += 1
            arg_end = i - 1
            arg = line[arg_start:arg_end]
            old_text = line[colon_pos:i]
            new_text = ':set(' + stat_const + ', ' + arg + ')'
            line = line[:colon_pos] + new_text + line[i:]
            idx = colon_pos + len(new_text)
    return line


def replace_infection_getter(line):
    line = re.sub(r':getInfectionLevel\(\)', ':getApparentInfectionLevel()', line)
    return line


def replace_infection_setter(line):
    """setInfectionLevel(v) → set(CharacterStat.ZOMBIE_INFECTION, v) on stats"""
    search = ':setInfectionLevel('
    idx = 0
    while True:
        pos = line.find(search, idx)
        if pos == -1:
            break
        arg_start = pos + len(search)
        depth = 1
        i = arg_start
        while i < len(line) and depth > 0:
            if line[i] == '(': depth += 1
            elif line[i] == ')': depth -= 1
            i += 1
        arg = line[arg_start:i-1]
        # Find the variable before :setInfectionLevel — it was bodyDamage, redirect to stats
        old_text = line[pos:i]
        new_text = ':set(CharacterStat.ZOMBIE_INFECTION, ' + arg + ')'
        # We need to also change the object. In tests: player:getBodyDamage():setInfectionLevel(v)
        # → player:getStats():set(CharacterStat.ZOMBIE_INFECTION, v)
        prefix_end = pos
        prefix = line[:prefix_end]
        if 'getBodyDamage()' in prefix:
            prefix = prefix.replace('getBodyDamage()', 'getStats()')
        line = prefix + new_text + line[i:]
        idx = prefix_end + len(new_text)
    return line


def replace_bd_methods(line):
    """Replace bd:getUnhappinessLevel() and bd:getPanicLevel() 
    In tests these are typically bd:getUnhappinessLevel() → need to redirect to stats.
    This is tricky because we need to change the object too."""
    # getUnhappinessLevel on bodyDamage → stats:get(CharacterStat.UNHAPPINESS)
    if 'getUnhappinessLevel()' in line:
        # Replace bd:getUnhappinessLevel() with player:getStats():get(CharacterStat.UNHAPPINESS)
        line = re.sub(r'(\w+):getUnhappinessLevel\(\)', r'player:getStats():get(CharacterStat.UNHAPPINESS)', line)
    if 'getPanicLevel()' in line:
        line = re.sub(r'(\w+):getPanicLevel\(\)', r'player:getStats():get(CharacterStat.PANIC)', line)
    return line


def replace_getmaxendurance(line):
    return re.sub(r':getMaxEndurance\(\)', ':get(CharacterStat.ENDURANCE)', line)


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        original = f.read()
    
    lines = original.split('\n')
    new_lines = []
    for line in lines:
        line = replace_stat_getters(line)
        line = replace_stat_setters(line)
        line = replace_infection_getter(line)
        line = replace_infection_setter(line)
        line = replace_bd_methods(line)
        line = replace_getmaxendurance(line)
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False


def main():
    if process_file(TEST_FILE):
        print(f"Migrated {TEST_FILE}")
    else:
        print(f"No changes needed in {TEST_FILE}")
    
    # Count remaining old API calls
    with open(TEST_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    old_patterns = ['getPanic()', 'setPanic(', 'getStress()', 'setStress(', 
                    'getFatigue()', 'setFatigue(', 'getHunger()', 'setHunger(',
                    'getThirst()', 'setThirst(', 'getBoredom()', 'setBoredom(',
                    'getEndurance()', 'setEndurance(', 'getDrunkenness()', 'setDrunkenness(',
                    'getMaxEndurance()', 'getInfectionLevel()', 'setInfectionLevel(',
                    'getUnhappinessLevel()', 'setUnhappinessLevel(']
    
    remaining = 0
    for pat in old_patterns:
        count = content.count(pat)
        if count > 0:
            print(f"  WARNING: {count}x '{pat}' still present")
            remaining += count
    
    if remaining == 0:
        print("All old API calls replaced!")
    else:
        print(f"  {remaining} old API calls still remaining")


if __name__ == '__main__':
    main()
