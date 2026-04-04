# UT_fast

## Trait Summary

- UT trait id: UT_fast
- Source mod: MoreTraits (ToadTraits)
- Source trait id: ToadTraits:fast
- Current cost: 6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (runtime implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/registries.lua` (registration)
- Source trigger path: `Events.OnPlayerUpdate` → `MT_FastGimpTraits(player)` fires every frame when the player is moving; checks `player:hasTrait(ToadTraitsRegistries.fast)` and then reads the current gait (walking / running / sprinting).
- Source behavior: On every player-update tick where the player is physically moving, the source reads the player's deferred movement vector and multiplies it by a sandbox-configurable additive modifier. Defaults (from code): walking +0.25, running +0.50, sprinting +0.75. The result is applied via `player:Move(vector)` — i.e., the speed gain is an additive injection to the movement vector, not a multiplier on the base speed stat. No endurance mechanic is present in the source. The source description states "+15% movement speed" (`UI_trait_fastdesc`), which does not match the actual per-gait vector values in code. Cost in source: 6 points. Mutually exclusive with `ToadTraits:gimp`.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — mutually exclusive with `UniversalTraits:UT_noodlelegs` and `UniversalTraits:UT_lurcher`
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_fast.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1119–1128)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 332–333)
  - `test/run_tests.lua` (lines 79–81, 487–492)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — fires every player update tick
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — presence check used in both handlers
  - `UTCore.applySpeedModifier(player, 0.3)` — called once in `onNewGame`
- Runtime chain (plain language):
  1. On new game, if the player has the trait, `UTCore.applySpeedModifier` is called with a value of `0.3`, writing `UT_speedMod = 0.3` into the player's mod data. The engine or UT core reads this value to apply the speed bonus persistently.
  2. On every subsequent player update tick, if the player has the trait, a mod-data counter (`UT_fast_tick`) increments. When it reaches 30, it resets to 0 and the endurance regen branch runs: if the player's current endurance is below max, it is increased by `0.01`, capped at max.
- Actual behavior (exact values):
  - Speed: +30% movement speed applied once at new game via `UTCore.applySpeedModifier(player, 0.3)`.
  - Endurance regen: +0.01 endurance per 30 ticks while endurance is below maximum. Fires unconditionally regardless of player state (moving, idle, etc.).

## Description Integrity

- Display name check: "Fast" — matches intent; accurate.
- Description check: `UI_UT_fastDesc` = "+30% movement speed. Also slowly regenerates endurance (+0.01 per 30 ticks) while endurance is not full." — this accurately describes both runtime effects with exact values.
- Missing or misleading details: None. The description correctly states the speed value, the endurance regen rate, and the condition (below max). No issues found.

## Balance Review

- Upside: +30% movement speed (permanent, unconditional); passive endurance regen of +0.01 per 30 ticks when below max.
- Downside: none — pure positive trait.
- Uptime: Speed bonus is 100% permanent. Endurance regen is 100% uptime whenever endurance is not full (i.e., during and after exertion).
- Peer comparison: `UT_pacer` costs 4 points. `UT_pacer` likely provides a smaller movement bonus (name implies jogging/pacing). `UT_fast` at 6 points provides both a substantial speed increase AND a secondary passive endurance recovery, making it potentially overloaded for its cost relative to movement-only peers. The source `ToadTraits:fast` also cost 6 with movement only. The UT version added endurance regen on top without adjusting cost.
- Stack or exclusion notes: Mutually exclusive with `UT_noodlelegs` (−6 cost, movement penalty + endurance drain) and `UT_lurcher` (−5 cost, movement penalty trait). Cannot be combined with either negative movement trait. No exclusion from `UT_pacer` (positive movement trait at 4 points) — these could stack.
- Cost verdict: questionable — the source trait at 6 points was movement-only. UT adds an unconditional endurance regen secondary effect without increasing cost. The combined value (permanent speed + free endurance regen) likely exceeds the 6-point tier, especially compared to `UT_pacer` at 4.

## Regression Proof

- Existing test: Two tests cover this trait.
  1. `"UT_fast registered"` (line 79) — asserts `UTTraitsRegistries.UT_fast == "UniversalTraits:UT_fast"`.
  2. `"UT_fast sets UT_speedMod > 0"` (line 488) — fires `OnNewGame` with the trait active and asserts that `modData["UT_speedMod"]` is a positive number.
- What it proves: The trait is registered correctly and the `onNewGame` handler executes and writes a positive speed modifier to mod data.
- Missing proof: No test verifies the endurance regen logic in `onPlayerUpdate`. Specifically: (a) that the tick counter increments and resets at 30, (b) that endurance is increased by exactly 0.01 at tick 30, (c) that the regen does not fire when endurance is already at max.
- Minimum next test if needed: A test that creates a player with the trait, sets endurance below max, fires `OnPlayerUpdate` 30 times, and asserts that endurance increased by `0.01`. A second case should fire with endurance at max and assert no change.

## Final Verdict

- Source origin: proven — `ToadTraits:fast` from MoreTraits confirmed; definition, translation, cost, and exclusion all traced.
- UT implementation: simplified — the source used a per-frame movement vector injection with per-gait configurable multipliers; UT replaces this with a single stat modifier applied once at new game. The endurance regen is a UT addition with no source equivalent.
- Description: accurate — both effects are correctly documented with exact values.
- Balance: questionable — 6 points for permanent +30% speed plus free endurance regen is overloaded relative to the source (speed only) and relative to `UT_pacer` (4 points, movement only). Cost should be reviewed upward or endurance regen should be reduced.
- Regression proof: partially protected — speed modifier on new game is tested; endurance regen loop is untested.
- Action needed: test fix | doc fix (balance note) — add endurance regen tests; consider cost increase to 7–8 or reduce regen rate, and document the decision.
- Open gaps:
  - No test for the `onPlayerUpdate` endurance regen path (tick counter, regen value, at-max guard).
  - `UT_pacer` exclusion absent: confirm whether stacking `UT_fast` + `UT_pacer` is intended.
  - Cost was not raised when endurance regen was added; this gap should be resolved with an explicit design decision recorded.
  - Source `ToadTraits:fast` used sandbox-configurable per-gait modifiers; UT uses a flat stat write. The behavioral difference (gait-specific vs. flat) is intentional but undocumented.
