# UniversalTraits — Agent Instructions

This file is the single source of truth for AI agents working in this project.
Update it after completing any non-trivial task with lessons learned, API discoveries,
and decisions made. This prevents repeat research and research drift across sessions.

---

## Standing Instruction: Update This File After Every Session

After completing all tasks in a session, evaluate whether any of the following were learned:
- New PZ B42 API calls discovered or confirmed working
- Mod structure decisions that differ from initial assumptions
- Gotchas, quirks, or bugs encountered
- Decisions about trait design (costs, effects, MET groupings)
- Test or tooling patterns that proved useful

If yes, add them to the relevant section below before closing the session.

---

## Project Overview

Two-mod layout targeting Project Zomboid Build 42 (Kahlua/Lua 5.x):

| Mod | Purpose | Dependency |
|-----|---------|-----------|
| `UT_CORE` | Shared Lua infrastructure, helpers | None |
| `UniversalTraits` | All trait definitions, scripts, translations | requires UT_CORE |

**Goal:** ~200 traits, all `UT_`-prefixed, no vanilla overrides, single-player only (`DisabledInMultiplayer = true`).

---

## Repo Structure

```
UniversalTraits/                          ← repo root
  UT_CORE/
    media/lua/shared/UTCore/              ← source infrastructure files
    release/UT_CORE/42.0/media/           ← deployed copy (must be kept in sync)
    test/run_tests.lua                    ← 29 tests (standard Lua 5.x)
    test/UTCoreMocks.lua                  ← mock IsoPlayer, Stats, BodyDamage
  UniversalTraits/
    media/registries.lua                  ← CharacterTrait.register() for all traits
    media/scripts/UT_character_traits.txt ← script-block definitions
    media/lua/shared/Translate/EN/UI_EN.txt ← all translations
    media/lua/shared/UniversalTraits/
      UT_MET.lua                          ← runtime mutual exclusivity table
      traits/UT_<id>.lua                  ← per-trait Lua effect files (95 files)
    release/UniversalTraits/42.0/media/   ← deployed copy (must be kept in sync)
    test/run_tests.lua                    ← 28 tests (standard Lua 5.x)
    test/UTTestMocks.lua                  ← mock CharacterTrait
  planning/                               ← implementation plans
  research/                               ← source mod research
  PRD.md
  AGENTS.md                               ← this file
```

---

## Test Commands

Run from repo root (`C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods`):

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

**Current passing counts:** 29 (UT_CORE) + 28 (UniversalTraits) = 57 total.

---

## In-Game Testing (Deploy to Live Mods)

Run from repo root after ANY code change before in-game testing:

```bash
cp -r UniversalTraits/media/. "C:/Users/Admin/Zomboid/mods/UniversalTraits/42.0/media/"
cp -r UT_CORE/media/. "C:/Users/Admin/Zomboid/mods/UT_CORE/42.0/media/"
```

**Note:** Deploy directly from source (`media/`) to the live mods folder. Do NOT write to `release/`.

---

## Release Folder Policy

`UniversalTraits/release/` and `UT_CORE/release/` are **empty during development**.

They are only populated when the mod is ready for distribution (Workshop upload or zip packaging).
At that point, copy the full deployable package:

```bash
# Only run this when preparing a distribution release — NOT for in-game testing
mkdir -p UniversalTraits/release/UniversalTraits/42.0/media
cp UniversalTraits/mod.info UniversalTraits/release/UniversalTraits/42.0/
cp -r UniversalTraits/media/. UniversalTraits/release/UniversalTraits/42.0/media/

mkdir -p UT_CORE/release/UT_CORE/42.0/media
cp UT_CORE/mod.info UT_CORE/release/UT_CORE/42.0/
cp -r UT_CORE/media/. UT_CORE/release/UT_CORE/42.0/media/
```

The `release/` folders hold only the minimal deployable mod package — no docs, no tests, no planning files.

---

## Trait Count (as of 2026-03-28)

| Phase | Count | Status |
|-------|-------|--------|
| Phase 1 — XP Boost / script-only stat modifiers | 99 | Complete |
| Phase 2 — Stat modifier + hasTrait Lua effects | 46 | Complete |
| Phase 3a — Spawn-with-condition | 4 | Complete |
| Phase 3b — Periodic-check (timer-based) | 24 | Complete |
| Phase 3c — Event-driven | 18 | Complete |
| Phase 3d — Complex state machines | 3 | Complete |
| **Total registered** | **199** | — |
| Deferred: UT_amputee | 1 | Deferred indefinitely |

