import json

path = r'C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI.json'
with open(path, encoding='utf-8') as f:
    content = json.load(f)

content['UI_UT_physicallyactiveDesc'] = (
    'You have always pushed your body and it pays off. Gain ×2 XP in Fitness and '
    'Sprinting. During exercise, stress and boredom steadily decrease. At Fitness '
    'level 10, gym exercises cost no endurance.'
)
content['UI_UT_gunspecialist_IIIDesc'] = (
    'Firearms are an extension of yourself. Gain ×3 XP in Aiming and Reloading, '
    'and ×2 XP in Nimbleness. Reload time and aim time are each reduced by 10%. '
    'Equipped weapons never jam.'
)

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(content, f, ensure_ascii=False, indent=4)
    f.write('\n')

print('updated UI.json entries')
