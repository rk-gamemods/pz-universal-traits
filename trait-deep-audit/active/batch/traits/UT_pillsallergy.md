# UT_pillsallergy

## Trait Summary
- UT trait id: UT_pillsallergy
- Source mod: DynamicTraitsExpandedMoodles (`mods/Dynamic-Traits-main`)
- Source trait id: `PillsAllergy`
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/NPCs/DTMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTPillsTraits.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTnewMechanics.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTMoodles.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/changes.txt`
- Source cost: -6
- Source mutual exclusion: none proven in reviewed source files
- Source trigger path:
  - `TraitFactory.addTrait("PillsAllergy", ..., -6, ...)`
  - `ISTakePillAction:perform()` is overridden in `DTPillsTraits.lua`
  - Vitamins add `DTDrugsAllergy +15`
  - Other pills add `DTDrugsAllergy +30`
  - While `getReduceInfectionPower() > 0`, a 1 in 9 roll adds `reduceInfectionPower / 4`
  - `DTMainFile.lua` runs `checkReduceInfectionPower`, `DTDrugsAllergy.allergyDecrease`, and `DTDrugsAllergy.allergyMoodleLv1..Lv4` every in game minute
- Source behavior:
  - Stateful medicine allergy using `DTDrugsAllergy` clamped to 0..100
  - Lv1 over 20..40: cough and sound
  - Lv2 over 40..60: more cough plus itch and pain events
  - Lv3 over 60..80: pain plus endurance loss and poison gain
  - Lv4 over 80..100: fatigue gain, endurance loss, health loss, faint or head pain events
  - `changes.txt` explicitly says a new drugs allergy for pills was created

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions or grants correct: N/A
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/registries.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_pillsallergy.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. New game starts.
  2. Trait check runs.
  3. If present, `player:getModData()["UT_pillsAllergyFlag"] = true` is written.
  4. Nothing else in UT production code reads that flag.
- Actual behavior (exact values): one time write of `UT_pillsAllergyFlag = true` on new game only. No pill hook, no periodic hook, no reaction severity, no moodle, no pain, no fatigue, no endurance loss, no poison, no health loss.

## Description Integrity
- Display name check: accurate to source concept
- Description check: misleading because current UT code never reacts to pills or medicine
- Missing or misleading details:
  - No source severity ladder
  - No vitamins versus other pills split
  - No cough, pain, poison, fatigue, endurance, or health consequences
  - Current description promises a medicine reaction that is not implemented

## Balance Review
- Upside: none
- Downside: none in current UT behavior
- Uptime: none beyond an unused moddata flag
- Peer comparison:
  - Source trait is an active escalating penalty
  - UT planning labeled this trait `Medicine reaction | OnConsumeMedicine`
  - Current shipped UT trait is only a stub flag write
- Stack or exclusion notes: no UT exclusions proven
- Cost verdict: wrong because source is -6 for a real penalty while UT is -4 for no gameplay effect

## Regression Proof
- Existing test: trait id appears in `UniversalTraits/test/run_tests.lua` registration list
- What it proves: registration presence only
- Missing proof: no test covers pill consumption, medicine reaction, or any consumer of `UT_pillsAllergyFlag`
- Minimum next test if needed:
  - Add a behavior test for medicine consumption with the trait
  - Add a negative test without the trait
  - Add proof that some production consumer reads the moddata flag if that design stays

## Final Verdict
- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: wrong
- Regression proof: missing
- Action needed: code fix
- Open gaps:
  - `UT_pillsAllergyFlag` is written but never read in current UT production code
  - Planned `OnConsumeMedicine` behavior is missing
  - Source cost -6 was changed to -4 without documented rationale
  - Source severity and decay system was not ported
  - Vitamins and other pills are not distinguished
  - Infection reduction medicine interaction was not ported
  - No automated regression proof exists
