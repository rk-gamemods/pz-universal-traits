# UT_addictedtocaffeine

## Trait Summary
- UT trait id: `UniversalTraits:UT_addictedtocaffeine`
- Source mod: Dynamic Traits Expanded Moodles (DynamicTraitsExpandedMoodles / Dynamic-Traits-main)
- Source trait id: `AddictedToCaffeine` (unnamespaced vanilla-style string)
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMAddictions.lua` — core caffeine addiction logic
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua` — per-minute tick dispatcher
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMoodles.lua` — caffeine moodle display
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMPillsTraits.lua` — caffeine-pill consumption hook
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/TimedActions/DTEMDrinkFluid.lua` — fluid-drink consumption hook
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/server/DTEMRecipeCode.lua` — food/coffee/hot-drink consumption hooks
  - `DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua` — moddata initialisation

- Source trigger path: `EveryOneMinute` event → `DTEMaddictedToCaffeineTrait(player)` called from `DTEMMainFile.lua` unconditionally each minute. The function lives in `DTEMAddictions.lua`.

- Source behavior: The source trait is a **dynamic** addiction that can be acquired or lost during gameplay, not selected at character creation. It uses two moddata counters:
  - `DTEMtimeSinceLastCaffeine` — incremented by 1 per minute; reset to 0 when caffeine is consumed; capped at 7500.
  - `DTEMcaffeineOnBody` — decremented by 1 per minute; incremented by a formula based on hunger/thirst/fatigue change when caffeine is consumed; clamped 0–2500.
  - `DTEMaddictedToCaffeineTrait` — a score clamped ±28800; decrements while caffeine is on the body, increments while in withdrawal (>1440 min dry); trait is added when score < −20160 and removed when score > 20160.

  While the trait is held and `DTEMcaffeineOnBody > 0` (caffeinated): stress −0.01, anger −0.01, fatigue −0.01 per minute. While the trait is held and `DTEMtimeSinceLastCaffeine > 1440` (withdrawal): stress +0.15, anger +0.15 per minute (probabilistic via `ZombRand`), headache pain applied, and daytime fatigue increase + night-time insomnia effect active. The source trait is a two-sided dynamic sim: caffeine relieves and withdrawal punishes.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
  (`UTTraitsRegistries.UT_addictedtocaffeine = CharacterTrait.register("UniversalTraits:UT_addictedtocaffeine")` at line 269)
- Defined in UT_character_traits.txt: yes
  (lines 1886–1894; Cost = -3, no MutuallyExclusiveTraits, no XPBoosts)
- Translation strings present: yes
  (`UI_UT_addictedtocaffeine = "Caffeine Addict"` and `UI_UT_addictedtocaffeineDesc = "Coffee is not a luxury, it is a necessity. Without caffeine, your focus crumbles and the headaches begin."`)
- Exclusions/grants correct: N/A — no mutual exclusions defined; no peer caffeine traits exist in UT to exclude.
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_addictedtocaffeine.lua` (19 lines, complete)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition

- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)` — fires every 10 in-game minutes

- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper; calls `player:getTraits():contains(traitId)`. Returns false if player is nil or traits list is nil.

- Runtime chain (plain language):
  1. Every 10 in-game minutes, `handler()` fires.
  2. Bail if `getPlayer()` returns nil.
  3. Bail if the player does not have the trait.
  4. Read `player:getModData()["UT_hadCaffeine"]`.
  5. If that key is **falsy** (nil or false): get `player:getStats()` and call `stats:setStress(math.min(1, stats:getStress() + 0.06))`.
  6. Unconditionally set `md["UT_hadCaffeine"] = nil`, clearing any previously set flag.

