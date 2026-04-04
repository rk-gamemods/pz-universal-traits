# UT_mstoptimist

## Trait Summary
- UT trait id: `UniversalTraits:UT_mstoptimist`
- Source mod: MoreSimpleTraits
- Source trait id: `MSTOptimist`
- Current cost: +3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` line 145 — `TraitFactory.addTrait("MSTOptimist", getText("UI_trait_optimistmood"), 2, getText("UI_trait_optimistmooddesc"), false)` — original cost **+2**, non-profession trait
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` line 126 — identical registration in the Vanilla variant
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 98–99 — English strings: display name **"Optimist"**, description **"Bored less. Can't get Depressed for a long time."**
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 846–894 — three handler functions (see below); wired to `Events.OnPlayerUpdate`, `Events.EveryOneMinute`, and `Events.EveryHours`
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua` — identical Vanilla variant
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` line 211 — `TraitFactory.setMutualExclusive("MSTDepressive", "MSTOptimist")`
- Source trigger paths and behavior:
  - **`hoursindepression()`** — wired to `Events.EveryHours`. Fires once per in-game hour for every active player. If the player has `MSTOptimist` and `getBodyDamage():getUnhappynessLevel() >= 39`, the counter `MSThoursUntilDepression` increments by 1. Otherwise it decrements by 2. The counter is clamped to the range `[0, 120]`. This counter is the gate for the next function.
  - **`optimisttrait()`** — wired to `Events.OnPlayerUpdate` (fires every game tick). For every active player: if the player has `MSTOptimist`, is not asleep, and `MSThoursUntilDepression <= 48`, then if `getBodyDamage():getUnhappynessLevel() >= 50`, it is forced down to 49. This is a **unhappiness ceiling**: while the player has not been deeply unhappy for more than ~48 game-hours, the player's unhappiness is hard-capped at 49 (just below the depression threshold of 50).
  - **`optimistraitbored()`** — wired to `Events.EveryOneMinute`. If the player has `MSTOptimist` and is **not** asleep: calls `MSTdecreaseBoredom(player, 0, 0.040)` — reduces boredom by a fixed 0.040 per minute (lower bound 0). If the player has `MSTOptimist` and **is** asleep: calls `MSTdecreaseBoredom(player, ZombRand(4), 0.080)` — reduces boredom by 0.080 per minute with a random `[0,3]` offset applied to the lower bound.
  - Source cost: **+2** (a positive trait).
  - Source mutual exclusions: `MSTOptimist` ↔ `MSTDepressive` (both variants).

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_mstoptimist = CharacterTrait.register("UniversalTraits:UT_mstoptimist")` at line 254, between `UT_pessimist` and `UT_adaptivemetabolism`
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_mstoptimist` at lines 1732–1741:
  ```
  character_trait_definition UniversalTraits:UT_mstoptimist
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_mstoptimist,
      Cost = 3,
      UIName = UI_UT_mstoptimist,
      UIDescription = UI_UT_mstoptimistDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_pessimist,
  }
  ```
  No `XPBoosts`. No `GrantedTraits`. One `MutuallyExclusiveTraits` entry.
- Translation strings present: yes — `UI_EN.txt` lines 539–540:
  - `UI_UT_mstoptimist = "Silver Lining"`
  - `UI_UT_mstoptimistDesc = "Even at the end of the world, you find something to be glad about. Every 10 in-game minutes, stress decreases by −0.08 when stress is above 0.6, or −0.03 otherwise."`
- Exclusions correct: partially. The UT script block excludes `UT_pessimist`. The source only excludes `MSTDepressive` (which maps to `UT_depressive` in UT namespace). The UT trait `UT_pessimist` is a different source trait (`UT_pessimist` costs -2 in UT). Additionally, `UT_pessimist` already reciprocally excludes `UT_mstoptimist` (and `UT_optimist`) in its own block at lines 1729. The exclusion of `UT_optimist` from `UT_mstoptimist` is **absent** — `UT_mstoptimist` does not exclude `UT_optimist`, even though the two traits both reduce stress via `Events.EveryTenMinutes`. See findings below.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_mstoptimist.lua` (19 lines)
- UT_MET group membership: none — not present in any `UT_MET` group. Not relevant for a periodic stress-reduction trait.

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_mstoptimist.lua` (19 lines, complete — reproduced in full below)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–16)
  - `test/run_tests.lua` lines 281–286 — Phase 3b smoke-test list
