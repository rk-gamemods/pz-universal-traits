# UT_adaptivemetabolism

## Trait Summary
- UT trait id: `UniversalTraits:UT_adaptivemetabolism`
- Source mod: SomewhatTraits (SomewhatFrog)
- Source trait id: `SWAdaptiveMetabolism`
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` — `"SWAdaptiveMetabolism", -- 5` (cost 5 at registration time)
  - `SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` — `TraitFactory.addTrait("SWAdaptiveMetabolism", ..., 5, ...)` and comment `--adjusts calorie burn rate when near unhealthy weight`
  - `SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` — `SWAdaptiveMetabolism()` handler, lines 70–85
  - `SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/SWTraits_MET.lua` — mutual exclusion wiring vs `CharacterTrait.WEIGHT_GAIN` and `CharacterTrait.WEIGHT_LOSS`
- Source trigger path:
  - `SWAdaptiveMetabolism()` is registered directly to `Events.OnTick` (line 85).
  - The file runs server-only (lines 7–9: `if client then return end`).
  - Tick cadence is throttled by a shared player-rotation timer: `currentTime > timestamp + timer` where `timer = 5000 / numPlayers` ms. In singleplayer this is effectively once per ~5 seconds of real time.
- Source behavior:
  - **Per tick (throttled ~5 s)**: reads `player:getNutrition()`. Gets `calories` and `weight`.
  - Computes `extraCalories = dayLengthMultiplier * 0.5`. `dayLengthMultiplier = baseDayLength / dayLength` where `baseDayLength = 60` and `dayLength = getSandboxOptions():getDayLengthMinutes()`. On default 1-hour days this is exactly `1.0`, so `extraCalories = 0.5`.
  - If `running or sprinting`, `extraCalories` is multiplied by 5 (becomes 2.5 on default day length).
  - If `weight < 77` and `calories < maxCalories (3600)`: `nutrition:setCalories(calories + extraCalories)` — adds calories when underweight.
  - Else if `weight > 83` and `calories > minCalories (-2100)`: `nutrition:setCalories(calories - extraCalories)` — removes calories when overweight.
  - The dead zone is `77 <= weight <= 83` — no caloric adjustment within the healthy range. This is the adaptive behaviour: the trait nudges calorie balance toward the 77–83 weight band by directly modifying the calorie counter rather than hunger stat.
  - Source cost: **5** (positive trait).
  - Source mutual exclusions (active): `WeightGain` (vanilla), `WeightLoss` (vanilla). All weight-body-type exclusions (Emaciated, Overweight, Obese, Underweight, Very Underweight) were commented out.
  - Source display name (from registration): `getText("UI_trait_SWAdaptiveMetabolism")`. Description referenced `getText("UI_trait_SWAdaptiveMetabolismDesc")` — actual strings not in the installed-mods index; content is not confirmed from source.
  - Source multiplayer: server-side handler, works in multiplayer (server-only execution, rotates through all online players).

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_adaptivemetabolism = CharacterTrait.register("UniversalTraits:UT_adaptivemetabolism")` at line 255
- Defined in UT_character_traits.txt: yes — lines 1743–1751:
  ```
  character_trait_definition UniversalTraits:UT_adaptivemetabolism
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_adaptivemetabolism,
      Cost = 4,
      UIName = UI_UT_adaptivemetabolism,
      UIDescription = UI_UT_adaptivemetabolismDesc,
  }
  ```
  No `XPBoosts`, no `MutuallyExclusiveTraits`, no `GrantedTraits`.
- Translation strings present: yes — UI_EN.txt lines 542–543:
  - `UI_UT_adaptivemetabolism = "Adaptive Metabolism"`
  - `UI_UT_adaptivemetabolismDesc = "Your body is remarkably good at making do with what it has. Your metabolism adjusts efficiently to changing conditions."`