- Actual behavior (exact values):
  - **Penalty tick:** stress +0.06 every 10 in-game minutes (= +0.006 per in-game minute), capped at 1.0.
  - **Suppression:** if `md["UT_hadCaffeine"]` is truthy, the stress increment is skipped for that tick; the flag is then cleared, so the suppression lasts exactly one 10-minute window.
  - **CRITICAL BUG — deadCode flag:** `UT_hadCaffeine` is **never set to `true` anywhere in the entire codebase** (confirmed by exhaustive search across both the UniversalTraits repo and the full UTMods repo). The suppression branch (`if not md["UT_hadCaffeine"]`) is therefore unreachable dead code. The trait applies the stress penalty unconditionally on every tick, regardless of whether the player has recently consumed caffeine. There is no mechanic to relieve the penalty by drinking coffee.

## Description Integrity
- Display name check: "Caffeine Addict" — accurate and concise. No issues.
- Description check: "Coffee is not a luxury, it is a necessity. Without caffeine, your focus crumbles and the headaches begin." — implies the penalty is conditional on not having caffeine. This is **misleading**. The description implies relief is possible via caffeine consumption, but no such relief path exists in the current implementation. The `UT_hadCaffeine` flag that would enable relief is never set.
- Missing or misleading details:
  1. The description does not state the penalty is stress-only (no headache, no anger, no fatigue — unlike the source mod).
  2. The description implies a "without caffeine" condition that is currently non-functional.
  3. No indication that this is a permanent -0.06 stress every 10 minutes with zero counterplay.
  4. The description does not state the cadence (every 10 minutes).

## Balance Review
- Upside: none. This is a pure negative trait.
- Downside: +0.06 stress every 10 in-game minutes unconditionally. Over an in-game hour (6 ticks): +0.36 stress. This is an extremely fast stress accumulation with no mechanism to suppress it. At baseline stress 0, the player hits maximum stress (1.0) in approximately 167 in-game minutes (~2h 47m of game time) from trait alone.
- Uptime: 100%. The penalty fires every tick regardless of player actions. There is no window of relief.
- Peer comparison:
  - `UT_alcoholic_I` (-4 pts): stress +0.05 every **30** in-game minutes (fires every 10 min but only acts every 3rd tick, and only when drunkenness < 0.05). Has a clear suppression condition (drink to 0.05+ drunkenness).
  - `UT_alcoholic_II` (-7 pts): stress +0.10 every 10 minutes when drunkenness < 0.05. Has suppression condition.
  - `UT_alcoholic_III` (-10 pts): stress +0.05 every 10 minutes when drunkenness < 0.1, plus panic +0.03 when drunkenness < 0.05. Has suppression condition.
  - `UT_addictedtocaffeine` (-3 pts): stress +0.06 every 10 minutes, **no suppression condition, no counterplay**. This is stronger than alcoholic_I in stress-per-minute terms (+0.06/10min vs +0.05/30min = 3× faster), has no relief mechanic, yet costs only -3 vs -4. At equivalent real cost the caffeine trait is dramatically more punishing than alcoholic_I.
- Stack or exclusion notes: No mutual exclusions defined. Could be stacked with alcoholic traits for compounding stress.
- Cost verdict: **Underpriced and broken.** The intended design with caffeine suppression would suggest -3 to -4 is reasonable (permanent low-level stress with occasional relief). But as implemented, with unconditional 100%-uptime stress at 0.06/tick and no relief, the actual mechanical severity is closer to alcoholic_II (-7) or beyond. Cost should be -5 to -6 at minimum if the suppression mechanic is not fixed. If the bug is fixed, -3 may be appropriate but needs re-evaluation once the relief cadence is defined.

## Regression Proof
- Existing test: yes — the trait ID appears in the Phase 3b periodic-check block of `test/run_tests.lua` line 293. It is included in the "all 198 trait IDs registered with CharacterTrait" test, which confirms registration only.
- What it proves: the trait is registered with `CharacterTrait.register()` and the ID string is correctly spelled. Nothing else.
- Missing proof:
  1. No test that `handler()` fires and increments stress by 0.06 on `EveryTenMinutes`.
  2. No test that the suppression branch (`UT_hadCaffeine` truthy) skips the stress increment.
  3. No test that the flag is cleared after each tick (one-tick suppression window).
  4. No test that setting `UT_hadCaffeine = true` before a tick actually suppresses the penalty — which would immediately expose the fact that nothing sets this flag.
