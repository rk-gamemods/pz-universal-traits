"""Fix _charStatAccum string keys to CharacterStat references in UT tests"""
f = "UniversalTraits/test/run_tests.lua"
with open(f, "r", encoding="utf-8") as fh:
    c = fh.read()

reps = {
    '_charStatAccum["Fatigue"]': '_charStatAccum[CharacterStat.FATIGUE]',
    '_charStatAccum["Unhappiness"]': '_charStatAccum[CharacterStat.UNHAPPINESS]',
    '_charStatAccum["Boredom"]': '_charStatAccum[CharacterStat.BOREDOM]',
    '_charStatAccum["Stress"]': '_charStatAccum[CharacterStat.STRESS]',
    '_charStatAccum["Hunger"]': '_charStatAccum[CharacterStat.HUNGER]',
}
for old, new in reps.items():
    cnt = c.count(old)
    print(f"{old} => {new}: {cnt} replacements")
    c = c.replace(old, new)

with open(f, "w", encoding="utf-8") as fh:
    fh.write(c)
print("Done")
