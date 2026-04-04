# UT_unwavering

## Trait Summary
- UT trait id: UniversalTraits:UT_unwavering
- Source mod: MoreTraits
- Source trait id: ToadTraits:unwavering (unwavering)
- Current cost: 6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua line 89
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt lines 1038-1045
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt lines 208-209
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua line 232
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua lines 850-863, 2187-2234, 5272-5308, 5363-5368, 5427, 5506, 5510
  - research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/server/MoreTraitsCC.lua lines 227-233
- Source trigger path:
  - Events.OnPlayerUpdate -> updateUnwavering(player, playerdata) for injury speed modifiers
  - Events.OnPlayerUpdate also rewrites Bite/BiteDefended hit reactions while in PlayerHitReactionState
  - Events.OnWeaponHitCharacter -> unwavering(actor, target, weapon, damage) for conditional bonus damage
- Source behavior:
  - Cost 6, no source exclusion found in reviewed script block
  - EN text promises reduced low-endurance/tired/pain damage penalty, reduced injury movement penalty, and faster recovery from zombie attacks
  - On weapon hit, source adds extra direct health loss at threshold tiers: 1.25x, 1.5x, or 2.0x damage when endurance/fatigue/pain thresholds are met
  - On player update, source raises body-part scratch/cut speed modifiers by 30 and deep-wound/burn modifiers by 60 once per player, mirrored to server
  - Source also swaps Bite/BiteDefended hit reactions to Unwavering variants; exact speed multiplier is only partially proven statically

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_unwavering.lua
  - UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua
  - repo-wide search for UT_panicResist and applyPanicResistance
- Event registrations:
  - Events.OnNewGame.Add(onNewGame)
- UT_CORE hooks used:
  - UTCore.hasTrait(player, TRAIT_ID)
  - UTCore.applyPanicResistance(player, 0.4)
- Runtime chain (plain language):
  1. On file load, UT registers one OnNewGame handler.
  2. On new game, it checks for the trait.
  3. If present, it calls UTCore.applyPanicResistance(player, 0.4).
  4. That helper only writes player:getModData()[UT_panicResist] = 0.4.
  5. No consumer of UT_panicResist was found anywhere in UT_CORE, UniversalTraits, or tests.
- Actual behavior (exact values):
  - Proven current effect: writes modData key UT_panicResist = 0.4 on new game only
  - No real panic reduction is currently proven; effect is likely inert because no consumer exists
  - No ongoing event handler exists after new game
  - Source mechanics absent from UT: no hit-reaction override, no injury-speed/body-part modifier logic, no weapon-hit bonus damage

## Description Integrity
- Display name check: matches source name
- Description check: UT text describes only a 40 percent panic resistance effect
- Missing or misleading details:
  1. Likely inert claim: no panic-resistance consumer was found in current UT code
  2. Major source drift: source trait was a multi-effect combat/injury trait, not a simple panic-resistance trait
  3. Dropped mechanics are undocumented: injury modifier, hit-reaction recovery, and conditional damage bonus are gone

## Balance Review
- Upside: only a one-time modData write is proven
- Downside: none
- Uptime: intended uptime would be constant, but current live benefit is unproven and likely zero
- Peer comparison: source justified cost 6 with several benefits; UT currently provides only an unconsumed flag
- Stack or exclusion notes: no confirmed exclusion issue; main problem is inertness/drift
- Cost verdict: wrong

## Regression Proof
- Existing test: registration-only coverage in UniversalTraits/test/run_tests.lua expected ID sweep
- What it proves: only that the trait ID exists
- Missing proof:
  - No test that OnNewGame sets UT_panicResist = 0.4 for trait holders
  - No test that non-holders are skipped
  - No test for actual panic reduction because no consumer exists
- Minimum next test if needed:
  - Load UT_unwavering.lua, fire Events.OnNewGame with a MockPlayer holding the trait, assert modData.UT_panicResist == 0.4
  - Add a no-trait guard test
  - After a real consumer exists, add a behavior test proving panic input is reduced by 40 percent

## Final Verdict
- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: wrong
- Regression proof: missing
- Action needed: code fix
- Open gaps:
  - No consumer for UT_panicResist was found, so the current UT implementation is only a one-time modData write and likely inert in gameplay
  - No evidence was found that UT intentionally replaced the source combat and injury bundle with a panic-resistance-only redesign
  - No regression test proves either the current OnNewGame modData write or any real panic-reduction behavior