- Minimum next test if needed:
  ```lua
  -- Confirm stress increments exactly 0.06 per EveryTenMinutes tick
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_addictedtocaffeine.lua")
  test("UT_addictedtocaffeine increments stress by 0.06 per tick when no caffeine flag", function()
      local p = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" })
      p:getStats()._stress = 0.0
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_eq(p:getStats():getStress(), 0.06, "stress after one tick without caffeine flag")
  end)

  -- Confirm UT_hadCaffeine suppresses one tick then is cleared
  test("UT_addictedtocaffeine suppresses stress when UT_hadCaffeine is set", function()
      local p = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" })
      p:getStats()._stress = 0.0
      p:getModData()["UT_hadCaffeine"] = true
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_eq(p:getStats():getStress(), 0.0, "stress should not increase when UT_hadCaffeine is set")
      assert_eq(p:getModData()["UT_hadCaffeine"], nil, "UT_hadCaffeine should be cleared after tick")
  end)
  ```
  The second test will pass mechanically (the branch exists), but it cannot be exercised in play because nothing writes the flag. A third test proving a caffeine-consumption hook sets the flag is not possible until the hook is implemented.

## Final Verdict
- Source origin: Well-sourced. DynamicTraitsExpandedMoodles `AddictedToCaffeine` is a fully-featured dynamic addiction with acquisition/loss mechanics, withdrawal multi-stat penalties, relief via caffeine consumption, and insomnia effects. The source is a complex two-sided sim.
- UT implementation: Severely stripped. Only the withdrawal stress penalty is ported. The caffeine-on-body relief path exists as dead code (the `UT_hadCaffeine` flag check is present but the flag is never set by any hook anywhere in the codebase). The implementation delivers pure unconditional stress punishment with zero counterplay.
- Description: Misleading. Implies conditional penalty ("without caffeine") that is non-functional. Omits exact stat affected, omits cadence, omits the absence of any relief mechanic.
- Balance: Underpriced for current behavior. At -3 cost the trait fires +0.06 stress every 10 minutes with no suppression — more severe per minute than UT_alcoholic_I at -4. If the suppression mechanic is implemented as designed, -3 may be re-evaluated; without it the cost should be at least -5 to -6.
- Regression proof: Registered-ID test only. No behavioral coverage. The suppression dead-code path is entirely untested.
- Action needed:
  1. **Bug fix (critical):** Implement a caffeine-consumption hook that sets `md["UT_hadCaffeine"] = true` when the player eats or drinks a caffeine-containing item. Without this, the trait has no counterplay and the description is false.
  2. **Balance re-evaluation:** After the hook is implemented, run cadence math to verify -3 cost is appropriate given the expected relief frequency in a normal playthrough.
  3. **Description rewrite:** Replace vague flavour text with accurate mechanical description. State the stress penalty per tick and the suppression mechanic explicitly. Example: "Every 10 minutes without recent caffeine, stress increases by +0.06. Consuming coffee or tea suppresses one tick."
  4. **Tests:** Add the two behavioral tests above, plus a hook-integration test once the caffeine-consumption hook exists.
- Open gaps:
  - No caffeine-consumption hook exists anywhere (the `UT_hadCaffeine` setter is completely absent).
  - No definition of which items count as "caffeine-containing" for the hook's item filter.
  - No headache, anger, or fatigue effects from the source mod are ported; unknown if intentional simplification or oversight.
  - No insomnia mechanic (night-time fatigue reduction in withdrawal) from source is present.
  - Suppression window is one tick (10 in-game minutes); if hook is added, this design choice should be documented — a single coffee should suppress exactly one 10-minute window, which means frequent drinking is needed to fully neutralise the trait.
