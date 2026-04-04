import re

path = r'C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI_EN.txt'
with open(path, encoding='utf-8') as f:
    content = f.read()

p1 = r'UI_UT_physicallyactiveDesc\s*=\s*"[^"]+",'
r1 = 'UI_UT_physicallyactiveDesc  = "You have always pushed your body and it pays off. Gain \u00d72 XP in Fitness and Sprinting. During exercise, stress and boredom steadily decrease. At Fitness level 10, gym exercises cost no endurance.",'

p2 = r'UI_UT_gunspecialist_IIIDesc\s*=\s*"[^"]+",'
r2 = 'UI_UT_gunspecialist_IIIDesc = "Firearms are an extension of yourself. Gain \u00d73 XP in Aiming and Reloading, and \u00d72 XP in Nimbleness. Reload time and aim time are each reduced by 10%. Equipped weapons never jam.",'

content, n1 = re.subn(p1, r1, content)
content, n2 = re.subn(p2, r2, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'phys={n1} gs3={n2} done')
