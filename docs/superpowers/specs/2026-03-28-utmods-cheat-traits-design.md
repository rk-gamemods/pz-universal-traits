# UTMods Cheat Traits & Sandbox Settings — Design Spec

**Date:** 2026-03-28
**Project:** UniversalTraits / UT_CORE (Project Zomboid B42)
**Status:** Approved

---

## Context

UTMods has 199 registered traits across three implementation phases. This spec adds a fourth category: `UT_CHEAT_*` — opt-in cheat traits hidden by default behind a sandbox toggle. These serve two purposes:

1. **Testing convenience** — extra character creation points let you load more mods and reach edge cases without creating new games repeatedly.
2. **Player choice** — single-player mods have no obligation to be balanced. Some players want a God Mode or No Hunger toggle, and that's a legitimate use of the trait system.

All cheat traits are hidden from the character creation screen unless the player explicitly enables them in sandbox settings. Default: off.

---

## Trait Catalog

**Total: 10 new traits.** All use the `UT_CHEAT_` prefix. All have `DisabledInMultiplayer = true`.

### Free Points (3 traits)

| Trait ID                  | Display Name    | Cost field | Effect                                             |
| ------------------------- | --------------- | ---------- | -------------------------------------------------- |
| `UT_CHEAT_points100`      | Free Points I   | `-100`     | +100 character creation points; no gameplay effect |
| `UT_CHEAT_points200`      | Free Points II  | `-200`     | +200 character creation points; no gameplay effect |
| `UT_CHEAT_points300`      | Free Points III | `-300`     | +300 character creation points; no gameplay effect |

**Implementation:** Script-only. Negative `Cost` in PZ's trait system grants points. No Lua effect file needed. These replace the `threehundredpoints` mod once live.

### God Mode (1 trait)

| Trait ID             | Display Name | Cost | Effect                                                                        |
| -------------------- | ------------ | ---- | ----------------------------------------------------------------------------- |
| `UT_CHEAT_godmode`   | God Mode     | `0`  | All body parts permanently at max health; Knox infection flag cleared each tick |

**Implementation:** `Events.OnPlayerUpdate` throttled handler (every 30 ticks). Sets all body part health to max via `getBodyDamage()` iteration. Clears infection via `player:getBodyDamage():setInfected(false)` or equivalent B42 call. Writes `UT_CHEAT_godmode = true` to moddata at `OnNewGame`; handler checks that flag.

### Max Skills (1 trait)

| Trait ID               | Display Name | Cost | Effect                             |
| ---------------------- | ------------ | ---- | ---------------------------------- |
| `UT_CHEAT_maxskills`   | Max Skills   | `0`  | All skills start at level 10 at spawn |

**Implementation:** `Events.OnNewGame` handler. Iterates all entries in the `Perks` table and calls `player:getXp():setXPLevel(perk, 10)` for each. Fires once; no periodic tick needed.

### No Needs (5 traits)

Each trait suppresses one survival stat. They are independent — a player can take just No Hunger without suppressing fatigue.

| Trait ID                      | Display Name    | Cost | Stat zeroed                            |
| ----------------------------- | --------------- | ---- | -------------------------------------- |
| `UT_CHEAT_noneed_hunger`      | No Hunger       | `0`  | `player:getStats():setHunger(0)`       |
| `UT_CHEAT_noneed_thirst`      | No Thirst       | `0`  | `player:getStats():setThirst(0)`       |
| `UT_CHEAT_noneed_fatigue`     | No Fatigue      | `0`  | `player:getStats():setFatigue(0)`      |
| `UT_CHEAT_noneed_boredom`     | No Boredom      | `0`  | `player:getStats():setBoredom(0)`      |
| `UT_CHEAT_noneed_unhappy`     | No Unhappiness  | `0`  | `player:getStats():setUnhappyness(0)`  |

**Implementation:** Single shared `Events.OnPlayerUpdate` throttled handler (every 30 ticks) in `UTCore_CheatHook.lua`. Checks moddata for each of the five `UT_CHEAT_noneed_*` flags and zeroes the corresponding stat for any that are active. One handler registration, not five.