Registration count test in `UniversalTraits/test/run_tests.lua` asserts **199**.
When adding new traits, update this count and the test.

---

## Script Block Format

In `UniversalTraits/media/scripts/UT_character_traits.txt`:

```
    character_trait_definition UniversalTraits:UT_<id>
    {
        IsProfessionTrait = false,
        DisabledInMultiplayer = true,
        CharacterTrait = UniversalTraits:UT_<id>,
        Cost = <int>,
        UIName = UI_UT_<id>,
        UIDescription = UI_UT_<id>desc,
        [XPBoosts = Skill=N;Skill2=N,]
        [MutuallyExclusiveTraits = UniversalTraits:UT_other;...,]
    }
```

- Negative Cost = negative trait (gives points back).
- XPBoosts only needed for script-only traits (Phase 1 / bouncer / gunspecialist tiers).
- Phase 2+ traits are Lua-driven — no XPBoosts in the script block.
- All trait IDs in MET fields use full namespace: `UniversalTraits:UT_<id>`.

---

## Registration Format

In `UniversalTraits/media/registries.lua`:

```lua
UTTraitsRegistries.UT_<id> = CharacterTrait.register("UniversalTraits:UT_<id>")
```

---

## Translation Format

In `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`:

```lua
UI_UT_<id>             = "Display Name",
UI_UT_<id>Desc         = "Flavor text description.",
```

Note: Script blocks reference `UI_UT_<id>desc` (lowercase d), translations use `UI_UT_<id>Desc`
(capital D). These are separate namespaces — both exist and both are needed.

---

## Per-Trait Lua File Format

In `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_<id>.lua`:

```lua
-- UT_<id>.lua
-- Brief description

local TRAIT_ID = "UniversalTraits:UT_<id>"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    -- effect
end

Events.OnNewGame.Add(onNewGame)
```

For periodic handlers, use `getPlayer()` (no args):

```lua
local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    -- effect
end
Events.EveryOneMinute.Add(onEveryMinute)
```

---

## UTCore API Reference

### UTCore_API.lua
- `UTCore.hasTrait(player, traitId)` → bool — nil-safe trait check

### UTCore_TraitChecks.lua
- `UTCore.hasAnyTrait(player, idTable)` → bool
- `UTCore.getModData(player, key, default)` → value
- `UTCore.setModData(player, key, value)`

### UTCore_StatModifiers.lua
- `UTCore.applyCarryWeight(player, delta)` — calls `player:setMaxWeightBase(base + delta)`
- `UTCore.applyBleedRate(player, multiplier)` — stores `UT_bleedMult` in moddata
- `UTCore.applyWorkSpeed(player, delta)` — stores `UT_workSpeedMod` in moddata
- `UTCore.applyXPMultiplier(player, perkName, multiplier)` — stores `UT_xpMult_<perk>` in moddata
- `UTCore.disableXP(player, perkName)` — stores `UT_xpDisable_<perk> = true` in moddata
- `UTCore.applyPanicResistance(player, amount)` — stores `UT_panicResist` in moddata
- `UTCore.applySpeedModifier(player, amount)` — stores `UT_speedMod` in moddata
- `UTCore.applyMoodModifier(player, amount)` — stores `UT_moodMod`; also calls `setStress` if amount > 0
- `UTCore.applySleepQuality(player, delta)` — stores `UT_sleepQualMod` in moddata
- `UTCore.applyNoiseMod(player, multiplier)` — stores `UT_noiseMult` in moddata

### UTCore_SpawnEffects.lua
- `UTCore.applySpawnStats(player, statTable)` — keys: `"panic"`, `"stress"`, `"hunger"`, `"thirst"`, `"fatigue"`, `"endurance"`, `"carryDelta"`
- `UTCore.applySpawnCondition(player, conditionTable)` — keys: `injuries={bodyPartIds}`, `fractures={bodyPartIds}`, `burnSeverity=float`

### UTCore_Events.lua
- `UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)` — idempotent
- `UTCore.unregisterPeriodicHandler(traitId)` — removes from Events and registry
- `intervalEvent` values: `"EveryOneMinute"`, `"EveryTenMinutes"`, `"EveryHours"`, `"OnPlayerUpdate"`

### UTCore_XPHook.lua

- Registered via `Events.AddXP` — reads `UT_xpMult_<perk>`, `UT_xpDisable_<perk>`, `UT_multiSkillPenalty` from moddata and applies corrections automatically
- `UTCore._xpPerksThisMinute` — exposed for test resets

