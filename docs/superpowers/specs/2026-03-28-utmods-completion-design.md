# UTMods Completion & Polish — Design Spec

**Date:** 2026-03-28
**Project:** UniversalTraits / UT_CORE (Project Zomboid B42)
**Status:** Approved

---

## Context

All 199 traits are registered and all three implementation phases are structurally complete (36 tests passing). However, six categories of trait effects are stored as moddata flags but never read at runtime — meaning those traits register in the character creation menu but have zero in-game effect. This spec covers the work required to make those effects actually fire, plus the behavioral test suite needed to verify them.

**What prompted this:** Post-phase-3 audit identified that UTCore helper functions like `applyXPMultiplier()`, `applySpeedModifier()`, `applyWorkSpeed()`, `applyBleedRate()`, and `applyReadSpeed()` write moddata keys but no event handlers in UTCore ever read those keys. The gap between "stored" and "applied" is the entirety of the remaining work.

**Intended outcome:** Every trait effect that the PRD describes actually fires in-game. UTCore is the sole owner of all hook complexity; individual trait files remain simple data-application calls.

---

## Architecture

### Principle: Dumb Traits, Smart Core

Individual trait Lua files (`traits/UT_*.lua`) only:
1. Check `UTCore.hasTrait()` in a handler
2. Call a UTCore helper to apply a modifier (or set moddata)
3. Register with `UTCore.registerPeriodicHandler()` if periodic

All event hooks, throttling logic, B42 API calls, and modifier math live exclusively in UT_CORE modules. No trait file ever directly touches `Events.*`, `player:setX()`, `getDuration()`, or BodyPart iteration.

---

## New UTCore Modules (4 files)

### 1. `UTCore_XPHook.lua`

**Purpose:** Single `Events.AddXP` handler that intercepts every XP gain and applies stored multipliers or disables.

**API added to UTCore:**
- `UTCore.applyXPMultiplier(player, perkName, multiplier)` — already exists, writes `UT_xpMult_<perk>` ✓
- `UTCore.disableXP(player, perkName)` — already exists, writes `UT_xpDisable_<perk>` ✓
- `UTCore.trackXPPerk(player, perkName)` — NEW: called by the AddXP hook to track which perks earned XP this game-minute (for onetrickpony multi-skill penalty)

**Handler logic:**
```
Events.AddXP handler(player, perk, amount):
  1. Check UT_xpDisable_<perk> → if true, cancel XP (return 0 or suppress)
  2. Check UT_xpMult_<perk> → if set, multiply amount
  3. Check UT_multiSkillPenalty → if true, call trackXPPerk; if >1 distinct perk
     this minute, apply 0.5x penalty to amount
  4. Return adjusted amount
```

**Throttle:** No throttle needed — `Events.AddXP` fires only when XP is actually awarded.

**Note on B42 AddXP interception:** B42 exposes `Events.AddXP(player, perk, amount)`. The amount cannot be directly cancelled from a hook — the handler pattern is to immediately add a negative correction XP call. Research confirms this is the standard approach used by DynamicTraitsExpandedMoodles.

---

### 2. `UTCore_SpeedHook.lua`

**Purpose:** `Events.OnPlayerMove` handler that multiplies position delta for speed traits.

**Moddata key read:** `UT_speedMod` (float, delta; 0.2 = 20% faster, -0.2 = 20% slower)

**Handler logic (from MoreTraits reference):**
```
Events.OnPlayerMove handler():
  player = getPlayer(); if not player then return end
  mod = getModData().UT_speedMod; if not mod or mod == 0 then return end
  Store previous X/Y in moddata (UT_prevX, UT_prevY)
  On next call: compute (newX - prevX, newY - prevY) delta
  Apply: player:setX(prevX + delta.x * (1 + mod))
         player:setY(prevY + delta.y * (1 + mod))
  Sanity clamp: if |delta| > 5 tiles, skip (teleport guard)
  Update UT_prevX, UT_prevY
```

**Traits that use this:** `UT_fast` (+0.3), `UT_noodlelegs` (-0.3), `UT_lurcher` (-0.2), `UT_pacer` (+0.15), `UT_sorelegs` (-0.25).

---

### 3. `UTCore_WorkSpeedHook.lua`

**Purpose:** Overrides `getDuration()` on all TimedActions at game boot to apply work speed and read speed modifiers.

**Moddata keys read:**
- `UT_workSpeedMod` (float, delta; -0.5 = 50% faster, +0.5 = 50% slower)
- `UT_readSpeedMod` (float, delta; -0.3 = 30% faster read)

**Hook pattern (from MoreTraits catch-all reference):**
```lua
Events.OnGameBoot.Add(function()
  for _, timedAction in pairs(_G) do
    if type(timedAction) == "table" and timedAction.getDuration then
      local orig = timedAction.getDuration
      timedAction.getDuration = function(self)
        local base = orig(self)
        if not base or base <= 1 then return base end
        return UTCore.applyWorkDuration(self, base)
      end
    end
  end
end)
```

