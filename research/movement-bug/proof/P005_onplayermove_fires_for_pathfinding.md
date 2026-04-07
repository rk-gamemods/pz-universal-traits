# P005: OnPlayerMove Fires for BOTH Keyboard and Pathfinding Movement

**Proven on:** 2026-04-06  
**Proven by:** Source code inspection + code review agent  
**Source:** `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2370-2374`

## Code (IsoPlayer.java:2370-2374)

```java
this.updateMovementFromInput(moveVars);
if (!this.justMoved && this.hasPath() && this.getPathFindBehavior2().shouldBeMoving()) {
    this.setJustMoved(true);
}
```

And at IsoPlayer.java:2158-2167:
```java
if (this.isJustMoved() && !this.isNpc) {
    if (!this.isRunning() && !this.isSprinting()) {
        d = 1.0F;
    } else {
        d = 1.5F;
    }
    if (!GameClient.client && !GameServer.server) {
        LuaEventManager.triggerEvent("OnPlayerMove", this);
    }
}
```

## Fact

`justMoved` is set to `true` when:
- Keyboard input produces movement (inside `updateMovementFromInput`), OR
- The player has an active pathfinding path AND `shouldBeMoving()` is true (line 2372-2374)

`OnPlayerMove` fires whenever `isJustMoved()` is true (line 2158+2166).

## Implication

**OnPlayerMove fires for Walk To pathfinding movement too.**

This REFUTES the earlier hypothesis that "Walk To works because OnPlayerMove doesn't fire for it."
The SpeedHook's setX/setY calls execute during Walk To movement as well.

## Consequence

If the SpeedHook is the cause of the bug, we need a DIFFERENT explanation for why Walk To
still works. Possible explanations:
1. The pathfinding system overwrites position after OnPlayerMove in a way keyboard movement doesn't
2. The pathfinding system is resilient to nextX clobbering in a way keyboard movement isn't
3. Something else in the update loop differs between the two paths

This is now the biggest open question in the investigation.