---

## Architecture

### New files

| Action | File                                                                    | Responsibility                                                                      |
| ------ | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| CREATE | `UniversalTraits/media/scripts/UT_cheat_traits.txt`                     | Script definitions for all 10 `UT_CHEAT_*` traits                                  |
| CREATE | `UniversalTraits/media/sandbox-options.txt`                             | Declares the `UniversalTraits_Cheats` sandbox page and `EnableCheatTraits` boolean  |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_CheatHook.lua`                  | `OnGameBoot` visibility gate + `OnNewGame`/`OnPlayerUpdate` effect handlers         |
| CREATE | `UniversalTraits/media/lua/shared/Translate/EN/Sandbox_EN.txt`          | Sandbox page and option translation strings (separate from UI_EN.txt — PZ convention) |
| UPDATE | `UniversalTraits/media/registries.lua`                                  | Add 10 `UT_CHEAT_*` IDs                                                             |
| UPDATE | `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`               | UIName + UIDescription for 10 traits                                                |

**No per-trait Lua files are created.** All cheat trait logic lives in `UTCore_CheatHook.lua`, following the "Dumb Traits, Smart Core" principle from the existing architecture.

### Sandbox settings

File: `UniversalTraits/media/sandbox-options.txt`

```ini
VERSION = 1,

option UniversalTraits.EnableCheatTraits
{
    type = boolean, default = false,
    page = UniversalTraits_Cheats, translation = UT_SandboxEnableCheatTraits,
}
```

`SandboxVars.UniversalTraits.EnableCheatTraits` is the single gate. When `false` (default), all `UT_CHEAT_*` traits are suppressed at `OnGameBoot` via `CharacterTrait.Get("UniversalTraits:<id>"):setIsAvailable(false)`. The traits remain registered in the script — they are hidden, not unregistered.

### `UTCore_CheatHook.lua` structure

```text
UTCore_CheatHook.lua
│
├── CHEAT_TRAIT_IDS  -- table of all 10 UT_CHEAT_* full IDs
│
├── OnGameBoot handler
│     if SandboxVars.UniversalTraits.EnableCheatTraits == false:
│       for each id in CHEAT_TRAIT_IDS:
│         CharacterTrait.Get(id):setIsAvailable(false)
│
├── OnNewGame handler
│     if hasTrait(UT_CHEAT_maxskills): set all skills to level 10
│     [sets moddata flags for OnPlayerUpdate handlers]
│
└── OnPlayerUpdate handler (throttle: every 30 ticks)
      if UT_CHEAT_godmode:    restore all body part health; clear infection
      if UT_CHEAT_noneed_*:   zero the matching stat(s)
