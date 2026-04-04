# UT_lesssweaty

## Trait Summary
- UT trait id: `UniversalTraits:UT_lesssweaty`
- Source mod: MoreSimpleTraits (`MSTMainFile.lua`)
- Source trait id: `LessSweaty` (unnamespaced vanilla-style string)
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` — function `lesssweatytrait()` (lines 924–974) and helper `MSTdecreaseWetness()` (lines 102–110); `Events.EveryOneMinute.Add(lesssweatytrait)` at line 1124
- Source trigger path:
  - `lesssweatytrait()` — wired directly to `Events.EveryOneMinute`. Fires once per in-game minute.
- Source behavior:
  - Reads `player:getBodyDamage():getWetness()` and `getClimateManager():getRainIntensity()`.
  - Guard: only runs if `player:HasTrait("LessSweaty")` and `currentWetness > 0` and `not player:isAsleep()`.
  - Branches by location/rain, applying `MSTdecreaseWetness(player, chance, wetness)` where the helper only executes if `ZombRand(chance) == 0` (so `chance=0` means a 1-in-1 = certain reduction; larger values are smaller probability).
    - **Indoors or in a vehicle** (condition: `not player:isOutside() or not player:getVehicle() == nil`): always applies.
      - Walking/idle: `MSTdecreaseWetness(player, ZombRand(2), ZombRand(2))` — `ZombRand(2)` produces 0 or 1, so ~50% chance to reduce, reducing by 0 or 1 (expected ~0.5 wetness units/min indoors at idle). Note: the `chance` itself is already a `ZombRand`, making the actual probability highly variable; see issues below.
      - Running: `MSTdecreaseWetness(player, ZombRand(4), ZombRand(1))` (~25% chance, reduce by 0).
      - Sprinting: `MSTdecreaseWetness(player, ZombRand(4), ZombRand(2))` (~25% chance, reduce by 0 or 1).
    - **Outside, rain intensity < 0.10**:
      - Walking/idle: `MSTdecreaseWetness(player, ZombRand(2), ZombRand(2))`.
      - Running: `MSTdecreaseWetness(player, ZombRand(4), ZombRand(1))`.
      - Sprinting: `MSTdecreaseWetness(player, ZombRand(4), ZombRand(2))`.
    - **Outside, rain intensity > 0.10** (rain):
      - Walking/idle: `MSTdecreaseWetness(player, ZombRand(4), ZombRand(2))`.
      - Running: `MSTdecreaseWetness(player, ZombRand(6), ZombRand(1))`.
      - Sprinting: `MSTdecreaseWetness(player, ZombRand(6), ZombRand(2))`.
  - `MSTdecreaseWetness` implementation: subtracts `wetness` from current wetness only when `chance == 0`; clamps result to 0. Both arguments are `ZombRand()` results, so the reduction is stochastic and small (0–2 raw wetness units per trigger on vanilla wetness scale).
  - Note: the source condition `not player:getVehicle() == nil` is a Lua operator precedence bug — it evaluates as `(not player:getVehicle()) == nil` which is always false. The indoors/vehicle branch is therefore only entered when `not player:isOutside()`.
  - Source cost: not directly extractable from this file (script definition not reviewed in installed-mods — see below).
  - Source multiplayer flag: not reviewed; MST is singleplayer-focused.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_lesssweaty = CharacterTrait.register("UniversalTraits:UT_lesssweaty")` at line 132, between `UT_sundayrunner` and `UT_highsweaty`
- Defined in UT_character_traits.txt: yes —
  ```
  character_trait_definition UniversalTraits:UT_lesssweaty
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_lesssweaty,
      Cost = 2,
      UIName = UI_UT_lesssweaty,
      UIDescription = UI_UT_lesssweatyDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_highsweaty,
  }
  ```
- Translation strings present: yes —
  - `UI_UT_lesssweaty = "Less Sweaty"` (UI_EN.txt line 299)
  - `UI_UT_lesssweatyDesc = "You don't sweat much even under exertion. Wetness from physical activity is significantly reduced."` (UI_EN.txt line 300)
  - Both strings are also present in `Translate/EN/UI.json` at lines 162–163.
