# UT_sloth

## Trait Summary
- UT trait id: `UniversalTraits:UT_sloth`
- Source mod: SomewhatTraits
- Source trait id: `SWSloth`
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: materially advanced - correction gaps identified

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` lines 89, 116
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI.json` lines 26-27
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` lines 31-53, 200-211
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` lines 332-348
- Source trigger path:
  - `SWSloth()` runs from a staggered `Events.OnTick` dispatcher and exits while running or sprinting.
- Source behavior:
  - Positive trait, cost `+2`.
  - Source UI text: `Sloth` / `Slows down fatigue gain when walking or standing still.`
  - While not running or sprinting, source removes fatigue by `dayLengthMultiplier * 0.0005`.
  - The 42.12 client path also halves the effect for vanilla sleep traits.
  - Source mutual exclusion: `SWSloth` <-> `SWSquirrel`.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes - `CharacterTrait.register("UniversalTraits:UT_sloth")` at `UniversalTraits/media/registries.lua` line 127.
- Defined in UT_character_traits.txt: yes - lines 969-977, cost `2`, `DisabledInMultiplayer = true`.
- Translation strings present: yes - `UI_UT_sloth = Sloth` and `UI_UT_slothDesc = Extreme laziness has kept you from developing any physical fitness. Fitness is at its lowest.`
- Exclusions and grants correct: no.
  - Source excludes `SWSquirrel`.
  - UT has no `MutuallyExclusiveTraits` entry for `UT_sloth`.
  - `UT_MET.lua` has no `UT_sloth` grouping.
  - `UT_squirrel` is exclusive with `UT_packmouse` and `UT_topheavy`, not `UT_sloth`.
- Runtime Lua file exists: yes - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sloth.lua`.

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sloth.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua`
  - `UniversalTraits/test/UTTestMocks.lua` lines 255-290
- Current runtime:
  ```lua
  local function handler(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      if player:isRunning() or player:isSprinting() then return end
      local stats = player:getStats()
      stats:remove(CharacterStat.FATIGUE, GameTime.getInstance():getMultiplier() * 0.0005)
  end

  UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
  ```
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)`
- Runtime chain:
  1. UT registers one `EveryOneMinute` wrapper for `UniversalTraits:UT_sloth`.
  2. UTCore resolves `getPlayer()` each minute.
  3. Trait exits if the player lacks `UT_sloth`.
  4. Trait exits if the player is running or sprinting.
  5. Otherwise it removes fatigue by `GameTime.getInstance():getMultiplier() * 0.0005`.
- Actual behavior:
  - Active while idle or walking.
  - Inactive while running or sprinting.
  - No persistent state or modData.
  - UT omits the source sleep trait adjustment.
  - At time multiplier `1`, effect is `0.0005` fatigue removed per in game minute, about `0.03` per in game hour.
- Drift from source:
  1. Source cadence is `OnTick`; UT simplifies to `EveryOneMinute`.
  2. Source sleep trait reduction is omitted.
  3. Source `Sloth <-> Squirrel` exclusion is omitted.

## Description Integrity
- Display name: accurate.
- Current description: misleading.
- Why:
  1. It claims poor physical fitness and lowest Fitness.
  2. Runtime does not reduce Fitness, XP, or max endurance.
  3. Real effect is a conditional fatigue reduction benefit.
- Correct description should say the trait slows fatigue gain while walking or standing still.

## Balance Review
- Upside: passive fatigue reduction outside running and sprinting.
- Downside: no direct downside beyond spending 2 points.
- Reliability: high; the hook is simple and state free.
- Cost verdict: questionable.
  - `+2` is plausible.
  - But the missing `UT_squirrel` exclusion lets players stack both movement fatigue benefits, weakening the intended specialization tradeoff.

## Regression Proof
- Existing proof:
  - `UniversalTraits/test/run_tests.lua` line 232 includes `UniversalTraits:UT_sloth` in the registration smoke test list.
- Missing proof:
  - No test fires `Events.EveryOneMinute` for `UT_sloth`.
  - No test proves idle activation.
  - No test proves running suppression.
- Minimum missing test:
  ```lua
  test("UT_sloth reduces fatigue while idle", function()
      local p = MockPlayer({ "UniversalTraits:UT_sloth" }, { fatigue = 0.5 })
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_true(p:getStats():getFatigue() < 0.5)
  end)

  test("UT_sloth does not fire while running", function()
      local p = MockPlayer({ "UniversalTraits:UT_sloth" }, { fatigue = 0.5 })
      p._running = true
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_eq(p:getStats():getFatigue(), 0.5)
  end)
  ```

## Final Verdict
- Source origin: proven
- UT implementation: simplified
- Description: misleading
- Balance: questionable
- Regression proof: missing
- Action needed: code fix

- Top correction gaps:
  1. Fix the description to match the actual fatigue reduction effect.
  2. Restore mutual exclusion with `UT_squirrel` in script definitions, and optionally mirror it in `UT_MET.lua`.
  3. Add runtime tests for idle activation and running suppression.
  4. Decide whether omitting the source sleep trait adjustment is intentional simplification or drift.
