# Strong and Nimble deep audit

## Scope and authority

- Trait: `UniversalTraits:UT_strongnimble`
- Accepted behavior baseline: pre-campaign `master`
- Engine baseline: PZCodebase SVN 964, Steam BuildID 23504596
- Product scope: single-player, current `42.0` package only
- Explicit non-goals: multiplayer, backward save migration, deployment

## Accepted contract

- Display name: Strong and Nimble
- Cost: 5
- XP boosts: Nimble +2 and Strength +1
- Grants: none
- Exclusions: none
- Multiplayer: disabled
- Pre-campaign promise: the player does not fall while climbing fences or ropes

The engine has distinct failure causes under that last sentence. The corrected
and proven static contract prevents the stochastic low-fence outcome and the
stochastic fall check on an intact sheet rope. It preserves ordinary falls,
unsupported-floor fence outcomes, obstacles, lunges, and the forced fall when a
rope is removed. Whether the pre-campaign promise should also override the
missing-rope path remains a user decision and is not guessed here.

## Pre-campaign and inherited failures

The pre-campaign runtime tried to clear `bFalling` after detecting a climb-like
action and registered `OnFenceClimb` and `OnClimbFence`. Neither event exists in
SVN 964. The broad fallback could also affect an ordinary fall, and the test
mock supplied the assumed cancellation surface instead of proving the engine
transition.

The inherited development correction found the exact low-fence outcome, but it
still had two defects:

1. `getVariable("ClimbFenceOutcome")` returns an animation-variable slot, so
   comparing it directly with the string `"fall"` cannot succeed in-game.
2. It omitted both current sheet-rope state paths.

The API verifier initially misclassified `getVariableBoolean` as missing because
it did not index default methods inherited through Java interfaces. Commit
`aa8456f` corrected that tool defect and proved the method is inherited through
`IAnimationVariableMap` and `IAnimationVariableSource`.

## Current low-fence trace

1. `ClimbOverFenceState.enter` sets `ClimbingFence`, initializes
   `ClimbFenceOutcome`, and writes the stochastic vault failure as exact value
   `fall`.
2. `IsoPlayer.updateInternal2` fires `OnPlayerUpdate` before `IsoPlayer` calls
   `super.update`, so the trait handler runs before the state execution that
   consumes the outcome.
3. The active-only UTCore dispatcher calls the handler only for a player with
   this trait.
4. The handler uses the engine's own boolean and string comparison surfaces:
   `getVariableBoolean("ClimbingFence")` and
   `isVariable("ClimbFenceOutcome", "fall")`.
5. It replaces only that exact outcome with `success`.
6. `ClimbOverFenceState.execute` therefore does not call `setbFalling(true)`,
   its exit does not disable sprinting for a fall, and its fall animation event
   does not run.

The separate values `falling`, `rope`, `obstacle`, `lunge`, and `success` stay
on their vanilla paths.

## Current sheet-rope trace

1. `ClimbSheetRopeState` and `ClimbDownSheetRopeState` set `ClimbRope`, create
   climb data, and accumulate `climbRopeTime`.
2. Each state computes a fall threshold from the character's climbing failure
   chance and checks the accumulated timer before attempting its random roll.
3. `OnPlayerUpdate` runs before state execution on every player update.
4. While `isClimbingRope()` is true, the active trait handler resets
   `climbRopeTime` to zero.
5. State execution adds only the current-frame increment, which cannot cross
   the minimum threshold, so the stochastic `fallFromRope()` branch is not
   reached.
6. Both states independently test whether a sheet rope still exists before the
   random branch. That forced missing-rope fall remains unchanged.

This uses the current public `isClimbingRope` and `setClimbRopeTime` methods. It
does not replace a Java state method, patch a global sandbox option, create a
fake event, or alter another player's state.

## Lifecycle and performance

The trait owns one light handler in the central active-only tick dispatcher.
Every-update cadence is required because the fence outcome and rope timer must
be changed before the Java state executes. Work is bounded to constant method
checks and calls, and runs only while the player has the trait. There are no
object scans, inventory scans, timers outside the existing climb timer,
background tasks, or additional event registrations.

Trait activation and removal follow the existing `OnCreatePlayer` active-array
rebuild. The handler owns no persisted modData and requires no save migration.

## Regression evidence

The focused filter initially produced 3 passed and 2 failed:

- the fence test failed when the mock rejected the invalid slot-to-string API;
- the intact-rope timer remained at 900 instead of being reset.

After correction, all 5 focused cases pass in 0.055 seconds. They prove the
exact fence outcome conversion, slot-safe string comparison, intact-rope timer
reset, off-rope and no-trait controls, preservation of every other fence
outcome, preservation of ordinary falling state, and trait gating.

The complete UniversalTraits standard-Lua suite passes 512 tests. The current
API verifier reports 886 calls, 305 unique API patterns, zero warnings, and zero
missing methods. Runtime and English source and `42.0` release pairs are
byte-identical. Read-only package verification reports no release drift and
retains only the separate `missing-source:poster.png` issue.

## Remaining runtime proof

- User decision on whether a physically removed rope must also be fall-proof
- Current-build Kahlua execution after a full desktop relaunch
- Live running and sprinting low-fence failures under conditions that normally
  produce the stochastic `fall` outcome
- Live upward and downward intact-rope climbs under poor climbing conditions
- Control observations for unsupported-floor fences, removed ropes, and
  ordinary falls
- New game, save load, death, and repeated world entry
- Interaction with other movement traits in the target playset
- Rendered English, balance telemetry, and profiler capture

These are exact runtime evidence requirements. The missing-rope decision is a
semantic question; the other items are not unresolved static defects.