- Exclusions/grants correct: The source had active mutual exclusions vs `WeightGain` and `WeightLoss` (vanilla). UT carries **none**. This is a meaningful deviation — see Balance Review.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_adaptivemetabolism.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_adaptivemetabolism.lua` (22 lines, complete)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition
- Event registrations:
  - `Events.EveryHours.Add(handler)` — raw direct registration; fires once per in-game hour. NOT via `UTCore.registerPeriodicHandler`.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper: calls `player:getTraits():contains(traitId)`; returns false if player or traits is nil.
- Runtime chain (plain language):
  1. Every in-game hour PZ fires `Events.EveryHours`.
  2. `handler()` runs (no arguments — calls `getPlayer()` internally, singleplayer only).
  3. Guard: if no player, exit. If player does not have `UniversalTraits:UT_adaptivemetabolism`, exit.
  4. Read `player:getStats():getHunger()` into `hunger`.
  5. Branch A — hunger > 0.7:
     - Set hunger to `math.max(0, hunger - 0.05)` — reduces hunger sensation by 0.05, floored at 0.
  6. Branch B — hunger < 0.3:
     - Set hunger to `math.min(1, hunger + 0.02)` — increases hunger sensation by 0.02, capped at 1.
  7. Neither branch fires if hunger is in the range `0.3 <= hunger <= 0.7` (dead zone).
- Actual behavior (exact values):
  - Cadence: once per in-game hour (`Events.EveryHours`).
  - Stat affected: `IsoGameCharacter.getStats().Hunger` (0.0 = not hungry, 1.0 = starving).
  - Scarcity branch (hunger > 0.7): −0.05 hunger per hour. To reduce from 0.7 to 0 would take 14 hours of continuous scarcity application, but in practice the player's natural hunger accumulation partially offsets this, so effective relief depends on hunger rate.
  - Well-fed branch (hunger < 0.3): +0.02 hunger per hour. This applies when the player is well-fed, nudging hunger gently upward to prevent the player from staying full indefinitely.
  - Dead zone: 0.3 <= hunger <= 0.7 — no hunger manipulation.
  - No nutrition (`player:getNutrition()`) interaction. No calorie manipulation. No weight check. No running/sprinting multiplier.

## Description Integrity
- Display name check: "Adaptive Metabolism" — accurate to concept; matches the source's trait name. No issues.
- Description check: "Your body is remarkably good at making do with what it has. Your metabolism adjusts efficiently to changing conditions." — this is vague and does not describe the actual mechanic.
- Missing or misleading details:
  1. **Misleading by omission**: The description implies a broadly adaptive system but gives no hint that the effect operates on the hunger stat specifically. A player reading this has no idea whether it affects calories, hunger rate, weight, or recovery speed.
  2. **Missing**: No mention of the direction or magnitude of hunger adjustment (−0.05/hr when hungry, +0.02/hr when well-fed).
  3. **Missing**: No mention of the threshold values (0.3 / 0.7) that define when the effect activates.
  4. **Misleading vs. source**: The source mechanic worked on raw calories and weight to keep the character in a healthy weight band (77–83 kg). The UT implementation works only on the hunger stat and has no weight awareness at all. The description could equally describe either mechanic, concealing the full scope of the redesign.
  5. **No mention of cost value 4**: description gives no indication of relative value for context (minor point — descriptions generally don't state costs, but the vagueness is notable).

## Balance Review
- Upside: pure positive trait, costs 4 points. Two effects:
  1. When starving (hunger > 0.7): reduces hunger by 0.05/hr — softens the starving moodle progression.
  2. When well-fed (hunger < 0.3): nudges hunger up by 0.02/hr — marginal penalty when satiated, negligible in practice.
- The well-fed branch (hunger < 0.3 → +0.02/hr) is an embedded downside. It is very small and will rarely be noticeable. A player who is well-fed will progress from 0.0 hunger to 0.3 in 15 hours at +0.02/hr, but food consumption regularly resets hunger to near 0, so this branch fires infrequently and for short durations. In practice it functions as a near-invisible balancing tax.
- The scarcity branch (hunger > 0.7 → −0.05/hr) is the main benefit. PZ vanilla hunger accumulation rate is roughly 0.002–0.006 per in-game minute depending on activity, which is approximately 0.12–0.36 per in-game hour. A reduction of 0.05/hr is a modest but consistent benefit — it extends the time before the player crosses the starvation moodle thresholds. It does not restore hunger to a safe level on its own; the player still needs to eat.
- Uptime: the scarcity branch is most relevant in food-scarce situations. In well-resourced playthroughs the player's hunger stays below 0.7 most of the time and this trait provides little. The trait rewards lean survival gameplay.
- Missing source mechanic: the source operated on `nutrition:setCalories()` directly, adjusting the calorie pool to nudge body weight toward a healthy band. The UT version does not touch calories or weight at all. The source version was meaningfully more powerful — it could partially offset long-term underweight or overweight status by manipulating the calorie counter. The UT version only damps the hunger moodle display. This is a significant mechanical divergence. The source was worth 5 points; UT's cost of 4 is plausible for the simpler implementation.
- Source exclusion gap: the source mutually excluded `WeightGain` and `WeightLoss` vanilla traits. UT has no exclusions. Since UT's mechanism no longer interacts with weight or calories, the functional reason for those exclusions no longer applies to the UT implementation. The omission is arguably correct given the redesigned mechanic. However, `WeightGain` and `WeightLoss` were excluded because they directly conflict with the trait's stabilising intent — the UT version doesn't stabilise weight, so the conflict is gone. **Omission is acceptable but should be documented as intentional.**
- Peer comparison: UT_ravenous (hunger-affecting negative), UT_accmetabolism (accelerated hunger/thirst, -3). Adaptive Metabolism at +4 is the positive hunger complement to UT_accmetabolism. The UT_accmetabolism increases hunger by +0.05/hr unconditionally; UT_adaptivemetabolism reduces hunger by −0.05/hr only when hungry (> 0.7). Both are hourly. This creates a clean symmetric pair at the bookends of hunger management.
- Cost verdict: **4 is defensible but on the high side** for what the trait actually does. The scarcity benefit (−0.05/hr when starving) is narrow in scope and the well-fed branch adds a minor counterweight. The source was 5 points but also directly manipulated calorie/weight balance which was a stronger effect. A cost of 3 would be more accurate to the current power level. **Acceptable at 4; recommend reviewing against UT_accmetabolism (-3) for calibration.**

## Regression Proof
- Existing test: `UniversalTraits:UT_adaptivemetabolism` appears in the Phase 3b smoke-test ID list at `test/run_tests.lua` line 286 (Phase 3b — Periodic-Check group). This list is checked by the "all trait IDs registered with CharacterTrait" test and the "script trait definitions resolve cleanly" test.
- What it proves: (1) `CharacterTrait.register("UniversalTraits:UT_adaptivemetabolism")` has been called and the trait ID is present in the registry; (2) the script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves. Neither test exercises the Lua runtime handler.
- Missing proof: No test covers:
  - The scarcity branch (hunger > 0.7 → hunger decremented by 0.05).
  - The well-fed branch (hunger < 0.3 → hunger incremented by 0.02).
  - The dead zone (0.3 ≤ hunger ≤ 0.7 → no change).
  - The `math.max(0, ...)` and `math.min(1, ...)` clamps at the extremes.
  - The guard path (player has wrong trait → no effect).
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_adaptivemetabolism.lua")

  test("UT_adaptivemetabolism: scarcity branch reduces hunger when > 0.7", function()
      local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" })
      p:getStats():setHunger(0.8)
      withActivePlayer(p, function() Events.EveryHours:fire() end)
      assert_approx_eq(p:getStats():getHunger(), 0.75, 0.001, "hunger should decrease by 0.05")
  end)

  test("UT_adaptivemetabolism: well-fed branch increases hunger when < 0.3", function()
      local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" })
      p:getStats():setHunger(0.1)
      withActivePlayer(p, function() Events.EveryHours:fire() end)
      assert_approx_eq(p:getStats():getHunger(), 0.12, 0.001, "hunger should increase by 0.02")
  end)

  test("UT_adaptivemetabolism: dead zone — no change when hunger is 0.5", function()
      local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" })
      p:getStats():setHunger(0.5)
      withActivePlayer(p, function() Events.EveryHours:fire() end)
      assert_eq(p:getStats():getHunger(), 0.5, "hunger should be unchanged in dead zone")
  end)

  test("UT_adaptivemetabolism: scarcity clamp — hunger floored at 0", function()
      local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" })
      p:getStats():setHunger(0.02)  -- < 0.3 so well-fed branch fires, not scarcity
      -- Test clamp at 0 by forcing hunger to exactly 0 via the math.max guard
      -- Only the scarcity branch can reach 0; test with hunger=0.71 to confirm decrement to 0.66, not below
      p:getStats():setHunger(0.71)
      withActivePlayer(p, function() Events.EveryHours:fire() end)
      assert_true(p:getStats():getHunger() >= 0, "hunger must not go below 0")
  end)

  test("UT_adaptivemetabolism: guard — no effect without trait", function()
      local p = MockPlayer({})  -- no trait
      p:getStats():setHunger(0.9)
      withActivePlayer(p, function() Events.EveryHours:fire() end)
      assert_eq(p:getStats():getHunger(), 0.9, "hunger should be unchanged without trait")
  end)
  ```

