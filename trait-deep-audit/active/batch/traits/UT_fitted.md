# UT_fitted

## Trait Summary
- UT trait id: UT_fitted
- Source mod: More Traits (ToadTraits / ToadTraits by Toad King)
- Source trait id: ToadTraits:fitted
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt`
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua`
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua`
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path: `Events.OnPlayerUpdate` fires every tick; the handler runs clothing logic unconditionally on every call (no throttle in source)
- Source behavior: When the player has `ToadTraits:fitted`, every worn clothing item has its actual weight set to `origWeight * 0.5`; run speed modifiers below 1.0 are raised to 1.0; combat speed modifiers below 1.0 are raised to 1.0. When the trait is absent, original values are restored. Unequipped items in inventory that were previously modified are also restored. State is tracked per-item via ModData keys `sState`, `iOrigRunSpeedMod`, `iOrigCombatSpeedMod`, `iOrigWeight`. Source cost: 4. Source had `DisabledInMultiplayer = false`. Source display name: "Well-Fitted". Source description: "Worn clothing weighs half as much and does not impose any speed penalty."

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A (no MutuallyExclusiveTraits or GrantedTraits in definition)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_fitted.lua`
- Event registrations: `Events.OnPlayerUpdate.Add(clothingUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — used to determine active state; no other UT_CORE hooks
- Runtime chain (plain language):
  1. `Events.OnPlayerUpdate` fires every player update tick.
  2. A module-level `tickCounter` increments; the handler skips execution unless `tickCounter % 30 == 0` (throttle of 30 ticks, approximately every ~1 second).
  3. `UTCore.hasTrait` is called to determine whether the player currently has `UniversalTraits:UT_fitted`; result maps to state `"Fitted"` or `"Normal"`.
  4. Pass 1 iterates all clothing items in the full inventory. Any item with `UT_fitted_state` set to a non-Normal value that is no longer worn has its run speed, combat speed, and actual weight restored to the stored originals, and its state reset to `"Normal"`.
  5. Pass 2 iterates all currently worn items. On first encounter, original run speed modifier, combat speed modifier, and actual weight are recorded in ModData. If the current state differs from the stored state, the appropriate adjustments are applied (or reverted), and the player's worn items list is refreshed via `player:setWornItems(wornItems)`.
- Actual behavior (exact values):
  - Weight: `actualWeight * 0.5` while trait is active; restored to original when removed or item unequipped.
  - Run speed modifier: set to `1.0` if original modifier was `< 1`; otherwise unchanged. Restored to original when trait removed or item unequipped.
  - Combat speed modifier: set to `1.0` if original modifier was `< 1`; otherwise unchanged. Restored to original when trait removed or item unequipped.
  - Throttle: 30 `OnPlayerUpdate` ticks between evaluations.
  - ModData prefix: `UT_fitted_` (keys: `UT_fitted_state`, `UT_fitted_origRunMod`, `UT_fitted_origCombatMod`, `UT_fitted_origWeight`).

## Description Integrity
- Display name check: UT display name is "Fitted" vs. source "Well-Fitted" — minor rename, does not misrepresent the trait.
- Description check: "Reduces the weight of each worn clothing item by 50%. Removes run and combat speed penalties from worn items. Effect updates every ~1 second." — accurate. The 50% weight reduction and speed penalty removal are confirmed by the runtime. The ~1 second update cadence is confirmed by the 30-tick throttle.
- Missing or misleading details: None. The description correctly qualifies that only penalties (modifiers < 1.0) are removed, and the throttle caveat is disclosed. No misleading claims found.

## Balance Review
- Upside: Halves the carry weight of all worn clothing (freeing significant encumbrance budget in a clothing-heavy loadout); eliminates run and combat speed penalties from any worn piece that imposes them. Both benefits apply simultaneously and passively.
- Downside: None — pure positive trait. Cost is 4 points.
- Uptime: Always-on while the trait is active; updates within ~1 second of equip/unequip. No conditions, no cooldown beyond the 30-tick throttle.
- Peer comparison: At cost 4, this is in the same range as traits like `UT_batteringram` (cost 7). Clothing weight and speed penalties are meaningful mid-to-late game quality-of-life gains. The benefit scales with how much clothing the player wears and whether those items impose penalties.
- Stack or exclusion notes: No mutual exclusions defined. No explicit stacking conflict with other clothing-modifier traits, though effects on the same item modifiers would interact additively with whatever base values the clothing has.
- Cost verdict: questionable — the trait provides two distinct, always-on passive benefits (weight halved, penalties nullified) with zero downside. At 4 points it competes with traits that have drawbacks or conditions. A cost of 5–6 would be more defensible for a no-downside dual-benefit trait.

## Regression Proof
- Existing test: `run_tests.lua` includes `"UniversalTraits:UT_fitted"` in the bulk registration-coverage list (the `expected_ids` array verified against `CharacterTrait._registered`). This proves the trait ID is registered.
- What it proves: Registration is present and the trait ID string is correct.
- Missing proof: No behavioral test exists. There is no test verifying that the `clothingUpdate` function correctly applies the 0.5 weight multiplier, raises speed modifiers to 1.0, stores originals, or restores values on unequip/trait removal. The 30-tick throttle and the ModData key names are also unverified by any test.
- Minimum next test if needed: A mock-based unit test for `clothingUpdate` with a fake player carrying one worn clothing item with `RunSpeedModifier = 0.9`, `CombatSpeedModifier = 0.85`, and `ActualWeight = 2.0`. Assert that after one active-state pass: weight becomes `1.0`, run modifier becomes `1.0`, combat modifier becomes `1.0`. Then toggle trait off and assert all three values are restored to originals.

## Final Verdict
- Source origin: proven
- UT implementation: faithful — logic is a direct port of the MoreTraits source with added throttle (every 30 ticks vs. every tick) and renamed ModData keys (`UT_fitted_` prefix). Behavior is identical.
- Description: accurate
- Balance: questionable
- Regression proof: partially protected (registration confirmed; runtime behavior unproven)
- Action needed: test fix
- Open gaps:
  - No behavioral unit test for `clothingUpdate` (weight halving, speed modifier restoration, per-item ModData lifecycle).
  - Cost deserves review: 4 points for a permanent, no-downside dual benefit may be underpriced relative to the trait tier.
  - `DisabledInMultiplayer` is `true` in UT vs. `false` in source — intentional divergence but not documented; should be confirmed as a deliberate design decision.
