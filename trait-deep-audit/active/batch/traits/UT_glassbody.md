# UT_glassbody

## Trait Summary
- UT trait id: UT_glassbody
- Source mod: More Traits (ToadTraits / MoreTraits)
- Source trait id: ToadTraits:glassbody
- Current cost: -10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (script definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (source strings)
- Source trigger path: `Events.OnPlayerUpdate` fires `OnPlayerUpdate`, which calls `GlassBody(player, playerData)` each frame when the player has the trait. A separate `Events.OnPlayerGetDamage` listener (`MTPlayerHit`) also checks for the trait but does not duplicate the GlassBody call; the damage amplification is applied inside `GlassBody` on the update loop.
- Source behavior: On each player update tick, the mod reads `bodyDamage:getOverallBodyHealth()` and compares it to the previously stored value. If HP dropped and the drop was between 0 and 50 HP, it rolls a 33% chance to apply a secondary wound to a random body part. The additional damage applied is `difference * 2` (doubling the detected drop). If the drop exceeds 0.33 HP the secondary effect is a fracture (`fractureTime = ZombRand(20) + 10`); if between 0.1 and 0.33 it is a scratch. Lucky/Unlucky modifiers shift the 33% chance and woundstrength by ±5 per luck impact level. The effect is suppressed while the player is asleep or the time multiplier exceeds 4.0. The source description claims ×2 total damage from all sources, scratch-from-minor-injuries, broken-bone-from-short-falls, and encumbrance damage — all delivered through this secondary wound system, not a direct multiplier. The cost in source is -10 with `DisabledInMultiplayer = false`.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — mutually exclusive with `UniversalTraits:UT_analgesia` (bidirectional, confirmed in both definitions)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_glassbody.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1228–1237)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 368–369)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires.
  2. If the player has `UniversalTraits:UT_glassbody`, the function writes `player:getModData()["UT_damageMult"] = 1.5` into the player's mod data.
  3. No further events are registered. The trait solely relies on whatever downstream system reads `UT_damageMult` from mod data and applies it as a damage multiplier.
- Actual behavior (exact values): Sets `UT_damageMult = 1.5` (+50% incoming damage). One-shot on new game only; no update loop, no per-hit recalculation, no fracture, no scratch, no encumbrance check, no luck interaction.

## Description Integrity
- Display name check: "Glass Body" — matches intent and source name ("Made of Glass" in source). Acceptable rename.
- Description check: "Your body feels like it was built to break. All incoming damage is multiplied by ×1.5 (+50% damage taken)." — accurately reflects the UT implementation (a flat 1.5× multiplier flag). However, it is a narrower promise than the source trait, which also caused scratches, fractures, and encumbrance damage.
- Missing or misleading details: The description does not mention that the multiplier is only applied at new-game start and has no effect on saves loaded mid-game or characters created outside `OnNewGame`. The description also does not flag that the trait only functions if a consuming system reads `UT_damageMult` from mod data — if that system is absent or not loaded, the trait silently does nothing.

## Balance Review
- Upside: none — pure downside trait
- Downside: +50% incoming damage from all sources (×1.5 multiplier stored in mod data), permanent for the life of the character
- Uptime: always-on (100%), provided the downstream damage-multiplier system reads the flag
- Peer comparison:
  - `UT_brittle` costs -6 and applies a narrower physical debuff
  - `UT_analgesia` costs +12 (mutually exclusive positive counterpart)
  - Source `ToadTraits:glassbody` cost was also -10, confirming cost was ported directly
- Stack or exclusion notes: Mutually exclusive with `UT_analgesia`. No stated exclusion from other damage-modifier traits (`UT_brittle` can be taken alongside, stacking debuffs).
- Cost verdict: justified — -10 for a permanent +50% damage-taken multiplier with no conditions or uptime limits is consistent with the source cost and comparable to peer traits at similar price points, assuming the multiplier system actually applies it.

## Regression Proof
- Existing test: `run_tests.lua` line 250 — `UT_glassbody` appears in the `expected_ids` list used by the "all 198 trait IDs registered with CharacterTrait" test and the "total registration count is 198" test.
- What it proves: The trait ID is registered in `registries.lua` and `CharacterTrait` sees it. Confirms the trait exists and is enumerable. Does not prove runtime behavior.
- Missing proof:
  - No test verifies that `onNewGame` sets `UT_damageMult = 1.5` on a player with the trait.
  - No test verifies that a player without the trait does not receive `UT_damageMult`.
  - No test verifies the mutual exclusion with `UT_analgesia` is enforced.
  - No test verifies that the consuming damage system reads and applies `UT_damageMult` correctly.
- Minimum next test if needed: Mock a player with `UT_glassbody`, call `onNewGame(player)`, assert `player:getModData()["UT_damageMult"] == 1.5`. Mock a player without the trait and assert `UT_damageMult` is nil after the same call.

## Final Verdict
- Source origin: proven — `ToadTraits:glassbody` from MoreTraits confirmed with matching cost (-10), trait ID structure, and display name lineage
- UT implementation: simplified — the source applied a complex per-tick wound system (fractures, scratches, encumbrance damage, luck interaction, sleep suppression); the UT version replaces all of that with a single mod-data flag (`UT_damageMult = 1.5`) written once at new-game start
- Description: incomplete — accurate for the UT implementation as written, but does not disclose that the effect is new-game-only, does not warn that it is inert without a consuming system, and omits the secondary wound behaviors present in the source
- Balance: justified — cost matches source and is proportionate to the stated penalty
- Regression proof: partially protected — registration is proven; runtime behavior is unproven
- Action needed: test fix, doc fix
- Open gaps:
  - No behavioral test for `onNewGame` setting `UT_damageMult`
  - Description should note the new-game-only application and dependency on a consuming damage-multiplier system
  - Confirm whether `OnLoadedPlayer` or a similar event should also set the flag (currently characters loaded from save after a restart would not have the flag re-applied unless the consuming system persists it)
  - `DisabledInMultiplayer` is `true` in UT; source had `false` — divergence should be a conscious decision, not an oversight
