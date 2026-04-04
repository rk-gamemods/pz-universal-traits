# UniversalTraits — Agent Instructions

This file is the single source of truth for AI agents working in this project.
Update it after completing any non-trivial task with lessons learned, API discoveries,
and decisions made. This prevents repeat research and research drift across sessions.

Before changing any trait, read `TRAIT_CHANGE_CHECKLIST.md` first. Keep the checklist short and operational; keep AGENTS for durable project knowledge.

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

```text
UniversalTraits/                          ← repo root
  UT_CORE/
    media/lua/shared/UTCore/              ← source infrastructure files
    release/UT_CORE/42/media/           ← deployed copy (must be kept in sync)
    test/run_tests.lua                    ← 52 tests (standard Lua 5.x)
    test/UTCoreMocks.lua                  ← mock IsoPlayer, Stats, BodyDamage
  UniversalTraits/
    media/registries.lua                  ← CharacterTrait.register() for all traits
    media/scripts/UT_character_traits.txt ← script-block definitions
    media/lua/shared/Translate/EN/UI_EN.txt ← translation source text
    media/lua/shared/Translate/EN/UI.json  ← generated translation JSON used by deployed mod
    media/lua/shared/UniversalTraits/
      UT_MET.lua                          ← runtime mutual exclusivity table
      traits/UT_<id>.lua                  ← per-trait Lua effect files (121 files)
    release/UniversalTraits/42/media/   ← deployed copy (must be kept in sync)
    test/run_tests.lua                    ← 70 tests (standard Lua 5.x)
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

**Current passing counts:** 52 (UT_CORE) + 70 (UniversalTraits) = 122 passing.

---

## In-Game Testing (Deploy to Live Mods)

Run from repo root after ANY code change before in-game testing:

```powershell
Copy-Item -Recurse -Force UT_CORE\media\* C:\Users\Admin\Zomboid\mods\UT_CORE\42\media\
Copy-Item -Recurse -Force UniversalTraits\media\* C:\Users\Admin\Zomboid\mods\UniversalTraits\42\media\
```

**Note:** The live mod folder structure is `Zomboid\mods\ModName\42\media\`. Copying to the mod root (without `42\media\`) is **silent failure** — PZ B42 only reads from `42\media\`.

---

## Release Folder Policy

`UniversalTraits/release/` and `UT_CORE/release/` must be kept in sync with source after every code change.

Required workflow after implementation work:

1. Run tests.
2. Sync `release/<ModName>/42/media/` from source `media/`.
3. Copy root `mod.info` into `release/<ModName>/`.
4. Deploy to live `C:\Users\Admin\Zomboid\mods\<ModName>\42\media\`.
5. Commit the changes.

Use these commands from repo root:

```bash
mkdir -p UniversalTraits/release/UniversalTraits/42/media
cp UniversalTraits/mod.info UniversalTraits/release/UniversalTraits/
cp -r UniversalTraits/media/. UniversalTraits/release/UniversalTraits/42/media/

