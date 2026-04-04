# UT_pacer

## Trait Summary

- UT trait id: UT_pacer
- Source mod: SomewhatTraits (SWTraits)
- Source trait id: SWTraits:SWPacer
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (script definition)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (source strings)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (runtime implementation)
- Source trigger path: `Events.OnTick.Add(SWPacer)` — fires every game tick while the player has the trait
- Source behavior: While running or sprinting, restores endurance each tick by `timeMultiplier * 0.0015` (running) or `timeMultiplier * 0.0075` (sprinting, multiplied by 5). Effectively slows endurance drain rather than granting a movement speed bonus. No unhappiness or indoor mechanic in the source.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — mutually exclusive with `UniversalTraits:UT_noodlelegs` (and UT_noodlelegs also excludes `UniversalTraits:UT_fast` and `UniversalTraits:UT_pacer`); no grants
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_pacer.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1141–1150)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 338–339)
  - `test/run_tests.lua` (lines 806, 830, 870–881)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` called in both handlers; no other UT_CORE calls
- Runtime chain (plain language):
  1. On new game, if the player has the trait, sets `player:getModData()["UT_speedMod"] = 0.15`. This modData key is written but nothing in this file reads it back or applies it to actual movement speed — it is a passive marker only (the engine or another system must consume `UT_speedMod`).
  2. On every player update, checks for the trait. Initialises `UT_pacer_indoor_ticks` to 0 if nil.
  3. If the player is outdoors, resets the tick counter to 0 and returns.
  4. If the player is indoors, increments the counter by 1.
  5. When the counter reaches 600, adds 2 to the current unhappiness level (capped at 100) via `bd:setUnhappinessLevel(...)`, then resets the counter to 0.
- Actual behavior (exact values):
  - Movement speed: +15% via `UT_speedMod = 0.15` written to modData on new game (passive write; engine consumption not verified in this file)
  - Unhappiness penalty: +2 unhappiness per 600 consecutive indoor `OnPlayerUpdate` ticks; counter resets on any outdoor tick
  - Unhappiness cap: 100

## Description Integrity

- Display name check: "Pacer" — matches the restless/movement theme; acceptable
- Description check: "You have always had a brisk, purposeful walk. +15% movement speed. After ~20 seconds indoors, you become restless (+2 unhappiness per cycle)." — the +15% claim depends on `UT_speedMod` being consumed by the engine, which is not verified inside this file. The "~20 seconds" approximation for 600 `OnPlayerUpdate` ticks is plausible but not precisely calibrated (tick rate depends on game speed). The +2 unhappiness per cycle is accurate.
- Missing or misleading details: The description does not clarify that unhappiness accumulates continuously in cycles (every ~20 s indoors) rather than applying once. The description implies the penalty fires once ("you become restless") rather than repeatedly. This is misleading. Additionally, whether `UT_speedMod = 0.15` is actually consumed by the movement system is not provable from this file alone — if the key is not read, the +15% speed is silently absent.

## Balance Review

- Upside: +15% walk speed (if `UT_speedMod` is consumed); always-on passive
- Downside: Persistent unhappiness pressure (+2 per ~600-tick indoor cycle) whenever sheltering inside a building; unlimited stacking across cycles
- Uptime: Speed bonus is always on. Unhappiness penalty applies only while indoors; any outdoor tick resets the counter fully
- Peer comparison: UT_fast is the direct speed peer (also in Phase 2 — Movement). UT_pacer costs 4 and adds a meaningful downside; UT_noodlelegs (negative, -6 points) degrades movement. At 4 points with a real indoor penalty the cost is reasonable if the speed bonus is functional
- Stack or exclusion notes: Mutually exclusive with `UniversalTraits:UT_noodlelegs`. No exclusion against `UniversalTraits:UT_fast` from UT_pacer's own definition (UT_noodlelegs excludes both, but UT_pacer does not exclude UT_fast directly — a player could take both UT_pacer and UT_fast if UT_noodlelegs is not selected)
- Cost verdict: justified — if the speed bonus is live; questionable if `UT_speedMod` is not consumed (downside with no upside)

## Regression Proof

- Existing test: "pacer applies unhappiness after 600 indoor ticks" (`run_tests.lua` line 870). Constructs a mock player with the trait and `indoorTicks = 599`, fires `OnPlayerUpdate` once, asserts `_unhappinessLevel` increased above baseline (50).
- What it proves: The unhappiness branch triggers correctly on the 600th indoor tick and increments the value
- Missing proof:
  - No test verifies that `UT_speedMod = 0.15` is written to modData on `OnNewGame`
  - No test verifies the outdoor-reset logic (counter resets to 0 when not indoors)
  - No test verifies the unhappiness cap at 100
  - No test verifies that the unhappiness counter resets after firing (preventing double-fire on the same tick)
  - No integration test confirms `UT_speedMod` is read and applied by the movement system
- Minimum next test if needed: Add a test for `onNewGame` that fires `Events.OnNewGame` on a pacer player and asserts `player:getModData()["UT_speedMod"] == 0.15`. Add a complementary test with `indoors = false` that asserts the counter resets to 0 and no unhappiness change occurs.

## Final Verdict

- Source origin: proven — SomewhatTraits SWPacer confirmed in scripts, translation, and runtime
- UT implementation: drifted — source SWPacer restores endurance during running/sprinting (endurance drain reduction); UT_pacer replaces this entirely with a +15% speed modData write plus an indoor unhappiness penalty; neither mechanic existed in the source
- Description: incomplete — the repeated-cycle nature of the unhappiness penalty is understated ("you become restless" reads as a one-time state change, not a recurring +2 drain); the +15% speed claim is unverified at the engine level
- Balance: justified — cost matches a real downside; however, if `UT_speedMod` is not consumed, the balance flips and the trait is purely harmful at a positive point cost
- Regression proof: partially protected — unhappiness trigger is covered; new-game speed write, outdoor reset, and cap are not tested
- Action needed: doc fix + test fix + research gap
- Open gaps:
  - Confirm whether `UT_speedMod` is consumed by the movement system (search for readers of this modData key across the codebase)
  - Rewrite UIDescription to reflect the repeating unhappiness cycle ("every ~20 s indoors" rather than a one-time state)
  - Add tests for `onNewGame` speed write, outdoor counter reset, and unhappiness cap
  - Clarify whether UT_pacer should also mutually exclude UT_fast (currently it does not, but taking both would stack two speed bonuses)
