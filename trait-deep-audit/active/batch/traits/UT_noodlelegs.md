# UT_noodlelegs

## Trait Summary

- UT trait id: UT_noodlelegs
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:noodlelegs
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime logic, `NoodleLegs` function, lines 4510–4553)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (source description)
- Source trigger path: `NoodleLegs(player)` is called from an `OnPlayerUpdate`-style tick handler in MoreTraits .lua. It fires only when the player is moving and is running or sprinting.
- Source behavior: While running or sprinting, the player has a random chance to trip and fall forward each tick. Trip chance denominator is `500001 + (Nimble * 12500) + (Sprinting * 12500)` against a threshold of 100, so at level 0/0 the base trip probability is roughly 100/500001 (~0.02%) per tick, decreasing as skills increase. Sprinting further reduces trip chance by multiplying the denominator by 0.6 (making trips more likely when sprinting than running). Graceful multiplies denominator by 1.2 (safer); Clumsy multiplies by 0.8 (more dangerous). A trip triggers `setBumpFallType("FallForward")` and `setBumpFall(true)`. No speed penalty. No endurance drain. Cost in source is -6.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — mutually exclusive with `UT_fast` and `UT_pacer`; `UT_fast` is also mutually exclusive with `UT_noodlelegs` and `UT_lurcher`
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_noodlelegs.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1130–1139)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 335–336)
  - `test/run_tests.lua` (lines 494–499)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` (called in both handlers; no other UTCore calls)
- Runtime chain (plain language):
  1. On new game, if the player has the trait, write `UT_speedMod = -0.2` into player mod data. The engine or a shared UT speed system reads this value to apply a 20% movement speed reduction.
  2. On every player update tick, if the player has the trait, increment a tick counter in mod data. When the counter reaches 30, reset it and subtract 0.005 from the player's current endurance (floored at 0). If endurance is already 0 the drain is skipped.
- Actual behavior (exact values):
  - Movement speed penalty: -20% (set once at game start via `UT_speedMod = -0.2`)
  - Endurance drain: -0.005 endurance per 30 ticks. At PZ's standard 30 ticks/second this equals -0.005 endurance/second continuously while alive. Drain stops when endurance reaches 0.

## Description Integrity

- Display name check: "Noodle Legs" matches the trait concept and mirrors the source mod name exactly.
- Description check: `"Your legs never quite cooperate. -20% movement speed and constant endurance drain (-0.005/sec)."` — the two stated effects (-20% speed, -0.005/sec drain) are accurate and match the code exactly.
- Missing or misleading details: The description is mechanically accurate for the UT implementation. However, the UT implementation is a complete redesign of the source behavior: the source trait causes random trip/fall events during running or sprinting with no speed penalty and no endurance drain. A player migrating from MoreTraits would experience a qualitatively different penalty. This divergence is not flagged anywhere in the description or audit trail. No functional issue with the description as written, but the redesign should be noted.

## Balance Review

- Upside: -6 points returned to the player at character creation.
- Downside: Permanent -20% movement speed at all times, plus continuous endurance drain of -0.005/sec (~0.3/min). Movement speed is one of the highest-value stats in PZ; -20% is severe and persistent with no counterplay mechanic. The endurance drain compounds the speed penalty by further limiting sprinting uptime.
- Uptime: Both penalties are always active (100% uptime) — speed penalty is set at game start unconditionally; endurance drain runs every update regardless of activity.
- Peer comparison: `UT_fast` costs +6 for a positive speed modifier; `UT_noodlelegs` at -6 is the direct inverse. `UT_lurcher` is excluded alongside `UT_fast`, suggesting lurcher occupies a similar negative movement niche. The source MoreTraits version at -6 delivered a probabilistic trip effect that only triggered during running/sprinting, which is significantly weaker than a permanent -20% speed reduction plus constant drain.
- Stack or exclusion notes: Excluded with `UT_fast` and `UT_pacer`. `UT_pacer` is also excluded with `UT_noodlelegs`. No grants. Stacks with all other non-excluded traits.
- Cost verdict: questionable — the UT redesign delivers a harsher, always-active dual penalty compared to the source's conditional trip mechanic. -6 points may undervalue the severity of a permanent -20% speed penalty combined with constant endurance drain; the source's probabilistic and skill-mitigated trip effect was substantially weaker for the same cost.

## Regression Proof

- Existing test: `test("UT_noodlelegs sets UT_speedMod < 0", ...)` in `test/run_tests.lua` lines 494–499.
- What it proves: Fires `OnNewGame` for a player with `UT_noodlelegs` and asserts that `getModData()["UT_speedMod"]` is a number less than 0. Confirms the new-game handler writes a negative speed modifier.
- Missing proof: No test covers the `onPlayerUpdate` path — the endurance drain logic (tick accumulation, 30-tick threshold, `setEndurance` call) is entirely untested. No test verifies the exact value `-0.2` (only `< 0` is checked). No test verifies drain halts correctly when endurance is at 0.
- Minimum next test if needed: Fire `OnPlayerUpdate` 30 times for a player with the trait and assert that endurance decreased by exactly 0.005. Also add a test that verifies endurance does not go below 0 when starting at 0.

## Final Verdict

- Source origin: proven — trait originates from MoreTraits (ToadTraits:noodlelegs), same display name and cost (-6)
- UT implementation: drifted — source mechanic (probabilistic trip/fall during running/sprinting, skill-mitigated) was replaced with a permanent speed penalty and continuous endurance drain; the concept is preserved but the mechanics are entirely different
- Description: accurate — the description correctly describes the UT implementation's actual behavior
- Balance: questionable — the UT redesign is mechanically harsher than the source for the same -6 cost; the dual always-active penalties may warrant a higher point refund
- Regression proof: partially protected — new-game speed modifier write is covered; endurance drain tick logic is not tested
- Action needed: test fix (add drain path tests); doc fix optional (note implementation divergence from source if internal tracking is desired)
- Open gaps:
  - No test for endurance drain tick loop or floor behavior at 0
  - No test asserting the exact speed modifier value (-0.2 specifically)
  - Balance review recommended: -6 cost vs. permanent -20% speed + unlimited endurance drain may be too generous for the player (too cheap a negative trait)
  - Internal note: UT diverged substantially from the source mechanic; if fidelity to MoreTraits is a design goal, the trip/fall system should be considered for implementation
