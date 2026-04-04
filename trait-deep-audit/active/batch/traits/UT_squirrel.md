# UT_squirrel

## Trait Summary

- UT trait id: `UniversalTraits:UT_squirrel`
- Source mod: SomewhatTraits (`SomewhatTraitsCore` runtime + `SomewhatTraits` definition)
- Source trait id: `SWTraits:SWSquirrel` (`SWSquirrel`)
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 225-236) — current B42 runtime
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (grep-confirmed `SWSquirrel()` legacy implementation) — older runtime naming continuity
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (lines 129-137) — current script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 91, 116) — legacy addTrait + mutual exclusion
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 30-31) — source EN text
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/SWTraits_MET.lua` (lines 70-73) — source runtime mutual exclusion
- Source trigger path:
  - `Events.OnTick.Add(SWSquirrel)` in source runtime.
  - Handler gates on active player, trait possession, and `running or sprinting` before applying the effect.
- Source behavior:
  - Source description: `"Slows down fatigue gain when running or sprinting."`
  - Source runtime removes fatigue by `dayLengthMultiplier * 0.0015` while running or sprinting.
  - Source halves that benefit if the player has vanilla `Needs Less Sleep` or `Needs More Sleep`.
  - Source cost is `2`.
  - Source made `SWSquirrel` mutually exclusive with `SWSloth`.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_squirrel = CharacterTrait.register("UniversalTraits:UT_squirrel")`.
- Defined in UT_character_traits.txt: yes —
  ```
  character_trait_definition UniversalTraits:UT_squirrel
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_squirrel,
      Cost = 2,
      UIName = UI_UT_squirrel,
      UIDescription = UI_UT_squirrelDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_packmouse;UniversalTraits:UT_topheavy,
  }
  ```
- Translation strings present: yes —
  - `UI_UT_squirrel = "Squirrel"`
  - `UI_UT_squirrelDesc = "You hoard everything you find, even when it weighs you down. Carry weight is increased but so is the tendency to overload."`
- Exclusions/grants correct: **no** — current exclusions are `UT_packmouse` and `UT_topheavy`, but the source exclusion was `SWSloth`; UT currently omits `UT_sloth` entirely.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_squirrel.lua`

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_squirrel.lua` (entire file)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` — periodic wrapper
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait`
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)`
  - Effective PZ event path: `Events.EveryOneMinute`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe trait check via `player:getTraits():contains(traitId)`.
  - `UTCore.registerPeriodicHandler(...)` — stores a trait+event wrapper and resolves `getPlayer()` at fire time.
- Runtime chain (plain language):
  1. On file load, the trait registers a periodic handler for `EveryOneMinute`.
  2. Each minute, UTCore resolves the active player and calls `handler(player)`.
  3. Guard 1: if the player lacks `UniversalTraits:UT_squirrel`, exit.
  4. Guard 2: if the player is neither running nor sprinting, exit.
  5. Otherwise, get player stats and call `stats:remove(CharacterStat.FATIGUE, GameTime.getInstance():getMultiplier() * 0.0015)`.
- Actual behavior (exact values):
  - **Trigger:** only while actively running or sprinting at the event tick.
  - **Cadence:** once per in-game minute in UT, versus every tick in source.
  - **Effect value:** removes fatigue by `GameTime.getInstance():getMultiplier() * 0.0015` per minute tick.
  - **Missing source rule:** UT does not halve the benefit for `Needs Less Sleep` / `Needs More Sleep`.
  - **No carry-weight mechanic exists.** UT does not change `MaxWeightBase`, inventory capacity, or overload thresholds.

## Description Integrity

- Display name check: `Squirrel` matches source intent.
- Description check: current UT text is unrelated to the implemented mechanic.
- Missing or misleading details:
  1. **Wrong mechanic:** the current description claims a hoarding/carry-weight effect, but runtime only reduces fatigue while running or sprinting.
  2. **Missing real trigger:** the active condition (`running or sprinting`) is omitted.
  3. **Missing real benefit:** the fatigue reduction is not mentioned at all.
  4. **Source drift hidden:** source text was short but accurate; UT replaced it with text that appears copied from a different inventory-themed trait concept.

## Balance Review

- Upside: conditional fatigue reduction while running or sprinting.
- Downside: none; this is a positive trait costing 2 points.
- Uptime: moderate for players who run/sprint often, low for cautious walkers.
- Peer comparison:
  - Direct opposite/source partner is `UT_sloth`, which helps when walking or idle. Source treated them as mutually exclusive complements.
  - Compared with source, UT is mechanically weaker because it fires only every in-game minute instead of every tick and omits the sleep-trait interaction.
- Stack or exclusion notes:
  - Missing `UT_sloth` exclusion allows players to take both movement-fatigue reducers together, which the source explicitly prevented.
  - Current exclusions with `UT_packmouse` and `UT_topheavy` do not match the runtime behavior and look unjustified from available evidence.
- Cost verdict: **questionable**. Cost `2` may still be acceptable for a modest active fatigue benefit, but UT currently underdelivers versus source while also advertising the wrong upside.

## Regression Proof

- Existing test: registration/inventory only — `UniversalTraits/test/run_tests.lua` includes `"UniversalTraits:UT_squirrel"` in the expected trait ID sweep.
- What it proves: only that the trait ID is present in the registry/script integrity set.
- Missing proof:
  - No test that `EveryOneMinute` removes fatigue while running.
  - No test that sprinting also qualifies.
  - No test that walking/idle does nothing.
  - No test for no-trait guard.
  - No test documenting the current cadence simplification versus source.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_squirrel.lua")

  test("UT_squirrel reduces fatigue while running", function()
      local stats = { removed = 0, remove = function(self, stat, amount)
          assert_eq(stat, CharacterStat.FATIGUE)
          self.removed = self.removed + amount
      end }
      local p = MockPlayer({ "UniversalTraits:UT_squirrel" }, { stats = stats })
      p:setRunning(true)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_true(stats.removed > 0, "expected fatigue reduction while running")
  end)
  ```
  Add companion tests for sprinting, no-trait, and idle guards.

## Final Verdict

- Source origin: **proven**
- UT implementation: **drifted** — broad running-fatigue concept remains, but cadence is much weaker, sleep-trait interaction is dropped, and exclusions no longer match source.
- Description: **misleading** — current text describes a nonexistent carry/hoarding mechanic.
- Balance: **questionable**
- Regression proof: **missing**
- Action needed: **doc fix**, **test fix**, **code/design review**
- Open gaps:
  - Need a design decision on whether the source `UT_sloth` mutual exclusion should be restored.
  - Need a design decision on whether the source sleep-trait halving rule was intentionally removed.
  - Need confirmation whether current `UT_packmouse` / `UT_topheavy` exclusions were deliberate or accidental carry-over.