```

### Moddata keys written

| Key                       | Type    | Written by        | Read by               |
| ------------------------- | ------- | ----------------- | --------------------- |
| `UT_CHEAT_godmode`        | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |
| `UT_CHEAT_noneed_hunger`  | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |
| `UT_CHEAT_noneed_thirst`  | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |
| `UT_CHEAT_noneed_fatigue` | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |
| `UT_CHEAT_noneed_boredom` | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |
| `UT_CHEAT_noneed_unhappy` | boolean | `OnNewGame` handler | `OnPlayerUpdate` handler |

Free Points and Max Skills write no moddata (script-only / fires once respectively).

---

## Translations

New strings in `UI_EN.txt` (trait names and descriptions):

```lua
UI_UT_CHEAT_points100 = "Free Points I",
UI_UT_CHEAT_points100desc = "[CHEAT] +100 character creation points. No gameplay effect.",
UI_UT_CHEAT_points200 = "Free Points II",
UI_UT_CHEAT_points200desc = "[CHEAT] +200 character creation points. No gameplay effect.",
UI_UT_CHEAT_points300 = "Free Points III",
UI_UT_CHEAT_points300desc = "[CHEAT] +300 character creation points. No gameplay effect.",
UI_UT_CHEAT_godmode = "God Mode",
UI_UT_CHEAT_godmodedesc = "[CHEAT] All body parts stay at full health. Cannot be infected.",
UI_UT_CHEAT_maxskills = "Max Skills",
UI_UT_CHEAT_maxskillsdesc = "[CHEAT] All skills start at level 10.",
UI_UT_CHEAT_noneed_hunger = "No Hunger",
UI_UT_CHEAT_noneed_hungerdesc = "[CHEAT] Hunger never increases.",
UI_UT_CHEAT_noneed_thirst = "No Thirst",
UI_UT_CHEAT_noneed_thirstdesc = "[CHEAT] Thirst never increases.",
UI_UT_CHEAT_noneed_fatigue = "No Fatigue",
UI_UT_CHEAT_noneed_fatiguedesc = "[CHEAT] Fatigue never increases.",
UI_UT_CHEAT_noneed_boredom = "No Boredom",
UI_UT_CHEAT_noneed_boredomdesc = "[CHEAT] Boredom never increases.",
UI_UT_CHEAT_noneed_unhappy = "No Unhappiness",
UI_UT_CHEAT_noneed_unhappydesc = "[CHEAT] Unhappiness never increases.",
```

New strings in `Sandbox_EN.txt` (sandbox page label and option):

```lua
Sandbox_EN = {
    Sandbox_UniversalTraits_Cheats = "UniversalTraits: Cheats",
    Sandbox_UT_SandboxEnableCheatTraits = "Enable Cheat Traits",
    Sandbox_UT_SandboxEnableCheatTraits_tooltip = "Show UT_CHEAT_* traits in character creation. Disabled by default. Cheat traits are for testing and single-player fun — use at your own discretion.",
}
```

---

## Test Coverage

### `UT_CORE/test/run_tests.lua` — add 3 tests (target: 32 total)

- `UT_CHEAT_godmode` moddata flag set by `OnNewGame` handler
- `OnPlayerUpdate` handler restores body part health when `UT_CHEAT_godmode = true`
- `OnPlayerUpdate` handler zeroes hunger stat when `UT_CHEAT_noneed_hunger = true`

### `UniversalTraits/test/run_tests.lua` — add 3 tests (target: 31 total)

- `UT_CHEAT_points100` is registered in the CharacterTrait system
- `UT_CHEAT_noneed_hunger` sets `UT_CHEAT_noneed_hunger = true` in moddata at `OnNewGame`
- Visibility gate: when `SandboxVars.UniversalTraits.EnableCheatTraits = false`, all 10 cheat traits report unavailable

---

## Files Modified / Created

| Action | File |
| ------ | ---- |
| CREATE | `UniversalTraits/media/scripts/UT_cheat_traits.txt` |
| CREATE | `UniversalTraits/media/sandbox-options.txt` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_CheatHook.lua` |
| CREATE | `UniversalTraits/media/lua/shared/Translate/EN/Sandbox_EN.txt` |
| UPDATE | `UniversalTraits/media/registries.lua` |
| UPDATE | `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` |
| UPDATE | `UT_CORE/test/run_tests.lua` — add 3 CheatHook tests |
| UPDATE | `UniversalTraits/test/run_tests.lua` — add 3 cheat trait spot-checks |
| UPDATE | `AGENTS.md` — document cheat traits category and sandbox settings |
| SYNC   | `UT_CORE/release/` and `UniversalTraits/release/` after all changes |

---

## Verification

### Unit tests (automated)

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
# Expected: 32 tests passing

"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
# Expected: 31 tests passing
```

### In-game smoke test (manual)

1. New game with `EnableCheatTraits = false` (default) → no `UT_CHEAT_*` traits visible in character creation
2. New game with `EnableCheatTraits = true` → all 10 cheat traits visible
3. Take `UT_CHEAT_points300` → character creation budget increases by 300
4. Take `UT_CHEAT_godmode` → get wounded in-game, confirm health restores automatically
5. Take `UT_CHEAT_maxskills` → inspect skills at spawn, confirm all level 10
6. Take `UT_CHEAT_noneed_hunger` + `UT_CHEAT_noneed_thirst` → play for 24 in-game hours, confirm hunger and thirst stay at 0; fatigue still increases normally
