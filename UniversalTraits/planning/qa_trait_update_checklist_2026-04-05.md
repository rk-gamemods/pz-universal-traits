# UniversalTraits Trait Update QA Checklist (2026-04-05)

This file records the exact state of the current trait-update batch using direct evidence from source files, release files, live mod files, tests, and the latest available Project Zomboid log.

## Scope

Reviewed traits from the current batch:

- UT_antique
- UT_scrounger
- UT_cleaver
- UT_improviser
- UT_natural
- UT_woodsplitter
- UT_wildsman
- UT_evasive
- UT_prospear
- UT_graverobber
- UT_sharpshooter
- UT_gordanite
- UT_axes
- UT_trackman
- UT_taut
- UT_onehanded_axes
- UT_blissful
- UT_tavernbrawler
- UT_flexible
- UT_strongnimble
- UT_paramedic
- UT_twohanded_blunts
- UT_long_blunts
- UT_pitcrew
- UT_gymgoer
- UT_twohanded_axes
- UT_marathonrunner
- UT_olympian
- UT_blunttwirl
- UT_trekker
- UT_long_blades
- UT_bladetwirl
- UT_twohanded_blades

## Headline Status

| Check | Status | Evidence |
| --- | --- | --- |
| Source UI.json exists | PASS | UniversalTraits/media/lua/shared/Translate/EN/UI.json exists |
| Release UI.json exists | PASS | UniversalTraits/release/UniversalTraits/42/media/lua/shared/Translate/EN/UI.json exists |
| Live UI.json exists | PASS | C:\Users\Admin\Zomboid\mods\UniversalTraits\42\media\lua\shared\Translate\EN\UI.json exists |
| UI.json source/release/live hashes match | PASS | All three copies hash to 3FE6157571442D14EC5BAA71623D37C500090CC14181DA3A31FC4D191EA4433A |
| Trait script source/release/live hashes match | PASS | All three copies of UT_character_traits.txt hash to D1C6067802D0EABFB01B19E0FD269D69C51BB3163C85E214B23CF2FB95295C5F |
| UT_items.txt exists in source/release/live | PASS | Present in all three locations |
| Antique clothing assets exist in source/release/live | PASS | Jacket_Antique.xml present in all three locations |
| UniversalTraits enabled in default.txt | PASS | C:\Users\Admin\Zomboid\mods\default.txt contains mod = UniversalTraits |
| UT_CORE enabled in default.txt | PASS | C:\Users\Admin\Zomboid\mods\default.txt contains mod = UT_CORE |
| Latest available game log loaded UniversalTraits | PASS | Latest debug log contains loading UT_CORE and loading UniversalTraits |
| Latest available game log saw translation override | PASS | Latest debug log line: mod "UniversalTraits" overrides media/lua/shared/translate/en/ui.json |
| Current live UI.json has been validated by a game launch after this deploy | FAIL | Latest available debug log is 2026-04-05 17:05, but live UI.json last-write is 2026-04-05 18:17. No later game log was found. |
| poster.png exists in source package | FAIL | UniversalTraits/poster.png is missing |
| poster.png exists in release root package | FAIL | UniversalTraits/release/UniversalTraits/poster.png is missing |
| poster.png exists in live root package | FAIL | C:\Users\Admin\Zomboid\mods\UniversalTraits\poster.png is missing |
| poster.png exists in release versioned package | FAIL | UniversalTraits/release/UniversalTraits/42/poster.png is missing |
| poster.png exists in live versioned package | FAIL | C:\Users\Admin\Zomboid\mods\UniversalTraits\42\poster.png is missing |
| UT_CORE tests pass | PASS | 155 passed, 0 failed |
| UniversalTraits tests pass | PASS | 232 passed, 0 failed |
| Behavior-specific automated coverage added for most changed traits | FAIL | Exact trait-id search shows most reviewed traits appear only once in test files, which is the generic registration list. |

## Game-Load Evidence

Latest available debug log file found:

- C:\Users\Admin\Zomboid\Logs\logs_2026-04-05\2026-04-05_17-05_DebugLog.txt

Relevant lines found in that log:

- line 15930: loading UT_CORE.
- line 15932: loading UniversalTraits.
- line 15934: mod "UniversalTraits" overrides media/lua/shared/translate/en/ui.json.
- line 15935: mod "UniversalTraits" overrides media/registries.lua.

Important limitation:

- The current live UI.json was written at 18:17.
- The newest available debug log is from 17:05.
- That means the currently deployed translation file has not yet been proven to load in a post-deploy game session.

## Per-Trait Matrix

Meaning of ExactTestRefs:

- 1 = found only in the generic registration/integrity list
- 2 or more = at least one additional exact trait-id-specific reference exists

| Trait | Source Lua | Release Lua | Live Lua | Registered | Script Block | UI Name Key | UI Desc Key | ExactTestRefs | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UT_antique | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_scrounger | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_cleaver | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_improviser | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_natural | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_woodsplitter | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_wildsman | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_evasive | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_prospear | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_graverobber | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_sharpshooter | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_gordanite | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_axes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 2 | One extra exact UT_axes reference exists in UT_CORE tests |
| UT_trackman | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_taut | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_onehanded_axes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_blissful | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_tavernbrawler | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_flexible | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_strongnimble | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_paramedic | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_twohanded_blunts | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_long_blunts | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_pitcrew | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_gymgoer | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_twohanded_axes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_marathonrunner | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_olympian | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_blunttwirl | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_trekker | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_long_blades | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |
| UT_bladetwirl | No | No | No | Yes | Yes | Yes | Yes | 1 | Script-only trait; no Lua file present |
| UT_twohanded_blades | Yes | Yes | Yes | Yes | Yes | Yes | Yes | 1 | Runtime file present |

## What This Checklist Proves

It proves all of these points:

- The changed translation file is present in source, release, and live.
- The changed trait script file is present in source, release, and live.
- The active mod list includes UT_CORE and UniversalTraits.
- The latest available game log did load UniversalTraits and did see the translation override path.
- The changed runtime trait Lua files are present in live for the reviewed runtime traits.

It does not prove these points yet:

- That the current 18:17 live UI.json has been loaded by a new game session.
- That the player-facing descriptions now render correctly in the UI after the latest deploy.
- That the missing poster asset is harmless for this package layout.
- That the new behaviors are protected by focused automated tests.

## Next Required Validation Step

To validate the current deploy rather than an older session, the game must be fully restarted after the 18:17 deploy and a new debug log must be produced. Then re-check:

- whether the new debug log is newer than the current live UI.json timestamp
- whether the log still shows UniversalTraits overriding media/lua/shared/translate/en/ui.json
- whether the trait descriptions render in character creation