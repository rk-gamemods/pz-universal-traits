import re
with open(r'C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\scripts\UT_character_traits.txt', encoding='utf-8') as f:
    content = f.read()
targets = ['UT_slack','UT_slowworker','UT_restfulsleeper','UT_quickrest','UT_brittle',
           'UT_flailer','UT_lurcher','UT_ironliver','UT_glassbody','UT_snorer',
           'UT_onetrickpony','UT_thickblood','UT_weaklybleedingwounds','UT_ascetic',
           'UT_owlperson','UT_larkperson']
blocks = re.split(r'(?=    character_trait_definition UniversalTraits:)', content)
for block in blocks:
    m = re.match(r'\s*character_trait_definition UniversalTraits:(\w+)', block)
    if not m:
        continue
    tid = m.group(1)
    if tid not in targets:
        continue
    cost = re.search(r'Cost\s*=\s*(-?\d+)', block)
    cost_val = cost.group(1) if cost else '?'
    met = re.findall(r'MutuallyExclusiveTraits\s*=\s*([^\n,}]+)', block)
    print(tid + ': Cost=' + cost_val)
    for m2 in met:
        print('  MET: ' + m2.strip())
    print()