### UTCore_SpeedHook.lua

- Registered via `Events.OnPlayerMove` — reads `UT_speedMod` from moddata and applies position delta multiplication automatically
- Teleport guard: skips if delta > 5 tiles

### UTCore_WorkSpeedHook.lua

- `UTCore.applyWorkDuration(timedAction, base)` → number — applies `UT_workSpeedMod` and (for ISReadABook) `UT_readSpeedMod` to a TimedAction duration
- Registered via `Events.OnGameBoot` to patch all TimedAction `getDuration()` calls globally

### UTCore_BleedHook.lua

- Registered via `Events.OnPlayerUpdate` (throttled every 30 ticks) — reads `UT_bleedMult` from moddata and applies BodyPart health corrections automatically
- `UTCore._bleedTickCounter` — exposed for test resets

---

## B42 PZ API — Confirmed Working

Discovered from research mods (MoreTraits, FillerTraits, DynamicTraitsExpandedMoodles, EvolvingTraitsWorld):

### Player
- `player:getTraits()` → Java ArrayList; use `:contains(id)` to check
- `player:getModData()` → Lua table (persists across save/load)
- `player:getMaxWeightBase()` / `setMaxWeightBase(n)` — carry weight (integer)
- `player:getBodyDamage()` → IsoBodyDamage
- `player:getBodyTemperature()` → float (normal ~37.0)
- `player:isOutside()` → bool
- `player:isSprinting()` / `isRunning()` / `isWalking()` → bool
- `player:getVehicle()` → vehicle or nil (check for in-vehicle)
- `player:getZ()` → floor level (0 = ground, 1+ = upper floors)
- `player:getPerkLevel(Perks.PerkName)` → int (0-10)

### Stats (`player:getStats()`)
- `getStress()` / `setStress(v)` — 0.0-1.0
- `getPanic()` / `setPanic(v)` — 0.0-1.0
- `getHunger()` / `setHunger(v)` — 0.0-1.0
- `getThirst()` / `setThirst(v)` — 0.0-1.0
- `getFatigue()` / `setFatigue(v)` — 0.0-1.0
- `getEndurance()` / `setEndurance(v)` — 0.0-1.0
- `getMaxEndurance()` → float
- `getDrunkenness()` / `setDrunkenness(v)` — 0.0-1.0
- `getBoredom()` / `setBoredom(v)` — 0.0-1.0
- `getAnger()` → float

### Body Damage (`player:getBodyDamage()`)
- `:getBodyPart(BodyPartType.xxx)` → IsoBodyPart
- `:getInfectionLevel()` / `setInfectionLevel(v)` — 0.0+
- Body part: `:setHealth(v)`, `:setFractured(bool)`
- Body part constants: `BodyPartType.Hand_L`, `Hand_R`, `Foot_L`, `Foot_R`, `Torso_Upper`, `Torso_Lower`, `Neck`, etc.

### Time
- `getGameTime():getTimeOfDay()` → 0.0-1.0 (0.0=midnight, 0.5=noon)
- `getGameTime():getNight()` → bool
- `getGameTime():getWorldAgeHours()` → float (for cooldown timestamps)

### Events
- `Events.OnNewGame.Add(fn)` — fn receives `(player)`
- `Events.OnPlayerUpdate.Add(fn)` — fn receives `(player)` — **throttle required**
- `Events.EveryOneMinute.Add(fn)` — no args, use `getPlayer()`
- `Events.EveryTenMinutes.Add(fn)` — no args
- `Events.EveryHours.Add(fn)` — no args
- `Events.OnVehicleEnter.Add(fn)` — fn receives `(player, vehicle)`
- `Events.OnVehicleExit.Add(fn)` — fn receives `(player, vehicle)`
- `Events.OnEat.Add(fn)` — fn receives `(player, food)`
- `Events.OnPanic.Add(fn)` — fn receives `(player)`
- `Events.OnZombieKilled.Add(fn)` — fn receives `(player, zombie)`
- `Events.AddXP.Add(fn)` — fn receives `(player, perkType, amount)` — use for XP multiplier hooks

---

## Key Architecture Decisions

### Speed modification
B42 speed is modified via `player:Move(Vector2)` in OnPlayerUpdate — complex and MP-sensitive.
For UT_ traits, speed effects are stored as moddata flags (`UT_speedMod`, `UT_speedBoost`) rather than
directly calling Move(). This is consistent with how MoreTraits handles it.