mkdir -p UT_CORE/release/UT_CORE/42/media
cp UT_CORE/mod.info UT_CORE/release/UT_CORE/
cp -r UT_CORE/media/. UT_CORE/release/UT_CORE/42/media/
```

The `release/` folders hold only the minimal deployable mod package — no docs, no tests, no planning files.

---

## Trait Count (as of 2026-03-28)

| Phase | Count | Status |
|-------|-------|--------|
| Phase 1 — XP Boost / script-only stat modifiers | 98 | Complete |
| Phase 2 — Stat modifier + hasTrait Lua effects | 46 | Complete |
| Phase 3a — Spawn-with-condition | 4 | Complete |
| Phase 3b — Periodic-check (timer-based) | 25 | Complete |
| Phase 3c — Event-driven | 22 | Complete |
| Phase 3d — Complex state machines | 3 | Complete |
| **Total registered** | **198** | — |
| Deferred: UT_amputee | 1 | Deferred indefinitely |

Registration count test in `UniversalTraits/test/run_tests.lua` asserts **198**.
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
- Vanilla B42 startup order is `ModRegistries.init()` first, then `ScriptManager.instance.Load()`. `media/registries.lua` runs before `media/scripts/*.txt`, so `MutuallyExclusiveTraits` can safely reference any trait id that was registered in `registries.lua`, even if its script block appears later in the file.
- Character creation still reads `MutuallyExclusiveTraits` from `UT_character_traits.txt`; `UT_MET.lua` is only a runtime grouping table and does not populate the pregame UI by itself.
- Script-side `addMutuallyExclusive()` is one-way. For character-creation behavior, keep intended `UniversalTraits:` exclusions explicit on both traits so selecting either side removes the other from the available list.
- The real null-crash causes are unknown/unregistered trait ids in script/runtime mutual exclusions, or runtime code that appends `nil` into `getMutuallyExclusiveTraits()` / `setMutualExclusive()`.
- Cross-mod `MutuallyExclusiveTraits` entries are only safe when the other mod is an explicit dependency and the exact foreign trait id has been verified in that mod's `media/registries.lua`. Do not guess third-party ids.
- When static review cannot identify the bad entry, add a temporary client-side wrapper around `CharacterCreationProfession:doTestForMutuallyExclusiveTraits()` and log the selected trait id plus the unresolved `exclusiveTrait` before vanilla dereferences `:isFree()`.

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

After editing `UI_EN.txt`, regenerate `UniversalTraits/media/lua/shared/Translate/EN/UI.json` by running `convert_translations.lua`, then sync the generated JSON into release and live copies. Do not assume `UI_EN.txt` alone is enough for the in-game deployed text.

---

## Per-Trait Lua File Format

In `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_<id>.lua`:

```lua
-- UT_<id>.lua
-- Brief description

local TRAIT_ID = "UniversalTraits:UT_<id>"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    -- effect (transient state like applyCarryWeight)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
```

Use `OnNewGame` only for one-time spawn effects (moddata flags, spawn conditions).
Use `OnCreatePlayer` for anything that sets transient engine state (carry weight, handler registration).

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

### UT_martial.lua (public API)

- `UT_martial.applyBonusDamage(player, target, endurance)` → damage dealt (0 if mundane) — calculates bonus damage using Small Blunt skill, crit chance `(5 + level*5)%`, crit multiplier 6×0.1=0.6 vs normal 2×0.1=0.2, all scaled by endurance (×0.35 at 0 to ×1.35 at 1.0)

### UTCore_SpawnEffects.lua

- `UTCore.applySpawnStats(player, statTable)` — keys: `"panic"`, `"stress"`, `"hunger"`, `"thirst"`, `"fatigue"`, `"endurance"`, `"carryDelta"`
- `UTCore.applySpawnCondition(player, conditionTable)` — keys: `injuries={bodyPartIds}`, `fractures={bodyPartIds}`, `burnSeverity=float`

### UTCore_Events.lua

- `UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)` — idempotent per trait+event pair (one trait can now register multiple different events safely)
- `UTCore.unregisterPeriodicHandler(traitId, intervalEvent?)` — removes one trait+event pair or all handlers for that trait when no event is provided
- `intervalEvent` values: `"EveryOneMinute"`, `"EveryTenMinutes"`, `"EveryHours"`, `"OnPlayerUpdate"`

### Vehicle trait helpers

- `UTCore.registerVehicleTrait(traitId, stateKey, mods, priority)` — registers an event-driven vehicle trait definition; higher priority wins if multiple vehicle traits are active
- `UTCore.syncVehicleTrait(player, vehicle?)` — applies the selected registered vehicle trait from cached baseline values on vehicle enter or save-load
- `UTCore.restoreVehicleMod(vehicle)` — restores cached baseline vehicle stats on exit
- `UTCore.applyVehicleMod(player, stateKey, mods, vehicleOverride?)` — low-level baseline-based apply helper used by `syncVehicleTrait`

### UTCore_XPHook.lua

- Registered via `Events.AddXP` — reads `UT_xpMult_<perk>`, `UT_xpDisable_<perk>`, `UT_multiSkillPenalty` from moddata and applies corrections automatically
- `UTCore._xpPerksThisMinute` — exposed for test resets

### UTCore_SpeedHook.lua

- Registered via `Events.OnPlayerMove` — reads `UT_speedMod` from moddata and applies position delta multiplication automatically
- Teleport guard: skips if delta > 5 tiles

### UTCore_WorkSpeedHook.lua

- `UTCore.applyWorkDuration(timedAction, base)` → number — applies `UT_workSpeedMod` and (for ISReadABook) `UT_readSpeedMod` to a TimedAction duration
- Registered via `Events.OnGameBoot` to patch all TimedAction `getDuration()` calls globally

### UTCore_ReadingHook.lua

- Registered via `Events.OnGameBoot` to patch `ISReadABook.start`, `update`, `stop`, and `perform` when present
- `UTCore.getSkillBookCompletionXP(item)` → number — returns the flat completion XP bonus for a skill book tier: 2/4/6/8/10 → 12/30/65/120/200
- `UTCore.applyReadingMoodEffects(player, tickScale)` — for reading traits, clears panic/stress and reduces boredom/unhappiness while reading
- `UTCore.tryAwardSkillBookCompletionXP(player, item, startPages, endPages)` → number — awards the flat XP bonus once when a skill book crosses from incomplete to fully read
- Used by `UT_photographicmemory` for fast reading, calm while reading, mood gain while reading, and flat skill-book completion XP

### UTCore_BleedHook.lua

- Registered via `Events.OnPlayerUpdate` (throttled every 30 ticks) — reads `UT_bleedMult` from moddata and applies BodyPart health corrections automatically
- `UTCore._bleedTickCounter` — exposed for test resets

### UTCore_BleedDecayHook.lua

- Registered via `Events.OnPlayerUpdate` (every tick — no throttle) — reads `UT_bleedDecayMult` and `UT_bleedDecayBandagedOnly` from moddata
- Adjusts `bleedingTime` on each body part to multiply the native decay rate:
  - `mult=3.0` → 3× faster wound healing (staunch trait)
  - `mult=0.33` → 3× slower wound healing (anemic trait)
- `bandagedOnly=true` → only affects bandaged body parts
- Uses native decay constants: bandaged = 0.0002, unbandaged = 0.00002 (per tick × gameMultiplier)

### UTCore_BleedDrainHook.lua

- Registered via `Events.OnPlayerUpdate` (throttled every 30 ticks) — reads `UT_bleedDrainMult` from moddata
- Offsets player general health to scale the effective bleed death rate:
  - `mult=2.0` → doubles bleed death rate (heavilybleedingwounds)
  - `mult=0.5` → halves bleed death rate (thickblood)
- Only active when at least one body part has `bleeding() == true`
- Estimates native drain per tick using per-body-part scalers (Neck = 5× standard)
- `UTCore._bleedDrainTickCounter` — exposed for test resets

### UTCore_MeleeDelayHook.lua

- Registered via `Events.OnPlayerUpdate` + `Events.OnWeaponHitCharacter`
- Reduces melee swing delay for weapon-category traits (axes, blunts, blades, spears, two-handed, one-handed) — standard traits get 50% delay reduction
- `UT_heavyswing` uses strength-scaled reduction: `delay * (strength × 0.1)`
- Uses `UT_meleeDelaySet` moddata flag to prevent re-application within a swing; cleared on `OnWeaponHitCharacter`
- `UTCore._meleeDelayOnPlayerUpdate` — exposed for direct test invocation

### UTCore_ZombieCollisionHook.lua

- Detects the **rising edge** of `player:isBumped()` with a zombie as the bump source
- On each real zombie collision (false→true transition of `isBumped()`), confirms the bumped entity is a zombie via `pcall(chr:isAlwaysKnockedDown())` — `isAlwaysKnockedDown()` is exclusive to `IsoZombie`, so pcall success = zombie type confirmed
- Fires all registered callbacks with `(player, zombie)` before the native stagger animation locks in
- **Cannot be throttled** — rising-edge detection requires checking every tick (exception to the throttle rule)
- `UTCore._zombieCollisionCallbacks` — table of `traitId → fn(player, zombie)`

#### Declare API (preferred for traits)

- `UTCore.declareZombieCollisionHandler(traitId, fn)` — **preferred trait API**; call at file-load time. Stores the handler in a local `_declarations` upvalue (not on UTCore table — cannot be accidentally cleared)
- On `Events.OnCreatePlayer`, UTCore iterates all declarations and auto-registers handlers for traits the player has via `UTCore.hasTrait()`
- Integrity self-healing via `Events.EveryOneMinute` — every 10 game-minutes (~10 real seconds), checks declared handlers against `_zombieCollisionCallbacks` and re-registers any that are missing
- Trait files need only one line: `UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)` — no OnCreatePlayer/OnNewGame boilerplate

#### Low-level API (internal / advanced use)

- `UTCore.registerZombieCollisionHandler(traitId, fn)` — directly register a callback
- `UTCore.unregisterZombieCollisionHandler(traitId)` — remove callback
- Cancel native stagger from inside a callback: `player:setBumpType("")` + `player:setBumpFall(false)`

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
- `player:isBumped()` → bool — true while `getBumpType()` is non-empty (player is mid-collision stagger state)
- `player:getBumpedChr()` → IsoGameCharacter — entity that caused the bump, or nil
- `player:setBumpType("")` — clears `isBumped()`; cancels the stagger movement-block
- `player:setBumpFall(false)` — prevents the trip/fall animation from playing
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

### Zombie (`IsoZombie`)

- `zombie:knockDown(fromBehind)` — knock the zombie to the ground; `false` = from front. Confirmed B42 (IsoZombie.java line ~4901)
- `zombie:isAlwaysKnockedDown()` → IsoZombie-exclusive method; **exists ONLY on IsoZombie, not on IsoPlayer or IsoGameCharacter**. Use `pcall(chr:isAlwaysKnockedDown())` as a zombie type discriminator: pcall success = zombie
- `zombie:getHealth()` / `setHealth(v)` — direct health manipulation
- `zombie:isKnockedDown()` → bool

### Events

- `Events.OnCreatePlayer.Add(fn)` — fn receives `(playerIndex, player)` — fires on **both** new game AND save load. Use this for conditional handler registration (preferred over `OnNewGame` for ongoing handlers)
- `Events.OnNewGame.Add(fn)` — fn receives `(player)` — **new game only, does NOT fire on save load**. Use only for one-time spawn effects
- `Events.OnGameStart.Add(fn)` — no args — fires on both new game and save load, after `OnCreatePlayer`
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

### Conditional handler registration (preferred for ongoing handlers)

For traits with event-driven or collision callbacks, prefer registering the handler
only when the trait is active instead of always-register-check-inside:

```lua
local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.registerSomeHandler(TRAIT_ID, myCallback)
end
Events.OnCreatePlayer.Add(onCreatePlayer)
```

**Why `OnCreatePlayer` not `OnNewGame`:** `OnNewGame` only fires on new character creation.
Loading a save does NOT re-fire `OnNewGame`, so handlers registered there silently break.
`OnCreatePlayer` fires on both new game and save load.

**When NOT to use this:** Simple periodic checks (`EveryOneMinute`, `EveryTenMinutes`)
that do one-off moddata reads. The `hasTrait` check inside is cheap enough and the
always-register pattern is simpler. Reserve conditional registration for high-frequency
paths (`OnPlayerUpdate`) or callback systems (collision hooks).

### Periodic handler throttling

**Rule:** No OnPlayerUpdate handler without a moddata tick counter throttle.
Minimum throttle: every 15 ticks for high-frequency checks, 30 ticks for normal.
Prefer `EveryOneMinute` / `EveryTenMinutes` over OnPlayerUpdate when real-time is not needed.

**Exception:** Rising-edge detection (e.g., `UTCore_ZombieCollisionHook`) cannot be throttled — missing a single tick would skip the transition. These handlers must be lightweight: nil check + two boolean comparisons + early return covers 99%+ of ticks.

### Moddata key convention

All UT_ moddata keys are prefixed `UT_` to avoid collision with vanilla and other mods.
Examples: `UT_speedMod`, `UT_bleedMult`, `UT_indefCooldown`.

Additional reading/XP keys:
- `UT_xpMult_All` — global XP multiplier applied to all perks by `UTCore_XPHook`
- `UT_readCalm` — if true, reading forces panic and stress to 0 via `UTCore_ReadingHook`
- `UT_readMoodBonus` — per-tick boredom/unhappiness reduction while reading

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

- `UT_CORE/test/UTCoreMocks.lua` is now just a thin loader around `UniversalTraits/test/UTTestMocks.lua`, so there is one shared `MockPlayer` / event implementation for both suites.
- `UniversalTraits/test/UTTestMocks.lua` now has controllable `ZombRand`, mock game time (`getWorldAgeHours()`, `getTicks()`), vehicle mocks, nutrition mocks, body-part mocks, timed-action mocks, and functional `registerPeriodicHandler` / `registerVehicleTrait` stubs. Prefer those shared helpers over ad-hoc per-test stubs when adding more Phase 2/3 trait coverage.

- Vehicle traits no longer poll every `OnPlayerUpdate`. They now register once and apply on vehicle enter / player creation, then restore the cached baseline on vehicle exit.

For trait metadata integrity, test the script file directly when the bug lives in `UT_character_traits.txt` rather than runtime Lua. The character creator null-crash (`isFree of non-table: null`) came from broken script-side `MutuallyExclusiveTraits`, not from `UT_MET.lua` itself.

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