`UTCore.applyWorkDuration(timedActionSelf, baseDuration)`:
- Gets player from `timedActionSelf.character`
- Reads `UT_workSpeedMod`
- If `timedActionSelf.Type == "ISReadABook"`, also reads `UT_readSpeedMod`
- Returns `math.max(1, baseDuration * (1 + workMod + readMod))`

**Traits that use this:**
- Work speed: `UT_quickworker` (-0.5), `UT_slowworker` (+0.5), `UT_slack` (+0.4)
- Read speed: `UT_flatearther` (+0.3 = slower), `UT_photographicmemory` (-0.2 = faster)

---

### 4. `UTCore_BleedHook.lua`

**Purpose:** Throttled `Events.OnPlayerUpdate` handler that applies bleeding rate modifiers to all active bleeding body parts.

**Moddata key read:** `UT_bleedMult` (float, multiplier; 0.5 = half bleed rate, 2.0 = double)

**Handler logic (from MoreTraits bleed reference):**
```
Events.OnPlayerUpdate throttle: every 30 ticks
  player = getPlayer(); if not player then return end
  mult = getModData().UT_bleedMult; if not mult or mult == 1.0 then return end
  bd = player:getBodyDamage()
  if bd:getNumPartsBleeding() == 0 then return end
  for each bodyPart in bd:getBodyParts():
    if bodyPart:bleeding() and not bodyPart:IsBleedingStemmed():
      if mult < 1.0:  -- slow bleed (thickblood, weaklybleeding)
        bodyPart:AddHealth(0.002 * (1.0 - mult))
      else:           -- fast bleed (heavilybleeding)
        bodyPart:ReduceHealth(0.001 * (mult - 1.0))
      neck multiplier: × 2 if bodyPart:getType() == BodyPartType.Neck
```

**Traits that use this:**
- `UT_thickblood`: `UT_bleedMult = 0.4`
- `UT_weaklybleedingwounds`: `UT_bleedMult = 0.6`
- `UT_heavilybleedingwounds`: `UT_bleedMult = 2.0`

---

## Test Expansion

### UT_CORE tests (`UT_CORE/test/run_tests.lua`)

Add behavioral tests for each new hook module. Target: **25 tests** (up from 15).

New test groups:
- **XPHook (4 tests):** XP multiply, XP disable, multi-skill penalty triggers, multi-skill penalty does not fire for single-skill
- **SpeedHook (3 tests):** Positive delta multiplied, negative delta multiplied, teleport guard clamps
- **WorkSpeedHook (3 tests):** getDuration shortened, getDuration lengthened, read-type gets readSpeedMod applied
- **BleedHook (2 tests):** AddHealth called for mult < 1.0, ReduceHealth called for mult > 1.0

### UniversalTraits tests (`UniversalTraits/test/run_tests.lua`)

Add spot-check tests for the 6 previously-gap traits. Target: **28 tests** (up from 21).

New tests:
- `UT_onetrickpony` sets `UT_multiSkillPenalty = true` in moddata
- `UT_flatearther` sets `UT_readSpeedMod` in moddata
- `UT_fast` sets `UT_speedMod` positive
- `UT_noodlelegs` sets `UT_speedMod` negative
- `UT_quickworker` sets `UT_workSpeedMod` negative
- `UT_thickblood` sets `UT_bleedMult` < 1.0
- `UT_heavilybleedingwounds` sets `UT_bleedMult` > 1.0

---

## Files Modified / Created

| Action | File |
|--------|------|
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua` |
| UPDATE | `UT_CORE/test/run_tests.lua` — add 10 behavioral tests |
| UPDATE | `UniversalTraits/test/run_tests.lua` — add 7 moddata spot-checks |
| UPDATE | `AGENTS.md` — mark gaps resolved, document new hook modules |
| SYNC | `UT_CORE/release/` and `UniversalTraits/release/` after all changes |

**No trait files are modified.** Trait moddata keys are already set correctly by existing trait handlers.

---

## Verification

### Unit tests (automated, pre-commit gate)
```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
# Expected: 25 tests passing

"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
# Expected: 28 tests passing
```

### In-game smoke test (manual, post-deploy)
Deploy from source:
```bash
cp -r UniversalTraits/media/. "C:/Users/Admin/Zomboid/mods/UniversalTraits/"
cp -r UT_CORE/media/. "C:/Users/Admin/Zomboid/mods/UT_CORE/"
```

Verification checklist:
1. Start new game with `UT_fast` → observe movement is visibly faster
2. Start new game with `UT_noodlelegs` → observe movement is visibly slower
3. Start new game with `UT_quickworker` → time a crafting action, confirm it completes faster
4. Start new game with `UT_thickblood` → get wounded, confirm bleeding stops sooner
5. Start new game with `UT_heavilybleedingwounds` → get wounded, confirm bleeding progresses faster
6. Start new game with `UT_flatearther` → read a book, confirm it takes longer
7. Start new game with `UT_noxpshooter` → fire weapon, confirm no Aiming XP gained
8. Start new game with `UT_onetrickpony` → level two skills in same session, confirm XP penalty applies