### Periodic handler throttling
**Rule:** No OnPlayerUpdate handler without a moddata tick counter throttle.
Minimum throttle: every 15 ticks for high-frequency checks, 30 ticks for normal.
Prefer `EveryOneMinute` / `EveryTenMinutes` over OnPlayerUpdate when real-time is not needed.

### Moddata key convention
All UT_ moddata keys are prefixed `UT_` to avoid collision with vanilla and other mods.
Examples: `UT_speedMod`, `UT_bleedMult`, `UT_indefCooldown`.

### Cooldown tracking
Use `getGameTime():getWorldAgeHours()` for cooldown timestamps (persists across sessions).
Compare: `now - startTime >= (minutes / 60.0)`.

### Lua file loading (PZ vs standard Lua)
PZ loads via `dofile`, not `require`. Therefore:
- Do NOT use `local` for top-level module tables (they won't be accessible globally).
- Do NOT use `return` at end of file.
- Use `TableName = TableName or {}` pattern.

### Tests run with standard Lua 5.x (not Kahlua)
The test harness uses `UTCoreMocks.lua` / `UTTestMocks.lua` to stub PZ globals.
When adding new PZ API calls to UTCore files, add corresponding mock support to the mock files.

---

## MET Groups (Mutual Exclusivity)

Defined in `UT_MET.lua` (runtime) and `MutuallyExclusiveTraits` fields in script blocks.
Key groups:
- **Specialization series:** specweapons, speccrafting, specfood, specguns, specmove, specaid
- **Weapon Axes:** axes, twohanded_axes, onehanded_axes
- **Weapon Blunts:** blunts, twohanded_blunts, onehanded_blunts, long_blunts, short_blunts
- **Weapon Blades:** blades, twohanded_blades, onehanded_blades, long_blades, short_blades
- **Hand type:** twohanded, onehanded
- **Prowess:** problunt, problade, progun, prospear
- **Alcoholic tiers:** alcoholic_I, alcoholic_II, alcoholic_III (pick one)
- **Injured tiers:** injured_I, injured_II
- **Mood:** optimist ↔ pessimist, optimist ↔ depressive, optimist ↔ melancholic, mstoptimist ↔ pessimist
- **Immune:** superimmune ↔ immunocompromised
- **Gun Specialist tiers:** gunspecialist_I, gunspecialist_II, gunspecialist_III (+ mutually exclusive with specguns)
- **Bouncer tiers:** bouncer_I, bouncer_II
- **Speed:** fast ↔ noodlelegs, fast ↔ lurcher, noodlelegs ↔ pacer
- **Work speed:** quickworker ↔ slowworker, quickworker ↔ slack, slowworker ↔ slack
- **Bleed:** thickblood ↔ heavilybleedingwounds, weaklybleedingwounds ↔ heavilybleedingwounds
- **Stamina:** indefatigable, hardy, secondwind (pick one)
- **Eating:** gourmand ↔ ascetic, anorexy ↔ gourmand, anorexy ↔ competitiveeater
- **Driving:** expertdriver ↔ poordriver, vehophobic ↔ expertdriver
- **XP shooters:** noxpshooter ↔ antigun
- **Day/Night:** owlperson ↔ larkperson

---

## Deferred Work

- **UT_amputee** — complex limb system, deferred indefinitely (plan says "defer to Phase 3b")
- **In-game verification** — all traits need visual/functional confirmation in PZ character creation
- **poster.png** — cosmetic, not required for function (both mods missing)
- **XP hooks** — `UT_xpMult_*` and `UT_xpDisable_*` moddata flags are stored but the
  `Events.AddXP` handler that reads them has not been implemented yet. Add to UTCore.

---

## Known Gaps / TODOs

All 6 previously documented gaps are now resolved. See new UTCore hook modules:

- **UTCore_XPHook.lua** — handles AddXP interception (XP mult, XP disable, onetrickpony multi-skill penalty)
- **UTCore_SpeedHook.lua** — handles OnPlayerMove speed delta (fast, noodlelegs, lurcher, pacer, sorelegs)
- **UTCore_WorkSpeedHook.lua** — handles getDuration override (quickworker, slowworker, slack, flatearther, photographicmemory)
- **UTCore_BleedHook.lua** — handles bleed rate via BodyPart health adjustment (thickblood, weaklybleeding, heavilybleeding)

### Remaining deferred work

- **UT_amputee** — complex limb system, deferred indefinitely
- **poster.png** — cosmetic, not required for function
- **In-game verification** — all traits need visual/functional confirmation in PZ character creation