## Final Verdict
- Source origin: confirmed — SomewhatTraits `SWAdaptiveMetabolism`. Source operated on `player:getNutrition():setCalories()` via a throttled `Events.OnTick` server-side handler (~every 5 real seconds). It adjusted the raw calorie pool to push body weight toward 77–83 kg: +extraCalories when underweight, −extraCalories when overweight, with a running/sprinting multiplier (×5). Source cost was 5. Mutually excluded `WeightGain` and `WeightLoss` (vanilla traits). Server-side and multiplayer-capable.
- UT implementation: completely redesigned from the source. Instead of calorie/weight manipulation, UT applies a hunger-stat nudge via `Events.EveryHours` (once per in-game hour, not per tick). Two branches: −0.05 hunger/hr when starving (> 0.7), +0.02 hunger/hr when well-fed (< 0.3). No weight awareness, no calorie manipulation, no running multiplier. `DisabledInMultiplayer = true`. Uses raw `Events.EveryHours.Add` instead of `UTCore.registerPeriodicHandler` — inconsistent with the majority of UT periodic traits but not functionally wrong for singleplayer.
- Description: **vague and non-specific**. "Adjusts efficiently to changing conditions" is accurate in tone but communicates nothing about which stat is affected, what the thresholds are, or what the magnitude is. Needs a rewrite that names the hunger stat and the two conditions.
- Balance: **acceptable at cost 4** but slightly over-priced for the current implementation. The scarcity benefit is narrow-trigger and modest; the well-fed penalty is negligible. The source was worth 5 points for a much stronger calorie-manipulation mechanic. Cost 3–4 is the right range; 4 is at the upper edge.
- Regression proof: **weak**. ID registration and script-block structure are covered by the smoke test. The runtime handler — both hunger branches, the dead zone, and the clamps — is entirely untested.
- Action needed:
  1. **Fix description** — rewrite to name the hunger stat and both conditions. Example: "Your body is remarkably efficient. When you are very hungry, your hunger pangs ease slightly each hour. When you are well-fed, your appetite gently returns."
  2. **Migrate event registration** to `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryHours", handler)` for consistency with the UT periodic pattern (handler signature must then accept `player` as argument and drop the internal `getPlayer()` call).
  3. **Add unit tests** per the minimum test block above.
  4. **Document the source divergence** — the calorie/weight mechanic was intentionally dropped in favour of a hunger-stat approach. This decision should be recorded in a design note so it is not re-litigated during future audits.
- Open gaps:
  - No mutual exclusions are defined in UT. Source excluded `WeightGain` and `WeightLoss`. Since UT's version does not interact with weight or calories, the exclusions are no longer mechanically motivated. The omission is likely correct — confirm it is intentional.
  - The `DisabledInMultiplayer = true` flag sidesteps the networking complexity that the source solved via server-side execution. If multiplayer support is ever added to UT traits, this trait's `Events.EveryHours` + `getPlayer()` pattern would need refactoring before the flag can be removed.
  - The well-fed branch (+0.02 hunger/hr when < 0.3) is effectively a hidden minor penalty embedded in a positive trait. It is so small as to be nearly imperceptible in practice, but its existence makes the trait technically a dual-effect trait. The description should acknowledge it or the branch should be documented as intentional balancing.
