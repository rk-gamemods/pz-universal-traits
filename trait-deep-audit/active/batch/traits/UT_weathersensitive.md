# UT_weathersensitive

## Trait Summary

- UT trait id: `UniversalTraits:UT_weathersensitive`
- Source mod: MoreSimpleTraits
- Source trait id: `WeatherSensitive`
- Current cost: -2
- Scripted: yes
- Owner: parallel trait audit / method 1 / `UT_weathersensitive`
- Status: audited; issues documented

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
- Source trigger path: registered through `TraitFactory.addTrait("WeatherSensitive", ..., -2, ...)`; runtime handled by `MSTWeatherSensitiveTrait()` on `EveryTenMinutes`; foraging penalty added through `forageSkills["WeatherSensitive"]`.
- Source behavior:
  - Trait cost is -2.
  - Uses climate forecast for today and tomorrow.
  - Tracks `player:getModData().MSThoursSinceLastRain` as a rolling barometric-pressure style accumulator.
  - During/approaching bad weather, can add head pain; after long wet stretches followed by clear forecast, can also trigger head pain.
  - Adds foraging penalties: `visionBonus=-0.2`, `weatherEffect=-3`, `darknessEffect=-3`.
  - Source behavior is proven from source files, though the exact gameplay intent is pain/forecast sensitivity rather than mood shifts.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UniversalTraits/media/registries.lua:260`
- Defined in UT_character_traits.txt: yes — `UniversalTraits/media/scripts/UT_character_traits.txt:1793-1801`
- Translation strings present: yes — `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt:557-558`
- Exclusions/grants correct: yes — no UT-side exclusions or grants exist; source mutex was against non-UT `Pluviophile`, so omission is acceptable here.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_weathersensitive.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_weathersensitive.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
  - `UniversalTraits/test/run_tests.lua`
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, traitId)` only
- Runtime chain (plain language):
  1. Every ten in-game minutes, the shared handler runs.
  2. It gets player 0 via `getPlayer()`.
  3. It exits unless that player has `UniversalTraits:UT_weathersensitive`.
  4. On a `ZombRand(3) == 0` roll, it increases stress by `0.05`, clamped to `1.0`.
  5. It does not read weather, forecast, temperature, outside state, or any saved accumulator.
- Actual behavior (exact values):
  - Trigger cadence: every `EveryTenMinutes` tick
  - Proc chance per tick: 1 in 3
  - Effect: `stats:setStress(min(1, currentStress + 0.05))`
  - Positive effect: none
  - Weather dependency: none
  - ModData/save state: none

## Description Integrity

- Display name check: acceptable. Weather Sensitive still fits the broad theme.
- Description check: inaccurate. Current text says storms drag the player down and clear days lift them up, but runtime code never checks weather and never gives a positive effect.
- Missing or misleading details:
  - No weather condition is implemented.
  - No positive clear-weather relief is implemented.
  - Source pain-style behavior was replaced with simple stress gain.
  - The text currently promises bidirectional mood shifts that do not exist.

## Balance Review

- Upside: none.
- Downside: small random stress drip (`+0.05` on one-third of `EveryTenMinutes` ticks).
- Uptime: low-to-medium; always eligible while trait is present, but only procs on 33.3% of ticks.
- Peer comparison: milder than the MoreSimpleTraits source version, which used forecast-aware head pain and added foraging penalties. Current UT version is much simpler and much weaker.
- Stack or exclusion notes: no UT mutual exclusion issue found; source DynamicTraits `Pluviophile` exclusion is not applicable unless UT later ports that trait.
- Cost verdict: questionable. `-2` is plausible for the actual mild stress drip, but not for the stronger weather-reactive behavior the description currently implies.

## Regression Proof

- Existing test: registration-only coverage in `UniversalTraits/test/run_tests.lua` expected ID list and total registration count checks.
- What it proves: the trait stays registered and included in the main trait inventory.
- Missing proof:
  - no test for `EveryTenMinutes` handler registration
  - no test for stress increase amount `+0.05`
  - no test for no-op when trait is absent
  - no test for clamp at `1.0`
  - no test for weather logic because no weather logic currently exists
- Minimum next test if needed:
  - Load `UT_weathersensitive.lua`, mock a player with and without the trait, stub `ZombRand`, fire the `EveryTenMinutes` event, and assert: absent trait = no change; present trait with winning roll = `stress + 0.05`; present trait near cap clamps at `1.0`.

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: questionable
- Regression proof: partially protected
- Action needed: doc fix | test fix
- Open gaps:
  - Decide whether UT should keep the simplified stress-drip design and rewrite the description to match, or restore real weather-aware behavior.
  - If faithful-port behavior is desired, add forecast checks, accumulator logic, and evaluate whether source foraging penalties should also be ported.
