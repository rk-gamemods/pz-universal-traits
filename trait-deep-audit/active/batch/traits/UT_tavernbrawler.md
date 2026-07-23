# Tavern Brawler deep audit

## Scope and authority

This record is the post-behavior evidence milestone for `UniversalTraits:UT_tavernbrawler`. Accepted behavior commit `0af8b161772237f245e5ef22be614b653279c20c` is immutable authority. Runtime, release, tests, mocks, definitions, registries, and UI are evidence inputs only in this milestone.

## Accepted contract

- Cost 2, `SmallBlunt = 1`, no grants, no exclusions, and `DisabledInMultiplayer = true`.
- The only damage trigger is a true stomp reported by `attacker:isShoveStompAnim()`.
- `OnHitZombie` has exactly `(zombie, attacker, bodyPart, weapon)`.
- The trait subtracts 30 direct zombie health before vanilla hit damage.
- On SVN revision 964, an ordinary zombie starts at 1.8 through 2.1 health (`IsoZombie.java:554`). Therefore 30 is an instant-kill magnitude, not moderate bonus damage, and instant kill remains the accepted pre-campaign outcome.
- A lethal subtraction calls `zombie:Kill(attacker)` exactly once.
- Re-evaluating the module removes its prior owned callback and leaves one callback.
- English truthfully says a stomp kills a downed zombie instantly.

## Exact engine and Kahlua sequence

1. `SwipeStatePlayer.java:228` computes the stomp animation state and calls `player.setShoveStompAnim(isStompAnim)`.
2. `IsoGameCharacter.java:1163-1168` exposes the boolean getter and setter used through the Java-Lua bridge.
3. `IsoZombie.java:1357` fires `OnHitZombie(this, wielder, bodyPart, weapon)` before `super.Hit(...)` applies vanilla damage.
4. `UT_tavernbrawler.lua:11-23` gates local attacker, trait ownership, and the true-stomp flag, subtracts 30 from current health, and calls `Kill(attacker)` once when the result is non-positive.
5. `IsoGameCharacter.java:15249-15264` records the killer and sets health to zero in `Kill`.
6. `SwipeStatePlayer.java:410` clears `shoveStompAnim` when the attack state exits.

The event ordering proves that the 30-point write precedes vanilla damage. Static Java and Lua evidence proves the intended path and signatures, but not current-version Kahlua execution or live event arguments.

## Reconciled campaign findings

`B11-TAVERN-001` is statically proven corrected by the true-stomp discriminator. The accepted commit also proves closure of the independent armed-prone false positive, wrong event signature, mock-created false confidence, and duplicate-handler defect. No Tavern-specific independent omission remains.

The following surfaces are proven correct: intent, event signature, static runtime path, numbers, English description, focused tests and mocks, source/release parity, and stacking/reload structure. Runtime observation is deliberately not inferred from standard-Lua tests.

## Remaining proof

- Current-build Kahlua execution and live `OnHitZombie` arguments/flag timing.
- Live 30-before-vanilla ordering, handler count, and `Kill(attacker)` attribution.
- New-game, save-load, death, repeated world entry, and gameplay observation.
- Balance telemetry and profiler capture.
- Rendered English and non-English localization coverage.
- The separate pre-existing UniversalTraits source poster package issue.

Multiplayer, backward save migration, deployment, and live-mod mutation are explicit non-goals.
