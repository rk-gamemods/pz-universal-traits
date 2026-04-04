# UT_sorelegs

## Trait Summary

- UT trait id: UT_sorelegs
- Source mod: MoreSimpleTraits (also present in MoreSimpleTraitsVanilla)
- Source trait id: SoreLegsTrait
- Current cost: -10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTFitnessAction.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trait cost: -8
- Source trigger path: `Events.EveryOneMinute.Add(sorelegscalc)` for walking/running pain; `Events.OnWeaponSwingHitPoint.Add(sorellegsstomppain)` for stomp pain; `ISFitnessAction:exeLooped` override for exercise pain
- Source behavior: Complex, pain-based system across multiple body parts, scaled by Sprinting skill level and movement state:
  - **Walking (not running, not sprinting):** Randomly increments foot pain on Foot_L and Foot_R (up to cap of 18) each minute via ZombRand(1)/ZombRand(3) calls
  - **Running, Sprinting level 0-3:** Adds pain to UpperLeg_L/R (up to ZombRand(4)+1), LowerLeg_L/R (up to ZombRand(3)+1), Foot_L/R (up to ZombRand(8)+1, capped at 42) per minute; while sprinting also drains endurance by 0.03 per minute
  - **Running, Sprinting level 4-7:** Slightly reduced pain ranges (ZombRand(3)+1 for upper/lower leg, ZombRand(6)+1 for feet); sprinting drains endurance by 0.02 per minute
  - **Running, Sprinting level 8-10:** Further reduced pain ranges (ZombRand(2)+1 for upper/lower leg, ZombRand(4)+1 for feet); sprinting drains endurance by 0.01 per minute
  - **Stomping (unarmed, aim-at-floor):** Adds Foot_R pain (ZombRand(6)+2, capped at 50) per swing hit
  - **Fitness (squats):** Adds pain to both upper and lower legs (ZombRand(4) chance, ZombRand(4)+1 amount) per exercise loop tick
  - **Fitness (burpees):** Adds pain to both upper and lower legs (ZombRand(4)+2) and feet (ZombRand(3)+2) per exercise loop tick
  - Mutually exclusive with MarathonRunner in source

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A (no exclusions defined in UT_character_traits.txt)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sorelegs.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt` (lines 1163-1171)
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 344-345)
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)`
  - `UTCore.applyCarryWeight(player, -2)`
  - `player:getModData()["UT_speedMod"] = -0.2`
- Runtime chain (plain language): On player creation, the handler checks whether the player has the trait. If so, it applies -2 to base carry weight via UTCore and writes -0.2 into the player's ModData under the key `UT_speedMod`, which is presumably picked up by a shared movement-speed hook in UTCore.
- Actual behavior (exact values): -2 base carry weight (permanent, applied once at creation); -20% movement speed (permanent, applied once at creation via ModData).

## Description Integrity

- Display name check: "Sore Legs" matches the trait intent — acceptable.
- Description check: "Your legs are weak and prone to fatigue. -20% movement speed and -2 base carry weight." — the two stat changes are correctly listed and the values match the code exactly.
- Missing or misleading details: None. The description accurately reflects what the UT implementation does. It correctly omits the source mod's pain system, which was not ported. No fabricated claims are present.

## Balance Review

- Upside: none (pure negative trait)
- Downside: -20% movement speed (permanent, unconditional) and -2 base carry weight (permanent, unconditional)
- Uptime: 100% — both penalties are applied at player creation and never removed
- Peer comparison:
  - UT_lurcher: -10 cost, -15% movement speed + -15% work speed + exhaustion-stumble risk; similar cost but lurcher adds a third mechanic and has a stumble hazard
  - UT_noodlelegs: movement-focused negative trait at different cost; exact values not audited here
  - UT_sorelegs at -10 delivers a harder movement penalty (-20% vs lurcher's -15%) plus a carry penalty, without the stumble risk; the combined effect is substantial and the cost appears defensible relative to lurcher
  - Source SoreLegsTrait was priced at -8 with a complex pain system instead of flat stat penalties; UT version trades pain complexity for flat stats and prices at -10
- Stack or exclusion notes: No MutuallyExclusiveTraits defined in UT_character_traits.txt; the source excluded MarathonRunner but UT does not carry that forward. The -20% speed mod uses the `UT_speedMod` ModData key — stacking behavior with other speed-modifying UT traits depends on how the shared hook accumulates multiple `UT_speedMod` writes; this is not confirmed from the files reviewed.
- Cost verdict: justified

## Regression Proof

- Existing test: UT_sorelegs is listed in the run_tests.lua Phase 2 movement batch (line 244), meaning it is included in whatever test suite covers movement traits
- What it proves: The trait ID is registered and participates in the movement trait test pass; does not prove carry weight or speed-mod values
- Missing proof: No dedicated unit test verifying that onCreatePlayer applies exactly -2 carry weight and sets UT_speedMod to -0.2 for a player holding this trait
- Minimum next test if needed: Construct a mock player with UT_sorelegs, call onCreatePlayer, assert `UTCore.applyCarryWeight` was called with -2 and `player:getModData()["UT_speedMod"] == -0.2`

## Final Verdict

- Source origin: proven (MoreSimpleTraits, trait id SoreLegsTrait, cost -8)
- UT implementation: simplified (source used a per-minute pain system scaled by Sprinting skill across six body parts plus exercise and stomp hooks; UT reduces this to two flat permanent stat changes applied at player creation)
- Description: accurate (both stated values match code exactly)
- Balance: justified
- Regression proof: partially protected (included in movement batch test; no value-level assertion)
- Action needed: test fix
- Open gaps:
  - The source exclusion against MarathonRunner was not carried into UT_character_traits.txt; whether this is intentional simplification or an oversight is not documented
  - `UT_speedMod` accumulation behavior with other speed traits is not confirmed from files reviewed; if multiple traits write to the same ModData key, only the last write wins
  - No test verifies the exact carry weight delta or speed-mod value at character creation
