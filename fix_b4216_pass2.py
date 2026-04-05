"""
B42.16 Stats Migration: Pass 2 — Fix scope, infection, scale, and missed replacements.

This script handles issues the automated regex pass couldn't:
1. Scope bugs: stats variable referenced but never defined
2. setInfectionLevel removal: use stats:set(CharacterStat.ZOMBIE_INFECTION, v)
3. Scale changes: PANIC (was 0-1, now 0-100), INTOXICATION (was 0-1, now 0-100), WETNESS (was 0-1, now 0-100)
4. UTCore_ReadingHook: dead guards and removed BodyDamage methods
5. UT_flailer: getPanicLevel() not caught by regex
"""

import os

TRAITS = os.path.join("UniversalTraits", "media", "lua", "shared", "UniversalTraits", "traits")
UTCORE = os.path.join("UT_CORE", "media", "lua", "shared", "UTCore")


def fix_file(filepath, old, new):
    """Replace exact string old with new in file. Returns True if changed."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if old not in content:
        print(f"  WARNING: expected text not found in {filepath}")
        print(f"    Looking for: {old!r}")
        return False
    if content.count(old) > 1:
        print(f"  WARNING: multiple matches in {filepath}, replacing all")
    content = content.replace(old, new)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    return True


def main():
    changes = 0
    
    # ===== 1. SCOPE FIXES (add missing 'local stats = player:getStats()') =====
    print("\n=== Scope Fixes ===")
    
    # UT_lesssweaty.lua — bd is defined but stats is not
    f = os.path.join(TRAITS, "UT_lesssweaty.lua")
    if fix_file(f,
        "    local bd = player:getBodyDamage()\n    if not bd then return end\n    local wetness = stats:get(CharacterStat.WETNESS)",
        "    local stats = player:getStats()\n    local wetness = stats:get(CharacterStat.WETNESS)"):
        print(f"  Fixed {f}: added stats var, removed unused bd")
        changes += 1
    
    # UT_melancholic.lua — body is defined but stats is not
    f = os.path.join(TRAITS, "UT_melancholic.lua")
    if fix_file(f,
        "    local body = player:getBodyDamage()\n    stats:set(CharacterStat.UNHAPPINESS",
        "    local stats = player:getStats()\n    stats:set(CharacterStat.UNHAPPINESS"):
        print(f"  Fixed {f}: added stats var, removed unused body")
        changes += 1
    
    # UT_pacer.lua — stats used inside pcall but never defined
    f = os.path.join(TRAITS, "UT_pacer.lua")
    if fix_file(f,
        "        pcall(function()\n            local bd = player:getBodyDamage()\n            stats:set(CharacterStat.UNHAPPINESS, math.min(100, stats:get(CharacterStat.UNHAPPINESS) + 2))\n        end)",
        "        pcall(function()\n            local stats = player:getStats()\n            stats:set(CharacterStat.UNHAPPINESS, math.min(100, stats:get(CharacterStat.UNHAPPINESS) + 2))\n        end)"):
        print(f"  Fixed {f}: added stats var inside pcall, removed unused bd")
        changes += 1
    
    # UT_flailer.lua — getPanicLevel() not caught by regex (chained call)  
    f = os.path.join(TRAITS, "UT_flailer.lua")
    if fix_file(f,
        "    local panicLevel = 0\n    pcall(function()\n        panicLevel = player:getBodyDamage():getPanicLevel()\n    end)",
        "    local panicLevel = 0\n    pcall(function()\n        panicLevel = player:getStats():get(CharacterStat.PANIC)\n    end)"):
        print(f"  Fixed {f}: getPanicLevel → CharacterStat.PANIC")
        changes += 1
    
    # ===== 2. INFECTION FIXES (setInfectionLevel removed) =====
    print("\n=== Infection Fixes ===")
    
    # UT_immuneresponse.lua
    f = os.path.join(TRAITS, "UT_immuneresponse.lua")
    if fix_file(f,
        "            bodyDamage:setInfectionLevel(math.max(0, infectionLevel - 0.03))  -- FIXME: setInfectionLevel removed in B42.16, use stats:set(CharacterStat.ZOMBIE_INFECTION, v)\n",
        "            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, math.max(0, infectionLevel - 3))\n"):
        print(f"  Fixed {f}: setInfectionLevel → stats:set(ZOMBIE_INFECTION)")
        changes += 1
    
    # UT_immunocompromised.lua
    f = os.path.join(TRAITS, "UT_immunocompromised.lua")
    if fix_file(f,
        "            bodyDamage:setInfectionLevel(math.min(1, infectionLevel + 0.01))  -- FIXME: setInfectionLevel removed in B42.16, use stats:set(CharacterStat.ZOMBIE_INFECTION, v)\n",
        "            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, math.min(100, infectionLevel + 1))\n"):
        print(f"  Fixed {f}: setInfectionLevel → stats:set(ZOMBIE_INFECTION)")
        changes += 1
    
    # UT_superimmune.lua
    f = os.path.join(TRAITS, "UT_superimmune.lua")
    if fix_file(f,
        "            bodyDamage:setInfectionLevel(math.max(0, infectionLevel - 0.02))  -- FIXME: setInfectionLevel removed in B42.16, use stats:set(CharacterStat.ZOMBIE_INFECTION, v)\n",
        "            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, math.max(0, infectionLevel - 2))\n"):
        print(f"  Fixed {f}: setInfectionLevel → stats:set(ZOMBIE_INFECTION)")
        changes += 1
    
    # ===== 3. SCALE FIXES: PANIC (was 0-1, now 0-100) =====
    print("\n=== Panic Scale Fixes (0-1 → 0-100) ===")
    
    # UT_acrophobic.lua
    f = os.path.join(TRAITS, "UT_acrophobic.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.05))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 5))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # UT_alcoholic_III.lua — panic line
    f = os.path.join(TRAITS, "UT_alcoholic_III.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.03))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 3))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # UT_fearofthedark.lua — two panic lines
    f = os.path.join(TRAITS, "UT_fearofthedark.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.04))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 4))"):
        print(f"  Fixed {f}: panic add scale ×100")
        changes += 1
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - 0.01))",
        "stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - 1))"):
        print(f"  Fixed {f}: panic reduce scale ×100")
        changes += 1
    
    # UT_optimist.lua — panic line
    f = os.path.join(TRAITS, "UT_optimist.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - 0.04))",
        "stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - 4))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # UT_panicattacks.lua
    f = os.path.join(TRAITS, "UT_panicattacks.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.4))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 40))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # UT_paranoia.lua
    f = os.path.join(TRAITS, "UT_paranoia.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.06))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 6))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # UT_scardycat.lua — threshold and add
    f = os.path.join(TRAITS, "UT_scardycat.lua")
    if fix_file(f,
        "if prev ~= nil and (current - prev) >= 0.05 then\n        stats:set(CharacterStat.PANIC, math.min(1, current + 0.15))",
        "if prev ~= nil and (current - prev) >= 5 then\n        stats:set(CharacterStat.PANIC, math.min(100, current + 15))"):
        print(f"  Fixed {f}: panic threshold and delta ×100")
        changes += 1
    
    # UT_unwavering.lua
    f = os.path.join(TRAITS, "UT_unwavering.lua")
    if fix_file(f,
        "if panic > 0.1 then\n        stats:set(CharacterStat.PANIC, math.max(0, panic - 0.1))",
        "if panic > 10 then\n        stats:set(CharacterStat.PANIC, math.max(0, panic - 10))"):
        print(f"  Fixed {f}: panic threshold and delta ×100")
        changes += 1
    
    # UT_vehophobic.lua
    f = os.path.join(TRAITS, "UT_vehophobic.lua")
    if fix_file(f,
        "stats:set(CharacterStat.PANIC, math.min(1, stats:get(CharacterStat.PANIC) + 0.01))",
        "stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 1))"):
        print(f"  Fixed {f}: panic scale ×100")
        changes += 1
    
    # ===== 4. SCALE FIXES: INTOXICATION (was 0-1 drunkenness, now 0-100) =====
    print("\n=== Intoxication Scale Fixes (0-1 → 0-100) ===")
    
    # UT_alcoholic_I.lua
    f = os.path.join(TRAITS, "UT_alcoholic_I.lua")
    if fix_file(f,
        "stats:get(CharacterStat.INTOXICATION) < 0.05",
        "stats:get(CharacterStat.INTOXICATION) < 5"):
        print(f"  Fixed {f}: intoxication threshold ×100")
        changes += 1
    
    # UT_alcoholic_II.lua
    f = os.path.join(TRAITS, "UT_alcoholic_II.lua")
    if fix_file(f,
        "stats:get(CharacterStat.INTOXICATION) < 0.05",
        "stats:get(CharacterStat.INTOXICATION) < 5"):
        print(f"  Fixed {f}: intoxication threshold ×100")
        changes += 1
    
    # UT_alcoholic_III.lua — two thresholds
    f = os.path.join(TRAITS, "UT_alcoholic_III.lua")
    if fix_file(f,
        "if drunkenness < 0.1 then",
        "if drunkenness < 10 then"):
        print(f"  Fixed {f}: intoxication threshold 0.1→10")
        changes += 1
    if fix_file(f,
        "if drunkenness < 0.05 then",
        "if drunkenness < 5 then"):
        print(f"  Fixed {f}: intoxication threshold 0.05→5")
        changes += 1
    
    # UT_ironliver.lua — multiplicative (0.9x) is scale-independent, but threshold needs fix
    f = os.path.join(TRAITS, "UT_ironliver.lua")
    if fix_file(f,
        "if drunkenness > 0.1 then",
        "if drunkenness > 10 then"):
        print(f"  Fixed {f}: intoxication threshold 0.1→10")
        changes += 1
    
    # ===== 5. SCALE FIXES: WETNESS (was 0-1, now 0-100) =====
    print("\n=== Wetness Scale Fixes (0-1 → 0-100) ===")
    
    # UT_highsweaty.lua
    f = os.path.join(TRAITS, "UT_highsweaty.lua")
    if fix_file(f,
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 0.05, 1.0))\n        stats:add(CharacterStat.THIRST, 0.03)",
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 5, 100))\n        stats:add(CharacterStat.THIRST, 0.03)"):
        print(f"  Fixed {f}: sprint wetness ×100")
        changes += 1
    if fix_file(f,
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 0.03, 1.0))\n        stats:add(CharacterStat.THIRST, 0.02)",
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 3, 100))\n        stats:add(CharacterStat.THIRST, 0.02)"):
        print(f"  Fixed {f}: run wetness ×100")
        changes += 1
    if fix_file(f,
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 0.01, 1.0))",
        "stats:set(CharacterStat.WETNESS, math.min(wetness + 1, 100))"):
        print(f"  Fixed {f}: walk wetness ×100")
        changes += 1
    if fix_file(f,
        "stats:set(CharacterStat.WETNESS, math.min(stats:get(CharacterStat.WETNESS) + 0.02, 1.0))",
        "stats:set(CharacterStat.WETNESS, math.min(stats:get(CharacterStat.WETNESS) + 2, 100))"):
        print(f"  Fixed {f}: combat wetness ×100")
        changes += 1
    
    # UT_lesssweaty.lua
    f = os.path.join(TRAITS, "UT_lesssweaty.lua")
    if fix_file(f,
        "    local reduction = 0.03\n    if player:isOutside() and isRaining() then\n        reduction = 0.005\n    elseif player:isOutside() then\n        reduction = 0.015",
        "    local reduction = 3\n    if player:isOutside() and isRaining() then\n        reduction = 0.5\n    elseif player:isOutside() then\n        reduction = 1.5"):
        print(f"  Fixed {f}: wetness reduction ×100")
        changes += 1
    
    # ===== 6. UTCore_ReadingHook fixes =====
    print("\n=== UTCore_ReadingHook Fixes ===")
    f = os.path.join(UTCORE, "UTCore_ReadingHook.lua")
    
    # Fix dead guards: stats.setPanic/stats.setStress no longer exist as named methods
    if fix_file(f,
        "    if md[\"UT_readCalm\"] then\n        if stats.setPanic then stats:set(CharacterStat.PANIC, 0) end\n        if stats.setStress then stats:set(CharacterStat.STRESS, 0) end\n    end",
        "    if md[\"UT_readCalm\"] then\n        stats:set(CharacterStat.PANIC, 0)\n        stats:set(CharacterStat.STRESS, 0)\n    end"):
        print(f"  Fixed {f}: removed dead stats.setPanic/setStress guards")
        changes += 1
    
    # Fix getBoredomLevel/setBoredomLevel → stats:get/set(CharacterStat.BOREDOM)
    if fix_file(f,
        "    if bd.getBoredomLevel and bd.setBoredomLevel then\n        local boredom = bd:getBoredomLevel()\n        bd:setBoredomLevel(clampMinZero(boredom - (moodBonus * scale)))\n    end",
        "    local boredom = stats:get(CharacterStat.BOREDOM)\n    stats:set(CharacterStat.BOREDOM, clampMinZero(boredom - (moodBonus * scale)))"):
        print(f"  Fixed {f}: getBoredomLevel → CharacterStat.BOREDOM")
        changes += 1
    
    # Fix getUnhappinessLevel/setUnhappinessLevel → stats:get/set(CharacterStat.UNHAPPINESS)
    if fix_file(f,
        "    local getUnhappy = bd.getUnhappinessLevel or bd.getUnhappynessLevel\n    local setUnhappy = bd.setUnhappinessLevel or bd.setUnhappynessLevel\n    if getUnhappy and setUnhappy then\n        local unhappy = getUnhappy(bd)\n        setUnhappy(bd, clampMinZero(unhappy - (moodBonus * scale)))\n    end",
        "    local unhappy = stats:get(CharacterStat.UNHAPPINESS)\n    stats:set(CharacterStat.UNHAPPINESS, clampMinZero(unhappy - (moodBonus * scale)))"):
        print(f"  Fixed {f}: getUnhappinessLevel → CharacterStat.UNHAPPINESS")
        changes += 1
    
    print(f"\n=== Pass 2 Complete: {changes} fixes applied ===")


if __name__ == '__main__':
    main()