- Full Lua file (19 lines):
  ```lua
  -- UT_mstoptimist.lua
  -- Silver Lining: stress reduction amplifies when stress is high

  local TRAIT_ID = "UniversalTraits:UT_mstoptimist"

  local function handler()
      local player = getPlayer()
      if not player then return end
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      local stats = player:getStats()
      if stats:getStress() > 0.6 then
          stats:setStress(math.max(0, stats:getStress() - 0.08))
      else
          stats:setStress(math.max(0, stats:getStress() - 0.03))
      end
  end

  Events.EveryTenMinutes.Add(handler)
  ```
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)` — raw direct registration, NOT via `UTCore.registerPeriodicHandler`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper defined in `UTCore_API.lua` lines 11–16: checks `player:getTraits():contains(traitId)`; returns `false` if `player` or `traits` is nil.
- Runtime chain (plain language):
  1. Every 10 in-game minutes PZ fires `Events.EveryTenMinutes`.
  2. `handler()` runs with no arguments — calls `getPlayer()` internally. Singleplayer only (consistent with `DisabledInMultiplayer = true` in script block).
  3. Guard: if `getPlayer()` returns nil, exit immediately.
  4. Guard: if the player does not have trait `UniversalTraits:UT_mstoptimist`, exit immediately.
  5. Read `player:getStats()` into local `stats`.
  6. Conditional branch on `stats:getStress()`:
     - If stress **> 0.6**: call `stats:setStress(math.max(0, stats:getStress() - 0.08))` — reduce stress by 0.08, floored at 0.
     - If stress **<= 0.6**: call `stats:setStress(math.max(0, stats:getStress() - 0.03))` — reduce stress by 0.03, floored at 0.
  7. No moddata written. No other hooks, events, or side effects.
- `stats` nil guard: **absent**. `player:getStats()` is called without a nil check on the return value. In practice PZ always provides a valid stats object for a live player, making this a low-risk omission, but it deviates from the defensive pattern used in some sibling traits. Consistent with the sibling `UT_optimist.lua` which also omits this guard.
- Actual behavior (exact values):

  | Condition | Delta per 10 min | Rate per hour | Time from 1.0 to 0.6 | Time from 0.6 to 0.0 |
  |---|---|---|---|---|
  | Stress > 0.6 | −0.08 | −0.48 | ~50 minutes (5 ticks) | ~75 minutes (7.5 ticks, but stress hits 0.6 boundary) |
  | Stress ≤ 0.6 | −0.03 | −0.18 | — | ~200 minutes (20 ticks, from 0.6 to 0) |

  - At stress exactly 0.61: one tick applies −0.08 → 0.53, which is now ≤ 0.6, so next tick applies −0.03. The threshold is tested against the value **before** the decrement.
  - Stress is floored at 0 via `math.max(0, ...)`. If stress is 0.02 and the high branch fires: `math.max(0, 0.02 - 0.08)` = `math.max(0, -0.06)` = 0. No underflow, no crash.
  - No condition gating beyond the stress value threshold — no activity check, no time-of-day restriction, no sleep check.
  - The trait fires unconditionally every 10 minutes as long as the player has it and a valid player object exists.

## Description Integrity
- Display name check: UT uses "Silver Lining". The source uses "Optimist" (from `UI_trait_optimistmood = "Optimist"`). The rename is intentional — UT already has a separate `UT_optimist` trait, so a new name was required to avoid collision. "Silver Lining" is thematically appropriate for stress reduction scaling with high stress.
- Description check: `"Even at the end of the world, you find something to be glad about. Every 10 in-game minutes, stress decreases by −0.08 when stress is above 0.6, or −0.03 otherwise."`
  - "Every 10 in-game minutes" — accurate. Event is `EveryTenMinutes`.
  - "stress decreases by −0.08 when stress is above 0.6" — accurate. Condition is `stats:getStress() > 0.6`, delta is `−0.08`.
  - "or −0.03 otherwise" — accurate. The else branch applies `−0.03` when stress is ≤ 0.6.
  - The description quantifies both rates and the threshold. This is one of the more complete UT trait descriptions.
- Missing or misleading details:
  1. The floor at 0 is not mentioned, but that is standard behavior and does not need disclosure.
  2. The description does not mention that the trait has no boredom reduction (unlike the source `MSTOptimist`), but this is an intentional redesign and omission is correct.
  3. No false claims detected.

## Balance Review
- Upside: stress reduction, tiered by current stress level.
  - When highly stressed (> 0.6): −0.08 per 10 min = −0.48/hr. From a maximum stress of 1.0, this brings the player below 0.6 in approximately 5 ticks (50 minutes). After crossing the threshold, the slower rate of −0.03/tick applies.
  - When moderately stressed (≤ 0.6): −0.03 per 10 min = −0.18/hr.
  - The trait is most valuable when the player is highly stressed — this is the "silver lining" design intent: the trait rescues the player from high-stress states faster than it maintains low stress.
- Peer comparison — `UT_optimist` (cost +2):
  - `UT_optimist` applies **−0.06 stress and −0.04 panic** per 10 minutes, unconditionally.
  - `UT_mstoptimist` applies **−0.08 stress (high) or −0.03 stress (low)** per 10 minutes, with no panic reduction.
  - At high stress: `UT_mstoptimist` removes stress 33% faster than `UT_optimist` (0.08 vs 0.06). At low stress: `UT_mstoptimist` removes stress 50% slower than `UT_optimist` (0.03 vs 0.06) and offers no panic reduction. `UT_mstoptimist` is better when the player is struggling (high stress) and worse during calm periods. This is an interesting and well-designed asymmetry.
  - Cost difference: `UT_mstoptimist` costs +3, `UT_optimist` costs +2. The extra point is justified by the high-stress bonus rate — the trait is more useful in crisis situations, which is when trait value matters most in a survival game.
- Stack or exclusion notes:
  - `UT_mstoptimist` excludes `UT_pessimist` (via its script block `MutuallyExclusiveTraits`).
  - `UT_pessimist` reciprocally excludes both `UT_optimist` and `UT_mstoptimist` (its block lists both).
  - `UT_optimist` excludes `UT_pessimist`, `UT_depressive`, and `UT_melancholic` — but does **not** exclude `UT_mstoptimist`.
  - **`UT_mstoptimist` does not exclude `UT_optimist`.** Both traits use `Events.EveryTenMinutes` to reduce stress. A player holding both would receive `−0.08 + 0.06 = −0.14` stress per 10 minutes when stressed above 0.6, plus `−0.04` panic from `UT_optimist`. This combined reduction (−0.84 stress/hr when stressed) would drain stress from 1.0 to 0 in roughly 72 minutes — significantly faster than either trait alone. It also stacks +3 and +2 for a 5-point combined cost, which is not obviously broken but the combination gives both the high-stress bonus and the flat panic reduction with no exclusion gate. This should be reviewed.
- Cost verdict: **+3 is reasonable**. The tiered stress reduction is well-priced relative to `UT_optimist` at +2. The crisis-bonus design is sound. The main concern is the missing mutual exclusion with `UT_optimist`.

## Regression Proof
- Existing test: `UniversalTraits:UT_mstoptimist` appears in the Phase 3b smoke-test ID list at `test/run_tests.lua` line 286. This list is validated by two tests:
  1. `"all 198 trait IDs registered with CharacterTrait"` — confirms `CharacterTrait.register("UniversalTraits:UT_mstoptimist")` has been called and the ID resolves.
  2. `"script trait definitions resolve cleanly and preserve UT_MET coverage"` — confirms the script block exists, `CharacterTrait` field matches the block ID, registry entry resolves, and any `MutuallyExclusiveTraits` entries reference registered IDs. For this trait, `UniversalTraits:UT_pessimist` is the only listed exclusion; it is registered (line 253 of `registries.lua`), so this check passes.
- What these tests prove: ID registration and script-block structural integrity. Neither test exercises the Lua runtime handler.
- Missing proof: No runtime handler test for `UT_mstoptimist`. The branching logic (stress > 0.6 vs. ≤ 0.6), the delta values, the `math.max` floor, and the nil guards are entirely untested at runtime.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_mstoptimist.lua")

  test("UT_mstoptimist: reduces stress by 0.08 when stress > 0.6", function()
      local p = MockPlayer({ "UniversalTraits:UT_mstoptimist" })
      p:getStats():setStress(0.80)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_true(math.abs(p:getStats():getStress() - 0.72) < 0.0001, "expected stress 0.80 - 0.08 = 0.72")
  end)

  test("UT_mstoptimist: reduces stress by 0.03 when stress <= 0.6", function()
      local p = MockPlayer({ "UniversalTraits:UT_mstoptimist" })
      p:getStats():setStress(0.50)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_true(math.abs(p:getStats():getStress() - 0.47) < 0.0001, "expected stress 0.50 - 0.03 = 0.47")
  end)

  test("UT_mstoptimist: stress is floored at 0 when delta would underflow", function()
      local p = MockPlayer({ "UniversalTraits:UT_mstoptimist" })
      p:getStats():setStress(0.02)  -- low, but delta 0.08 would go negative
      -- Force high-stress branch by setting to 0.65 first
      p:getStats():setStress(0.65)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      -- 0.65 - 0.08 = 0.57 (above 0, no clamp needed here)
      assert_true(p:getStats():getStress() >= 0, "stress must not go below 0")
      -- Now test actual floor: stress = 0.02, low branch
      p:getStats():setStress(0.02)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_eq(p:getStats():getStress(), 0, "stress should floor at 0")
  end)

  test("UT_mstoptimist: no stat change when player does not have trait", function()
      local p = MockPlayer({})
      p:getStats():setStress(0.75)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_true(math.abs(p:getStats():getStress() - 0.75) < 0.0001, "stress should not change without trait")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreSimpleTraits `MSTOptimist` (present in both `MoreSimpleTraits` base and `MoreSimpleTraitsVanilla` variants). Source display name: **"Optimist"**. Source description: **"Bored less. Can't get Depressed for a long time."** Source cost: **+2**. Source behavior was a three-function system:
  1. `hoursindepression()` (every hour): tracked accumulated unhappiness time in `MSThoursUntilDepression` moddata `[0, 120]`.
  2. `optimisttrait()` (every tick): while `MSThoursUntilDepression <= 48`, hard-capped `unhappynessLevel` at 49 — preventing the player from crossing into the depression state unless they had been continuously unhappy for ~48 game-hours.
  3. `optimistraitbored()` (every minute): reduced boredom by 0.040/min while awake, 0.080/min while asleep.
  Source mutual exclusions: `MSTOptimist` ↔ `MSTDepressive` only.
- UT implementation: **significant redesign**. UT discards the depression-immunity/boredom-reduction model entirely and replaces it with a **tiered periodic stress reduction**: `Events.EveryTenMinutes`, −0.08 when stress > 0.6, −0.03 otherwise. The new name "Silver Lining" reflects the crisis-bonus design. The cost increases from +2 to +3. No moddata used. The conceptual shift is from "prevents depression / reduces boredom" to "sheds stress faster when most stressed." These are related but mechanically distinct effects (PZ unhappiness/boredom vs. stress API).
- Description: **accurate and complete**. Both rates and the threshold are stated. No false claims. This is one of the better-documented UT traits.
- Balance: **reasonable** with one structural gap. The +3 cost vs. `UT_optimist`'s +2 is justified by the high-stress bonus rate. The missing mutual exclusion with `UT_optimist` allows stacking two stress-reduction traits (combined cost +5) with no gate, yielding −0.14 stress/tick when stressed above 0.6 plus −0.04 panic/tick from `UT_optimist`. This is not game-breaking but is an unintended combination that bypasses the intended tier distinction.
- Regression proof: **weak**. ID registration and script-block structure are covered by smoke tests. The runtime branching logic, delta values, and floor behavior have zero runtime test coverage.
- Action needed:
  1. **Add mutual exclusion with `UT_optimist`** in the `UT_mstoptimist` script block: `MutuallyExclusiveTraits = UniversalTraits:UT_pessimist;UniversalTraits:UT_optimist`. Also add the reciprocal exclusion in the `UT_optimist` script block. The two traits should be alternative choices, not stackable additions.
  2. **Add runtime moddata spot-check tests** per the minimum test block above — particularly the branching condition at the 0.6 threshold, both delta values, and the `math.max` floor.
  3. **Optional**: migrate event registration to `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryTenMinutes", handler)` for consistency with the UT pattern used by most other periodic traits (e.g., `UT_backpacker.lua`).
- Open gaps:
  - No `stats` nil guard on `player:getStats()`. Low risk — consistent with sibling `UT_optimist.lua` behavior — but deviates from the defensive pattern.
  - The source `MSTOptimist`'s boredom-reduction mechanic has no counterpart in UT. This is an intentional omission (the UT redesign focuses exclusively on stress). No action required unless a future boredom-reduction trait is desired.
  - The source depression-immunity mechanic (unhappiness hard-cap at 49 for up to 48 game-hours of accumulated unhappiness) has no counterpart in UT. Also intentionally omitted. The UT approach is cleaner and more predictable.