- Exclusions/grants correct: `MutuallyExclusiveTraits = UniversalTraits:UT_highsweaty` — mutually exclusive with its paired opposite trait. Correct; these are a positive/negative pair on the same stat axis.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_lesssweaty.lua` (24 lines)

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_lesssweaty.lua` (full 24 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` — `UTCore.registerPeriodicHandler` implementation (lines 16–42)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–16)
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)` — uses the UT wrapper; cadence is `Events.EveryOneMinute`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper: returns false if player is nil or `player:getTraits()` is nil; otherwise calls `traits:contains(traitId)`. Full namespaced ID `"UniversalTraits:UT_lesssweaty"` is used.
  - `UTCore.registerPeriodicHandler` — registers via a unique key `traitId .. "::" .. intervalEvent`; idempotent; wraps handler in a closure that calls `getPlayer()` at runtime and passes it to `handler(player)`; adds to `Events[intervalEvent]`.
- Runtime chain (plain language):
  1. At module load time `UTCore.registerPeriodicHandler("UniversalTraits:UT_lesssweaty", "EveryOneMinute", handler)` is called. The wrapper registers the closure with `Events.EveryOneMinute`.
  2. Every in-game minute PZ fires `Events.EveryOneMinute`.
  3. The UTCore closure calls `getPlayer()` and passes the result to `handler(player)`.
  4. Guard 1: `UTCore.hasTrait(player, TRAIT_ID)` — if player does not have `UniversalTraits:UT_lesssweaty`, exit.
  5. Guard 2: `player:isSleeping()` — if sleeping, exit. No reduction while asleep.
  6. Guard 3: `player:getBodyDamage()` — if nil (shouldn't happen in normal play), exit.
  7. Guard 4: `bd:getWetness() <= 0` — if already dry, exit.
  8. Determine reduction amount based on weather/location:
     - Default (indoors): `reduction = 0.03`
     - Outside AND raining (`player:isOutside() and isRaining()`): `reduction = 0.005`
     - Outside AND NOT raining (`player:isOutside()` only): `reduction = 0.015`
  9. Apply: `bd:setWetness(math.max(0, wetness - reduction))` — clamps to 0 minimum.
- Actual behavior (exact values):

  | Situation | Reduction per minute | Notes |
  |---|---|---|
  | Indoors / in vehicle | −0.03 wetness/min | Default case; fastest drying |
  | Outside, no rain | −0.015 wetness/min | Half indoors rate |
  | Outside, raining | −0.005 wetness/min | Minimal; rain is refilling wetness simultaneously |

  - Wetness range in PZ is 0.0–1.0 (float). 1.0 = fully soaked.
  - At the indoors rate of 0.03/min: from fully soaked (1.0) to dry (0.0) takes ~33 minutes of continuous indoor non-sleeping presence.
  - At the outdoor dry rate of 0.015/min: from 1.0 to 0.0 takes ~67 minutes outdoors in no rain.
  - At the outdoor rain rate of 0.005/min: effectively counteracted by rain; wetness will still climb unless rain input is very low.
  - No movement-speed branching. Unlike the source, UT applies a fixed reduction regardless of whether the player is walking, running, or sprinting.
  - No random chance element. Unlike the source's `ZombRand` stochastic model, UT applies a deterministic flat reduction every minute.
  - `DisabledInMultiplayer = true` — trait absent from MP character creation; singleplayer only. The `getPlayer()` pattern in the UTCore wrapper is consistent with this.

## Description Integrity
- Display name check: UT uses "Less Sweaty"; source trait string is `"LessSweaty"`. Name is accurate and consistent.
- Description check: "You don't sweat much even under exertion. Wetness from physical activity is significantly reduced."
- Assessment:
  1. **Slightly misleading framing**: The description focuses on "sweating" and "physical activity" as the wetness source. In practice the UT trait reduces *all* wetness accumulation (rain wetness included, however marginally). The phrasing implies only exertion-based wetness is affected, which is not how `bd:getWetness()` works — wetness is a single unified float regardless of source.
  2. **Missing**: No mention that the trait is inactive while sleeping.
  3. **Missing**: No mention of reduced effectiveness when it is actively raining (0.005/min vs 0.03/min indoors). The rain branch barely makes a dent and the player might expect "significantly reduced" to hold in all conditions.
  4. **Acceptable**: "significantly reduced" is a fair characterization for the indoors case (0.03/min off vs the base rate). The outdoor-rain case is nearly irrelevant due to rain refilling wetness faster than 0.005/min removes it, but documenting this in-description would be overspecifying.

## Balance Review
- Upside: passively drains wetness every minute when awake, regardless of location. Reduces the nuisance of wetness moodles and the infection/temperature penalties that come with prolonged wetness.
- Downside: none — positive trait, costs 2 points.
- Uptime: nearly always active while awake. Sleeping suspends it, but sleeping players are not accumulating wetness from activity anyway. Effective for all play styles.
- Rate analysis:
  - PZ vanilla wetness accumulates from rain, wading, and sweating. The natural drying rate indoors (without clothing changes) is slow enough that wetness can persist for many in-game minutes. A flat −0.03/min is a meaningful accelerant.
  - In rain, the 0.005/min reduction is near-irrelevant — rain at moderate intensity will increase wetness by more than that per minute. The trait provides almost no benefit during active rainfall, which limits its usefulness in wet climate conditions (e.g., autumn/winter Kentucky rain).
  - The trait is strongest for players who frequently go outside in rain (it helps them dry faster afterward indoors) and weakest for players who spend most time outdoors in wet weather.
- Peer comparison:
  - `UT_highsweaty` (mutually exclusive counterpart): cost -3, presumably accelerates wetness accumulation. The asymmetry of cost (+2 for less vs -3 for more) implies the designers consider excess sweating a stronger downside than reduced sweating is an upside. This is reasonable — wetness is a nuisance stat rather than a win condition.
  - No XPBoosts, no skill bonuses, no inventory effects — purely a quality-of-life passive.
- Cost verdict: **2 points is defensible but arguably low**. The trait is on all the time (while awake), has no situational conditions beyond rain, and reduces a genuine nuisance stat. It competes in value with traits like `UT_packmule` (extra carry weight). However, wetness is a secondary concern compared to health, panic, and fatigue — 2 points is likely correct. **Acceptable at 2.**

## Regression Proof
- Existing test: `"UniversalTraits:UT_lesssweaty"` appears in the Phase 1 Stat Modifiers block at `test/run_tests.lua` line 235, within the smoke-test all-trait-IDs list.
- Grouped as: Stat Modifiers (20), alongside `UT_highsweaty`.
- What it proves: (1) `CharacterTrait.register("UniversalTraits:UT_lesssweaty")` has been called and the ID is present in the registry; (2) the script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves.
- Missing proof: No runtime handler test. The `handler()` logic — guard conditions (sleeping, wetness <= 0, no body damage), the three reduction values (0.03 / 0.015 / 0.005), the `isRaining()` / `isOutside()` branch logic, and the `math.max(0, ...)` floor — are entirely untested.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_lesssweaty.lua")

  test("UT_lesssweaty: indoors, awake, wet — reduces wetness by 0.03", function()
      local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:setOutside(false)
      p:setSleeping(false)
      setRaining(false)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_near(p:getBodyDamage():getWetness(), 0.47, 0.001, "indoors reduction should be 0.03")
  end)

  test("UT_lesssweaty: outside, no rain — reduces wetness by 0.015", function()
      local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:setOutside(true)
      p:setSleeping(false)
      setRaining(false)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_near(p:getBodyDamage():getWetness(), 0.485, 0.001, "outdoor no-rain reduction should be 0.015")
  end)

  test("UT_lesssweaty: outside, raining — reduces wetness by 0.005", function()
      local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:setOutside(true)
      p:setSleeping(false)
      setRaining(true)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_near(p:getBodyDamage():getWetness(), 0.495, 0.001, "outdoor rain reduction should be 0.005")
  end)

  test("UT_lesssweaty: sleeping — no reduction", function()
      local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:setSleeping(true)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_eq(p:getBodyDamage():getWetness(), 0.5, "sleeping players should not be dried")
  end)

  test("UT_lesssweaty: already dry — no change, no underflow", function()
      local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" })
      p:getBodyDamage():setWetness(0)
      p:setOutside(false)
      p:setSleeping(false)
      setRaining(false)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_eq(p:getBodyDamage():getWetness(), 0, "wetness should not go below 0")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreSimpleTraits `lesssweatytrait()` in `MSTMainFile.lua`. Source used a stochastic `ZombRand`-based model with movement-speed branching (idle / running / sprinting) and rain intensity thresholds, applying small integer-step reductions via `MSTdecreaseWetness`. The source's `not player:getVehicle() == nil` condition is a Lua precedence bug that made the vehicle branch unreachable.
- UT implementation: clean simplification. Replaces the stochastic multi-branch source with a deterministic three-case branch (indoors 0.03 / outside-dry 0.015 / outside-rain 0.005) applied once per minute to the wetness float. Correctly uses `UTCore.registerPeriodicHandler` (consistent with the UT standard pattern) and `UTCore.hasTrait` for the trait guard. The sleeping guard and the `wetness <= 0` early-exit are both correct and present.
- Description: **acceptable with a minor gap**. The framing around "physical activity" slightly misrepresents the mechanic (wetness is a unified stat; the trait drains all wetness, not just sweat). The outdoor-rain branch (0.005/min) is effectively inert against active rain but is not worth calling out explicitly in a player-facing description. No rewrite strictly required.
- Balance: **acceptable at cost 2**. Always-on passive with near-zero conditions, counterbalanced by a weak rain-case. Slightly cheaper than might be warranted given the unconditional uptime, but wetness is a secondary nuisance stat — 2 is appropriate.
- Regression proof: **weak**. ID registration and script-block structure are covered. The runtime handler values, branch conditions, sleeping guard, and zero-clamp are entirely untested.
- Action needed:
  1. **Add runtime tests** per the minimum test block above, covering all three reduction branches plus sleeping and dry-floor guards.
  2. **Optional description tweak**: consider replacing "Wetness from physical activity" with "Your body's wetness level" or similar to accurately reflect that all wetness sources (rain included) are drained, not only sweat-origin wetness.
- Open gaps:
  - The outdoor-rain reduction (0.005/min) is nearly useless in moderate or heavy rain. If the intent is that the trait should meaningfully help during rain, the value may need to be raised (e.g., 0.01 or 0.02). If the intent is that rain wetness is simply harder to counter, the current value is intentional but should be validated against the game's actual rain wetness accumulation rate.
  - No movement-speed branching (unlike the source). Whether the source's idle/run/sprint distinction was meaningful or vestigial is unclear from the MST code given the `ZombRand`-on-`ZombRand` double-random pattern. The UT simplification is cleaner and likely correct.
  - Source had no multiplayer support; UT `DisabledInMultiplayer = true` is consistent and appropriate.
