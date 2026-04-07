# P012: Frame Order Proves x Is Stale During OnPlayerMove

**Proven on:** 2026-04-06  
**Proven by:** Java source inspection  
**Confidence:** Absolute

## The Question

P011 depended on one critical assumption:

- when `OnPlayerMove` fires inside `IsoPlayer.update()`, does `player:getX()` still return the
  pre-reconciliation position while the current frame's movement is sitting in `nextX`?

This proof answers **yes**.

## Evidence Chain

### Step 1: Scheduler order is `preupdate()` -> `update()` -> `postupdate()`

`MovingObjectUpdateSchedulerUpdateBucket.java:40-56`:

```java
isoMovingObject.preupdate();
isoMovingObject.update();
```

`MovingObjectUpdateScheduler.java:153-168`:

```java
public void update() {
    this.fullSimulation.update((int)this.frameCounter);
    ...
}

public void postupdate() {
    this.fullSimulation.postupdate((int)this.frameCounter);
    ...
}
```

`IsoWorld.java:2880-2886`:

```java
this.currentCell.update();
...
MovingObjectUpdateScheduler.instance.postupdate();
```

## Fact

Normal moving objects are processed in this order:

1. `preupdate()`
2. `update()`
3. `postupdate()`

So anything that happens inside `IsoPlayer.update()` occurs **before** `postupdate()` reconciles
`x` toward `nextX`.

### Step 2: `preupdate()` resets `nextX` to current `x`

`IsoMovingObject.java:1068-1071`:

```java
public void preupdate() {
    this.setNextX(this.getX());
    this.setNextY(this.getY());
    this.updateAnimationRecorder();
}
```

## Fact

At the start of the frame, `nextX` is reset to equal `x`.

### Step 3: Deferred movement adds into `nextX` during `update()`

`IsoGameCharacter.java:1686`:

```java
this.MoveUnmodded(dMovement);
```

`IsoMovingObject.java:584-588`:

```java
protected final void moveUnmoddedInternal(float dirx, float diry) {
    this.setNextX(this.getNextX() + dirx);
    this.setNextY(this.getNextY() + diry);
    this.reqMovement.x = dirx;
    this.reqMovement.y = diry;
}
```

## Fact

During `update()`, deferred movement is accumulated into `nextX` and `nextY`.
At this point, the current frame's movement exists in `nextX`, not in `x`.

### Step 4: `OnPlayerMove` fires inside `update()`, before `postupdate()`

`IsoPlayer.java:2076`:

```java
this.doDeferredMovement();
```

`IsoPlayer.java:2158-2166`:

```java
if (this.isJustMoved() && !this.isNpc) {
    ...
    LuaEventManager.triggerEvent("OnPlayerMove", this);
}
```

## Fact

`OnPlayerMove` runs during `IsoPlayer.update()` after deferred movement has already been written
into `nextX`, but before `postupdate()` applies the `nextX - x` delta back into `x`.

### Step 5: `postupdate()` is where normal movement reconciles `x` toward `nextX`

`IsoMovingObject.java:977-991`:

```java
float dx = this.getNextX() - this.getX();
float dy = this.getNextY() - this.getY();
...
this.setX(this.getX() + dx);
this.setY(this.getY() + dy);
...
this.setScriptNextX(this.getNextX());
this.setScriptNextY(this.getNextY());
```

## Fact

Normal non-ragdoll movement is committed from `nextX` into `x` during `postupdate()`, not earlier.

## Conclusion

During `OnPlayerMove` in the normal player movement pipeline:

- `x` still represents the current position from before postupdate reconciliation
- `nextX` already contains the current frame's animation/deferred movement

Therefore, reading `player:getX()` inside `UTCore_SpeedHook` does indeed read a stale,
pre-reconciliation position relative to the pending movement stored in `nextX`.

This closes the main proof gap from R001 and upgrades P011 from a plausible mechanism to a
fully source-backed one.