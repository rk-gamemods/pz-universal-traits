# H001: SpeedHook's setX/setY Disrupts Engine Movement State

**Status:** CONFIRMED as the primary cause on the failing character; pathfinding-survival details still open  
**Probability:** Confirmed  
**Depends on:** P003, P004, P005, P010, P011, P012

## Hypothesis

UTCore_SpeedHook.lua calls `player:setX()` and `player:setY()` inside the `OnPlayerMove`
event whenever `UT_speedMod != 0`. Per P003, `setX()` overwrites `x`, `nextX`, and
`scriptNextX` to the same value. P011 and P012 now show that this happens after deferred
movement has been accumulated into `nextX` during `update()`, but before `postupdate()`
reconciles `nextX` back into `x`. The hook therefore destroys the current frame's pending
movement on the failing character.

## What Supports This

1. **P001:** Disabling UT removes the bug while other mods remain.
2. **P003:** `setX()` clobbers nextX/scriptNextX.
3. **P004:** SpeedHook calls setX/setY when speedMod != 0.
4. **P010:** The failing character has `UT_fast`, so `UT_speedMod = 0.3` and the SpeedHook is active.
5. **P011:** SpeedHook clobbers the current frame's deferred movement by rewriting x and nextX.
6. **P012:** Frame order proves `OnPlayerMove` runs before `postupdate()` reconciles `nextX` into `x`.
7. **TchernoLib corroboration:** independent comment that setX-based rewriting "kills something."

## What Does NOT Support This

1. **P005:** OnPlayerMove fires for pathfinding too, so the hook does run there.
2. **P002:** Walk To still works in live testing.

These do **not** refute the root cause. They mean only that pathfinding has some later-stage
correction or resilience that direct keyboard movement does not. The remaining open problem is
why pathfinding survives, not whether the hook is dangerous.

## What Would Strengthen Confidence Further

- Live instrumentation showing `UT_speedMod`, `x`, `nextX`, and the SpeedHook write each frame.
- A new-character test with UT enabled but no speed traits selected.

These are no longer required to establish the current root cause, but they would tighten the
behavioral model and help validate a replacement design.

## Possible Explanations for the Walk To Gap

These are sub-hypotheses, each requiring further investigation:

### H001a: Pathfinding overwrites position AFTER OnPlayerMove
If the pathfinding system sets position via a different mechanism later in the frame,
it could overwrite the SpeedHook's damage. Keyboard movement may not have such a
late-stage overwrite.

### H001b: Pathfinding uses a state machine path that handles nextX differently
WalkTowardState may apply movement through a code path that recalculates from
animPlayer state rather than relying on nextX. Keyboard idle/walk state may be
more sensitive to nextX clobbering.

### H001c: Pathfinding has a corrective stage that keyboard movement lacks
Pathfinding may survive because `WalkTowardState` and related path-following logic continue to
correct or re-establish motion after the hook runs, while direct keyboard movement relies on the
current-frame deferred movement that the hook destroys.
