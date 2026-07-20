# UT_unwavering

## Trait Summary

- UT trait id: `UniversalTraits:UT_unwavering`
- Current cost: 6
- Status: statically validated; runtime proof remains open
- Accepted mechanic: fixed panic recovery, not proportional panic resistance

## Intent and History

- Pre-campaign master `a32f251` already contains the accepted mechanic.
- Commit `cf2da09` deliberately replaced the inert, write-only `UT_panicResist = 0.4` flag with an `EveryTenMinutes` panic drain.
- The Build 42 migration changed the panic domain from `0.1` to `10`; it did not change the player-facing mechanic.
- The obsolete `UI_EN.txt` repair did not update the game-loaded `UI.json`, leaving the prior 40 percent claim visible.

## Current Contract

- Event: `Events.EveryTenMinutes`
- Guard: the player has `UniversalTraits:UT_unwavering`
- Threshold: panic is strictly greater than 10
- Effect: subtract 10 panic, clamped to zero
- State: no trait-owned persistent state
- Multiplayer: disabled by the trait definition; multiplayer support remains out of scope

## Reconciliation

- Source and release `UI.json` now say: "Every 10 in-game minutes, if panic is above 10, panic is reduced by 10."
- Source and release Lua headers use the Build 42 values `10` and `10`.
- Gameplay code, cadence, threshold, amount, cost, registration, definition, exclusions, mocks, and live copies are unchanged.
- Focused tests cover the arithmetic boundary and exact source/release copy parity.

## Remaining Runtime Proof

- No current Kahlua/game run proves the event in the live engine.
- No current save/reload run proves the stateless handler after loading.
- No current rendered-English check proves the final UI text in game.
- No interaction/balance run with other panic modifiers was performed.
