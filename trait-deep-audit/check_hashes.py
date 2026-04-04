import hashlib, os

def h(f):
    return hashlib.md5(open(f, 'rb').read()).hexdigest()

checks = [
    (r'UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_scardycat.lua',
     r'UniversalTraits\release\UniversalTraits\42\media\lua\shared\UniversalTraits\traits\UT_scardycat.lua'),
    (r'UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_butterfingers.lua',
     r'UniversalTraits\release\UniversalTraits\42\media\lua\shared\UniversalTraits\traits\UT_butterfingers.lua'),
    (r'UniversalTraits\media\lua\shared\Translate\EN\UI_EN.txt',
     r'UniversalTraits\release\UniversalTraits\42\media\lua\shared\Translate\EN\UI_EN.txt'),
    (r'UniversalTraits\media\lua\shared\UniversalTraits\UT_ItemConsumptionHooks.lua',
     r'UniversalTraits\release\UniversalTraits\42\media\lua\shared\UniversalTraits\UT_ItemConsumptionHooks.lua'),
    (r'UT_CORE\media\lua\shared\UTCore\UTCore_XPHook.lua',
     r'UT_CORE\release\UT_CORE\42\media\lua\shared\UTCore\UTCore_XPHook.lua'),
]

for src, rel in checks:
    if not os.path.exists(src):
        print(os.path.basename(src), 'SRC MISSING')
    elif not os.path.exists(rel):
        print(os.path.basename(src), 'REL MISSING')
    else:
        m = h(src) == h(rel)
        print(os.path.basename(src), 'OK' if m else 'MISMATCH')
