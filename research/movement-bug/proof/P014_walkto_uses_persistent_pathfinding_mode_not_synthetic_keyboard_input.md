# P014: Walk To Uses Persistent Pathfinding Mode, Not Synthetic Keyboard Input

**Status:** PROVEN PARTIAL MODEL  
**Question answered:** Is right-click `Walk To` just another route into the same manual movement path?  
**Answer:** No. Source proves `Walk To` runs as a persistent pathfinding timed action with distinct engine state. It is not merely faking held keyboard input.

## What Is Proven

### 1. `Walk To` actions mark themselves as pathfinding timed actions

`ISWalkToTimedAction:start()`:

```lua
self.action:setPathfinding(true);
self.action:setAllowedWhileDraggingCorpses(true);
self.character:getPathFindBehavior2():pathToLocation(...)
```

`ISWalkToTimedAction:update()`:

```lua
self.result = self.character:getPathFindBehavior2():update();
```

It also explicitly ignores normal timed-action walk/run cancellation:

```lua
o.stopOnWalk = false;
o.stopOnRun = false;
o.maxTime = -1;
```

Source:

- `PZCodebase/Lua/client/TimedActions/WalkToTimedAction.lua`
- `PZCodebase/Lua/client/TimedActions/WalkToTimedActionF.lua`
- `PZCodebase/Lua/client/Vehicles/TimedActions/ISPathFindAction.lua`

### 2. The pathfinding flag is a real engine-side state bit

`BaseAction` stores the pathfinding flag:

```java
public void setPathfinding(boolean b) {
    this.pathfinding = b;
}

public boolean isPathfinding() {
    return this.pathfinding;
}
```

`IsoGameCharacter` exposes that on the current action:

```java
public boolean isCurrentActionPathfinding() {
    return this.checkCurrentAction(BaseAction::isPathfinding);
}
```

Source:

- `PZCodebase/Java/source/zombie/characters/CharacterTimedActions/BaseAction.java:199-203`
- `PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:3134-3148`

### 3. Local-player code separately promotes pathing into movement state

After the current `OnPlayerMove` cycle, local-player code resets `justMoved`, processes input, then sets `justMoved` back to true if the character has a path and `PathFindBehavior2.shouldBeMoving()`:

```java
this.setJustMoved(false);
this.updateMovementFromInput(moveVars);
if (!this.justMoved && this.hasPath() && this.getPathFindBehavior2().shouldBeMoving()) {
    this.setJustMoved(true);
}
```

Later in the same block it also treats pathfinding as active movement for player state:

```java
this.isPlayerMoving = this.isJustMoved() || this.hasPath() && this.getPathFindBehavior2().shouldBeMoving();
```

Source:

- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2368-2375`
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2646`

### 4. `OnPlayerMove` occurs earlier in the update cycle than that local re-priming block

In `IsoPlayer.updateInternal2()`, the engine does deferred movement, then triggers `OnPlayerMove`, and only later enters the large local-player input/path block that can re-set `justMoved` from `hasPath()`:

```java
this.doDeferredMovement();
...
if (this.isJustMoved() && !this.isNpc) {
    LuaEventManager.triggerEvent("OnPlayerMove", this);
}
```

Later in the same method:

```java
this.setJustMoved(false);
this.updateMovementFromInput(moveVars);
if (!this.justMoved && this.hasPath() && this.getPathFindBehavior2().shouldBeMoving()) {
    this.setJustMoved(true);
}
```

Source:

- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2076-2167`
- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2358-2375`

### 5. The timed-action queue does NOT provide a second post-update movement pass

`ISTimedActionQueue.onTick` runs on global `OnTick`, and its `tick()` only checks for stalled actions / queue completion. It does **not** call the action's `update()` method.

```lua
function ISTimedActionQueue:tick()
    local action = self.queue[1]
    ...
    if action.action:hasStalled() then
        self:onCompleted(action)
        return
    end
end

Events.OnTick.Add(ISTimedActionQueue.onTick);
```

The actual timed-action `update()` runs from the Java character-action update path:

```java
else if (valid && !act.finished() && !act.forceComplete && !act.forceStop) {
    act.update();
}
```

Source:

- `PZCodebase/Lua/client/TimedActions/ISTimedActionQueue.lua:101-115, 297`
- `PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:9691-9700`

## What This Means

This proves three important things:

1. `Walk To` is a distinct pathfinding action mode, not just keyboard input by another name.
2. The engine re-primes movement state from `hasPath()` / `shouldBeMoving()` after the current `OnPlayerMove` cycle.
3. The earlier theory that the timed-action queue gives pathing a second movement-producing pass after world update is false.

## What Is Still NOT Proven

This file does **not** prove the full final reason `Walk To` survives in live play.

The remaining unresolved step is:

- identify the exact frame-to-frame sequence that turns this persistent pathfinding state into net world-space progress despite the confirmed UT `setX()` / `setY()` clobber.

Most likely current explanation:

- pathfinding is continuously re-established as an engine movement mode across frames, while manual input is more directly exposed to the position-pinning loop.

That is now a strong source-backed model, but it still needs live instrumentation or a tighter frame-by-frame proof before it should be promoted to a fully closed explanation.