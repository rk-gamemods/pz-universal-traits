# UT_pessimist

## Trait Summary
- UT trait id: `UniversalTraits:UT_pessimist`
- Source mod: FillerTraits
- Source trait id: `Pessimist`
- Current cost: -2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua`
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua`
- Source registration:
  - `TraitFactory.addTrait("Pessimist", getText("Pessimist"), -4, getText("Will always be at least a little sad."), false, false)`
- Source trigger path:
  - `Events.OnPlayerUpdate.Add(Pessimist)`
- Source behavior:
  - If the player has `Pessimist` and `bodydamage:getUnhappynessLevel() < 40`, the source sets `bodydamage:setUnhappynessLevel(40)`.
  - Net effect: continuous minimum unhappiness floor of 40.
- Source exclusions:
  - `TraitFactory.setMutualExclusive("Optimist", "Pessimist")`

## Current UT Evidence

### Structure
- Registered in `registries.lua`: yes - `UTTraitsRegistries.UT_pessimist = CharacterTrait.register("UniversalTraits:UT_pessimist")` in `UniversalTraits/media/registries.lua:253`
- Defined in `UT_character_traits.txt`: yes - `UniversalTraits/media/scripts/UT_character_traits.txt:1723`
- Translation strings present: yes
  - `UI_UT_pessimist = "Pessimist"` in `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt:536`
  - `UI_UT_pessimistDesc = "You expect the worst and, frankly, you are usually right. Every 10 in-game minutes, stress increases by +0.05."` in `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt:537`
- Exclusions/grants correct: yes for declared ids; `UT_pessimist <-> UT_optimist` and `UT_pessimist <-> UT_mstoptimist` are real, namespaced, and bidirectional in script blocks
- Runtime Lua file exists: yes - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_pessimist.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_pessimist.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
  - `UniversalTraits/test/run_tests.lua`
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. Every 10 in-game minutes, the handler runs.
  2. It gets the active player with `getPlayer()` and returns early if nil.
  3. It returns early unless the player has `UniversalTraits:UT_pessimist`.
  4. It reads `player:getStats()` and sets stress to `math.min(1, current + 0.05)`.
- Actual behavior (exact values):
  - Cadence: once per 10 in-game minutes
  - Effect: `+0.05` stress each tick
  - Hourly rate: `+0.30` stress per in-game hour
  - Clamp: capped at `1.0`
  - No unhappiness floor
  - No panic effect
  - No moddata, cooldown, persistence state, or helper chain beyond `UTCore.hasTrait`

## Description Integrity
- Display name check: accurate - current UT name matches the source name and intent
- Description check: accurate for the current UT implementation; it correctly states the affected stat, cadence, and amount
- Missing or misleading details:
  - The description does not mention the 1.0 stress cap, but that omission is minor and not misleading
  - The current UT description is honest about the present code, but the trait is no longer a faithful port of the source's unhappiness-floor mechanic

## Balance Review
- Upside: none
- Downside: always-on `+0.05` stress every 10 in-game minutes with 100% uptime
- Uptime: unconditional while the trait is present
- Peer comparison:
  - `UT_depressive` is harsher at `+0.08` stress per 10 minutes for `-4`
  - `UT_melancholic` currently uses a different mechanic in source-inspired audits, but in code it is a distinct negative-mood peer and already excludes `UT_depressive`
  - `UT_pessimist` sits awkwardly between them because it can stack with both other negative mood traits while sharing the same design space
- Stack or exclusion notes:
  - Source only excluded `Optimist`
  - UT sensibly adds `UT_mstoptimist`
  - UT still allows stacking with `UT_depressive` and `UT_melancholic`
  - `UT_MET.lua` has no mood-group entry for this pair, so Lua-side reference coverage does not mirror the script exclusions here
- Cost verdict: questionable - `-2` is plausible in isolation, but current peer spacing and stackability make the price/design line feel inconsistent

## Regression Proof
- Existing test:
  - `UniversalTraits/test/run_tests.lua:285` includes `UniversalTraits:UT_pessimist` in the expected registered trait list
  - `UniversalTraits/test/run_tests.lua:347` proves the script block resolves and its declared mutually exclusive ids point at registered traits
- What it proves:
  - Registration exists
  - Script definition exists
  - Declared script exclusions reference valid ids
- Missing proof:
  - No test proves the `EveryTenMinutes` handler adds exactly `+0.05` stress
  - No test proves the `1.0` clamp
  - No test proves the no-trait guard
  - No test proves the nil-player guard
- Minimum next test if needed:
  - Load `UT_pessimist.lua`, fire `Events.EveryTenMinutes` with a mocked active player holding `UniversalTraits:UT_pessimist`, and assert stress rises by exactly `0.05`
  - Add companion tests for the cap at `1.0`, missing-trait no-op behavior, and nil-player safety

## Final Verdict
- Source origin: proven
- UT implementation: drifted
- Description: accurate
- Balance: questionable
- Regression proof: missing
- Action needed: code fix
- Open gaps:
  - The source trait enforced unhappiness, but UT rewrote it into periodic stress gain; that design drift is real and should be explicitly accepted or corrected.
  - `UT_pessimist` can still stack with `UT_depressive` and `UT_melancholic`, leaving the negative-mood lane internally inconsistent.
  - There is still no behavioral regression test for the actual periodic stress handler.
