# UT_sore

## Trait Summary

- UT trait id: UT_sore
- Source mod: FillerTraits
- Source trait id: Sore
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua
  - research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua
- Source trigger path: Events.OnPlayerUpdate.Add(Sore) runs Sore() every player update tick.
- Source behavior:
  - Registration uses TraitFactory.addTrait("Sore", getText("Sore"), -6, getText("Chronic soreness that causes constant states of minor physical pain."), false, false)
  - Source mutual exclusion uses TraitFactory.setMutualExclusive("Analgesia", "Sore")
  - Runtime checks player:HasTrait("Sore") and if stats:getPain() < 20 then calls stats:setPain(20)
  - Exact source effect is a continuous pain floor of 20. No strength penalty or endurance penalty was found.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions and grants correct: no. UT does not define the source side exclusion with UT_analgesia.
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - UniversalTraits/media/registries.lua
  - UniversalTraits/media/scripts/UT_character_traits.txt
  - UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt
  - UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sore.lua
  - UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua
  - UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua
- Event registrations:
  - UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
- UT_CORE hooks used:
  - UTCore.hasTrait(player, TRAIT_ID)
  - UTCore.applyStatFloor(player, CharacterStat.PAIN, 20)
  - UTCore.registerPeriodicHandler(...)
- Runtime chain in plain language: On each OnPlayerUpdate, the shared periodic wrapper resolves getPlayer() and calls handler(player). The trait handler exits unless the player has UniversalTraits:UT_sore. If the player has the trait, UTCore.applyStatFloor enforces CharacterStat.PAIN at a minimum value of 20.
- Actual behavior with exact values: pain is floored at 20 on every OnPlayerUpdate tick while the trait is active. No direct strength effect. No direct endurance effect.

## Description Integrity

- Display name check: acceptable drift. Source name was Sore. UT name is Chronically Sore.
- Description check: misleading. The current UT text says endurance and strength are reduced, but the code only enforces pain >= 20.
- Missing or misleading details:
  1. The real mechanic is a persistent pain floor of 20 and the description does not say that.
  2. The description claims strength and endurance penalties that do not exist.
  3. The source description was closer to the true mechanic than the UT description.

## Balance Review

- Upside: none
- Downside: permanent pain floor of 20
- Uptime: effectively 100 percent while active
- Peer comparison:
  - Source FillerTraits used the same pain floor at the same -6 cost.
  - UT_badteeth is an episodic pain downside. UT_sore is harsher because it is unconditional.
  - UT_analgesia is the direct opposite conceptually and was mutually exclusive in source.
- Stack or exclusion notes:
  - Missing UT_sore versus UT_analgesia exclusion is the main balance and structure gap.
- Cost verdict: justified

## Regression Proof

- Existing test: UniversalTraits/test/run_tests.lua only includes UniversalTraits:UT_sore in the expected id registration list.
- What it proves: registration only
- Missing proof:
  - No test proves the OnPlayerUpdate handler exists for UT_sore.
  - No test proves pain below 20 is raised to 20.
  - No test proves pain above 20 stays unchanged.
  - No test proves the no trait guard.
- Minimum next test if needed: load UT_sore.lua in the Lua harness, capture the mocked periodic handler, invoke it with a mock player with pain 10 and UT_sore, and assert pain becomes 20. Repeat with pain 30 and without the trait to verify unchanged behavior.

## Final Verdict

- Source origin: proven
- UT implementation: faithful
- Description: misleading
- Balance: justified
- Regression proof: partially protected
- Action needed: doc fix, test fix
- Open gaps:
  - Missing source exclusion with UT_analgesia
  - Description claims strength and endurance penalties that are not implemented
  - No behavioral test covers the pain floor runtime path
