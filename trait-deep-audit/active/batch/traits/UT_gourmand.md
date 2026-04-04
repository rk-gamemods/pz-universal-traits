# UT_gourmand

## Trait Summary
- UT trait id: UT_gourmand
- Source mod: MoreTraits (More Traits)
- Source trait id: gourmand (no namespace prefix, `player:HasTrait("gourmand")`)
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (runtime implementation — `setFoodState`, `FoodUpdate`, `Gourmand`, `ContainerEvents`, lines 2835–2886, 2888–3130, 3265–3276)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (source display strings, lines 135–136)
- Source registration: `player:HasTrait("gourmand")` checked inline — no `TraitFactory.addTrait` call visible in the reviewed files; trait registration is assumed to exist elsewhere in the MoreTraits mod bundle.
- Source trigger path: Two separate event hooks drive the source Gourmand trait:
  1. `FoodUpdate(_player)` — called on every inventory update; iterates all Food items in the player's inventory and calls `setFoodState(item, "Gourmand")` for each.
  2. `Gourmand(_iSInventoryPage, _state, _player)` — called from `ContainerEvents` when `_state == "end"` (i.e., when the player closes a container); iterates container food items and replaces rotten or non-fresh items with fresh copies at a 33% base chance (modified by Lucky/Unlucky traits), with an optional halo-text announcement.
- Source behavior (verified in `setFoodState` with `state == "Gourmand"`, lines 2952–3015):
  - Cooking speed: raw cookable food has `MinutesToCook` halved (`* 0.5`) and `MinutesToBurn` doubled (`* 2`). Stage flag is set to 1.
  - Cooked (non-rotten) food stats boosted:
    - `HungChange` multiplied by `1.5` (always, regardless of sign)
    - `UnhappyChange`: if original was `>= 0` (i.e., made you unhappy or neutral), set to `0`; if originally beneficial (`< 0`), multiplied by `1.5`
    - `BoredomChange`: same conditional logic as UnhappyChange — zeroed if non-beneficial, multiplied by `1.5` if beneficial
    - `ThirstChange`: if `>= 0`, halved (`* 0.5`); if beneficial (`< 0`), multiplied by `1.5`
    - `EndChange`: if `>= 0`, set to flat `-5`; if beneficial, multiplied by `1.5`
    - `StressChange`: if `>= 0`, set to flat `-10`; if beneficial, multiplied by `1.5`
    - `FatChange`: if `>= 0`, set to flat `-5`; if beneficial, multiplied by `1.5`
    - `GoodHot`, `BadInMicrowave`, `BadCold` all forced to `false` (temperature indifference)
    - `Age` reset to `0` and updated (freshness reset)
    - Stage flag set to 2 (fully processed)
  - Fresh-food find: 33% base chance on container close to replace rotten or non-fresh food items with a fresh copy of the same item type. Chance adjusted by Lucky (+10%) and Unlucky (-10%) traits.
  - Stage tracking uses `itemdata.iFoodStage` (0, 1, 2) to avoid redundant re-application.
