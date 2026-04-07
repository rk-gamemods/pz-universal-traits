# P011: SpeedHook Clobbers Current-Frame Deferred Movement by Rewriting x and nextX

**Proven on:** 2026-04-06  
**Proven by:** Java source analysis  
**Confidence:** Absolute

## The Discovery

Normal player movement is staged across frame phases:

- `preupdate()` resets `nextX = x`
- `doDeferredMovement()` adds the current frame's movement into `nextX`
- `OnPlayerMove` fires before `postupdate()`
- `postupdate()` later applies `dx = nextX - x` back into `x`

SpeedHook runs in the middle of that pipeline and calls `setX()` / `setY()`, which forces
`x = nextX = scriptNextX`. That wipes out the current frame's pending movement before
`postupdate()` can commit it.

## Evidence Chain

### Step 1: `doDeferredMovement()` calls `MoveUnmodded()`

`IsoGameCharacter.java:1686`:
```java
this.MoveUnmodded(dMovement);
```

Where `dMovement` is from `animPlayer.getDeferredMovement()` — the animation system's position delta.

### Step 2: `MoveUnmodded()` writes to `nextX` additively

`IsoMovingObject.java:585-588`:
```java
protected final void moveUnmoddedInternal(float dirx, float diry) {
    this.setNextX(this.getNextX() + dirx);  // ADDITIVE — accumulates into nextX
    this.setNextY(this.getNextY() + diry);
    this.reqMovement.x = dirx;
    this.reqMovement.y = diry;
}
```

**Key:** After this runs, the current frame's pending movement exists in `nextX`, not yet in `x`.
See P012 for the frame-order proof.

### Step 3: `setX()` collapses `nextX` back to `x`

`IsoMovingObject.java:473-478`:
```java
public float setX(float x) {
    this.x = x;
    this.setNextX(x);       // CLOBBERS the accumulated nextX
    this.setScriptNextX(x); // Also clobbers scriptNextX
    return this.x;
}
```

**Key:** `setX(newPos)` sets `x = nextX = scriptNextX = newPos`. Any pending delta
in `nextX` that was written by `moveUnmoddedInternal` is DESTROYED.

## Execution Order (Single Player, Local)

From `IsoPlayer.java`:

1. `preupdate()` has already reset `nextX = x` for the frame
2. **Line 2076:** `this.doDeferredMovement()` writes `nextX += delta`
3. **Line 2166:** `OnPlayerMove` fires during `update()`
4. **SpeedHook runs:** computes delta from `player:getX()` and calls `setX()` / `setY()`
5. `setX()` forces `nextX = x = newPos`
6. Later `postupdate()` sees `dx = nextX - x = 0` and has no deferred movement left to apply

The frame ordering in steps 1 and 6 is proven separately in P012.

## The SpeedHook's Specific Error

The SpeedHook does:
```lua
local dx = player:getX() - prevX
local newPosX = prevX + dx * factor  -- factor = 1.3
player:setX(newPosX)
```

At the moment the SpeedHook reads `getX()`, the value is still the pre-postupdate position for
the current frame, while the current frame's movement is sitting in `nextX`. So `dx` is derived
from stale position state, not from the not-yet-committed deferred movement delta.

Then `setX(newPosX)` forces `nextX = newPosX`, destroying whatever `doDeferredMovement` put there.

**The net effect:** the current frame's pending movement is discarded before postupdate can apply it.

## Why This Explains "Stuck" Movement

If `getX()` matches `prevX`, then `dx = 0`, and `setX(prevX + 0 * 1.3) = setX(prevX)` — the player
doesn't move and the pending current-frame `nextX` delta is destroyed.

**This is a position-pinning feedback loop:**
1. Animation writes to nextX
2. SpeedHook reads x (unchanged), gets dx=0
3. SpeedHook calls setX(prevX), which sets nextX=prevX
4. The nextX delta from animation is destroyed
5. Next frame: x still hasn't changed, prevX still equals x → repeat

## Walk To Gap — Working Hypothesis

`doDeferredMovement` has special handling for `WalkTowardState` (IsoGameCharacter.java:1629-1641):
```java
if (this.isCurrentState(WalkTowardState.instance())) {
    Vector2 targetVec = ...;
    targetVec.x = this.getPathFindBehavior2().getTargetX() - this.getX();
    targetVec.y = this.getPathFindBehavior2().getTargetY() - this.getY();
    if (targetVec.getLengthSquared() < dMovement.getLengthSquared()) {
        dMovement.setLength(targetVec.getLength());
    }
}
```

Additionally, the pathfinding system may have position correction mechanisms that run
AFTER OnPlayerMove, re-establishing the correct position. This needs further investigation.

**The justMoved flag for pathfinding is set AFTER updateMovementFromInput (line 2373-2374),
while keyboard justMoved is set inside updateMovementFromKeyboardMouse (line 3051).**
Both fire OnPlayerMove at line 2166. But the pathfinding system's ongoing state machine
may apply additional corrections that keyboard input does not.

## Status

- The **keyboard movement kill mechanism** is now proven from source.
- The exact reason Walk To survives is still only partially explained.
- This confirms H001 for the current failing character and leaves only the pathfinding-survival
    behavior as follow-up research.

## Implication for Fix

The SpeedHook should NOT use `setX()`/`setY()`. Instead it should either:
1. Modify the animation delta before it's applied (pre-movement hook)
2. Write to `nextX`/`nextY` directly (additive, not absolute)
3. Use a game-sanctioned speed modifier API if one exists

The TchernoLib author's comment that setX "kills something" is now explained — it kills
the pending deferred movement delta stored in nextX.
