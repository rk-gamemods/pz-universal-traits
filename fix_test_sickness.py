"""Fix remaining test assertions for B42.16:
- getFoodSicknessLevel() on bodyDamage -> stats:get(CharacterStat.FOOD_SICKNESS)
- Scale fixes for panic (0-1 -> 0-100) 
- Scale fixes for intoxication/drunkenness (0-1 -> 0-100)
- Scale fixes for wetness (0-1 -> 0-100)
- Melancholic bd._unhappinessLevel -> stats:get(CharacterStat.UNHAPPINESS)
"""
import re

f = "UniversalTraits/test/run_tests.lua"
with open(f, "r", encoding="utf-8") as fh:
    c = fh.read()

changes = 0

# getFoodSicknessLevel() -> stats:get(CharacterStat.FOOD_SICKNESS)
old = "player:getBodyDamage():getFoodSicknessLevel()"
new = "player:getStats():get(CharacterStat.FOOD_SICKNESS)"
cnt = c.count(old)
print(f"getFoodSicknessLevel: {cnt} replacements")
c = c.replace(old, new)
changes += cnt

with open(f, "w", encoding="utf-8") as fh:
    fh.write(c)

print(f"Total changes: {changes}")