- Source display name: `UI_trait_gourmand = "Gourmand"`
- Source description: `UI_trait_gourmanddesc = "You delight in food of all kinds and find cooking an enjoyable sport. Food cooks in half the time and takes twice as long to burn. More likely to find Fresh ingredients. Food that you cook is better. Temperature of food and method of cooking does not bother you. +1 Cooking"`
- Source cost: unknown (no `TraitFactory.addTrait` found in reviewed files)
- Source exclusions: unknown from reviewed files

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `run_tests.lua` line 95–97 confirms `UTTraitsRegistries.UT_gourmand == "UniversalTraits:UT_gourmand"`; also appears in the expected_ids list at line 277 (Phase 2 — Item / Consumption group)
- Defined in UT_character_traits.txt: yes — lines 1578–1587
  - `Cost = 4`
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_ascetic;UniversalTraits:UT_anorexy`
- Translation strings present: yes
  - `UI_UT_gourmand = "Gourmand"`
  - `UI_UT_gourmandDesc = "Food is one of life's great pleasures. Each meal grants +30% bonus hunger relief and reduces boredom by 0.05."`
- Exclusions verified: bidirectional partially verified — `UT_ascetic` definition (line 1597) lists `UT_gourmand` in its exclusion set; `UT_anorexy` definition (line 1952) lists `UT_gourmand` in its exclusion set. Both are confirmed bidirectional.
- Runtime Lua file exists: yes — `UT_gourmand.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_gourmand.lua` (full file, 65 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1578–1587)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 491–492)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. `onPlayerUpdate` fires on every player update tick.
  2. A module-level `tickCounter` is incremented each tick; the function exits early unless `tickCounter % 30 == 0` (i.e., processing runs every 30 ticks).
  3. `UTCore.hasTrait` is called to check whether the player currently has `UniversalTraits:UT_gourmand`.
  4. All items in the player's inventory are iterated. For each item whose `getCategory() == "Food"`:
     - If the player has Gourmand: `pcall(applyGourmandToFood, item)` is called.
     - If the player does not have Gourmand: `pcall(revertGourmandFood, item)` is called.
  5. `applyGourmandToFood(food)`: reads `food:getModData()`. If `UT_gourmand_state` is nil, stores originals for `HungChange`, `UnhappyChange`, and `BoredomChange`. If state is not already `"Gourmand"`, sets:
     - `HungChange` to `origHungChange * 1.5` (always)
     - `UnhappyChange` to `origUnhappyChange * 1.5` only if original was `< 0` (beneficial); otherwise leaves it unchanged (no zeroing of non-beneficial values)
     - `BoredomChange` to `origBoredomChange * 1.5` only if original was `< 0` (beneficial); otherwise leaves it unchanged
     - State set to `"Gourmand"`
  6. `revertGourmandFood(food)`: if state is `"Gourmand"`, restores all three originals and sets state to `"Normal"`.
- Actual behavior (exact values): Every 30 ticks, all Food items in inventory receive a 1.5× hunger multiplier unconditionally, and a 1.5× bonus to unhappiness/boredom only when those values were already beneficial. No cooking speed change, no temperature indifference flags, no fresh-food spawning, no Lucky/Unlucky interaction, no Endurance/Stress/Fatigue/Thirst bonuses, no +1 Cooking XPBoost.

## Description Integrity
- Display name check: "Gourmand" — matches source name exactly. No issue.
- Description check: `"Food is one of life's great pleasures. Each meal grants +30% bonus hunger relief and reduces boredom by 0.05."`
- Accuracy issues found:
  1. **"+30% bonus hunger relief"** — the Lua multiplies `origHungChange * 1.5`, which is a 50% increase in magnitude, not 30%. The description understates the hunger effect by 20 percentage points.
  2. **"reduces boredom by 0.05"** — the Lua does not apply a flat boredom reduction. It multiplies the original `BoredomChange` by 1.5 only if that value was already negative (beneficial). For food items with neutral or positive boredom change, the value is left unchanged. The description implies a flat unconditional reduction, which does not match the implementation.
  3. **No mention of unhappiness effect** — the Lua also conditionally scales `UnhappyChange` by 1.5 when beneficial. The description is silent on this.
  4. **Source effects omitted from UT with no disclosure**: cooking speed halving, burn time doubling, temperature indifference, fresh-food-find mechanic, Endurance/Stress/Fatigue/Thirst bonuses, and +1 Cooking are all present in the MoreTraits source but absent from UT. The UT description does not acknowledge this scope reduction.

## Balance Review
- Upside: Every 30 ticks, all inventory Food items receive +50% hunger relief and a conditional +50% bonus to unhappy/boredom changes that were already beneficial.
- Downside: none (purely positive trait)
- Uptime: 100% while the player has the trait; food stats are maintained in the item's mod data and reverted on trait removal.
- Cost: 4 points (UT)
- Source cost: not found in reviewed files (unknown)
- Peer comparison:
  - `UT_ascetic` is listed at `-4` (a mirror negative trait for food); the symmetric cost at `+4` for the positive food trait is thematically coherent.
  - `UT_anorexy` costs `-6` and is also mutually exclusive, suggesting a stronger downside than ascetic; gourmand being exclusive with both is reasonable.
  - The effect is moderate: hunger efficiency gains reduce food consumption rate, the conditional mood bonuses are situational. 4 points for a passive consumption efficiency boost is plausible.
- Stack or exclusion notes: Mutually exclusive with `UT_ascetic` (bidirectional) and `UT_anorexy` (bidirectional). No noted interaction with `UT_ironliver` or other consumption traits. The tick-throttle (every 30 ticks) means there is a brief window when food stats are not yet modified for newly picked-up items.
- Cost verdict: plausible — 4 points for a modest hunger efficiency trait with no downsides is within normal range, though the description inaccuracies mean players cannot accurately assess the value before taking it.
- Scope vs. source: UT Gourmand delivers roughly 20% of the mechanical scope of the MoreTraits source. The cooking speed, temperature indifference, fresh-find, and secondary stat bonuses are entirely absent. The reduced scope could justify a lower cost than the source, but without the source cost this cannot be verified numerically.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 95–97: `test("UT_gourmand registered", ...)` — asserts `UTTraitsRegistries.UT_gourmand == "UniversalTraits:UT_gourmand"`. Proves the registry entry exists.
  - `run_tests.lua` line 277: `"UniversalTraits:UT_gourmand"` appears in the `expected_ids` table (Phase 2 — Item / Consumption group). Proves the trait is enumerable in the full registration count test.
- What the tests prove: The trait is registered and discoverable. Nothing more.
- Missing proof:
  - No test verifies that `applyGourmandToFood` correctly multiplies `HungChange` by 1.5.
  - No test verifies the conditional logic for `UnhappyChange` and `BoredomChange` (beneficial-only scaling).
  - No test verifies that `revertGourmandFood` correctly restores original values.
  - No test verifies the tick-throttle behavior (only fires every 30 ticks).
  - No test verifies that food items picked up after the last tick cycle do not have stale state.
  - No test verifies that mutual exclusion with `UT_ascetic` and `UT_anorexy` is enforced.
  - No test verifies behavior when a player loses the trait mid-session (revert path).
- Minimum next test if needed: Mock a Food item with known `HungChange = -20`, `UnhappyChange = -10`, `BoredomChange = 5`. Call `applyGourmandToFood(item)`. Assert `HungChange == -30` (`-20 * 1.5`), `UnhappyChange == -15` (`-10 * 1.5`, beneficial), `BoredomChange == 5` (unchanged, non-beneficial). Then call `revertGourmandFood(item)` and assert all three values return to their originals.

## Final Verdict
- Source origin: proven — MoreTraits "gourmand" confirmed via `player:HasTrait("gourmand")` checks in `FoodUpdate` and `Gourmand` functions, and the `setFoodState` state machine in `MoreTraits.lua`
- UT implementation: substantially simplified — the source applies cooking speed changes, temperature indifference, multi-stat boosts (Endurance, Stress, Fatigue, Thirst), freshness resets, and a container-close fresh-food-find mechanic; the UT version applies only hunger relief (+50%) and conditional unhappy/boredom scaling (+50% if beneficial) on a 30-tick cycle
- Description: inaccurate on two stated values and silent on the unhappiness bonus — "+30% hunger relief" should be "+50%"; "reduces boredom by 0.05" does not match the conditional proportional scaling implemented in Lua; the unhappy scaling benefit is not mentioned at all
- Balance: plausible given the reduced scope — 4 points for passive hunger efficiency is reasonable, but the description inaccuracies prevent informed player choice
- Regression proof: partially protected — registration proven; all runtime behavior unproven
- Action needed: description fix (primary); optional test additions
- Open gaps:
  - Description must be corrected: hunger multiplier is 1.5× (50%), not 30%; boredom change is a proportional conditional scale, not a flat 0.05; unhappy change is also conditionally scaled but is not mentioned
  - Confirm whether the reduced scope relative to MoreTraits source is intentional (cooking speed, temperature flags, fresh-find, secondary stats all omitted)
  - Source cost unknown — if the source trait cost can be located, verify whether UT's 4-point cost is calibrated appropriately relative to the scope reduction
  - `DisabledInMultiplayer = true` — source MoreTraits did not restrict the trait to singleplayer; this divergence should be a confirmed intentional decision
  - The tick-throttle (every 30 ticks) creates a brief window on pickup where food is not yet modified; consider whether this window is acceptable or should be supplemented with an `OnItemAdded` hook
  - No test coverage for the apply/revert cycle or the conditional scaling logic; add behavioral unit tests before this trait is considered regression-safe
