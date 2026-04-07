# P003: setX() Overwrites nextX and scriptNextX

**Proven on:** 2026-04-06  
**Proven by:** Source code inspection  
**Source:** `PZCodebase/Java/source/zombie/iso/IsoMovingObject.java:473-478`

## Code

```java
public float setX(float x) {
    this.x = x;
    this.setNextX(x);
    this.setScriptNextX(x);
    return this.x;
}
```

Compare with `setForceX()` (line 480-485) which additionally resets `lastX`:
```java
public void setForceX(float x) {
    this.setX(x);
    this.setNextX(x);
    this.setLastX(x);
    this.setScriptNextX(x);
}
```

## Fact

Calling `player:setX(value)` from Lua sets THREE internal fields to the same value:
- `this.x` (current position)
- `nextX` (next-frame target position)
- `scriptNextX` (script-layer position)

## Implication

Any Lua code that calls `setX()`/`setY()` to reposition a player is NOT just setting the current position — it is also clobbering the engine's next-frame position targets. This makes `setX()`/`setY()` a dangerous call during movement processing.

## Independent Corroboration

TchernoLib's SpeedFramework author independently discovered this and documented it:
```
-- it seems when I force x (or y or z), I kill something:
-- probably because it forces nx / scriptnx, see IsoMovingObject:setX(float var1)
-- because next update is always 0 (it should not)
```
Source: `C:/Steam/steamapps/workshop/content/108600/2986578314/mods/TchernoLib/media/lua/shared/Movement/SpeedFramework.lua:33`

## What This Does NOT Prove

- It does NOT prove that overwriting nextX directly breaks animation-driven deferred movement.
  `IsoGameCharacter.java:1321` shows deferred movement comes from `animPlayer.getDeferredMovement()`,
  not from a visible `nextX - x` calculation in the code inspected so far.
- The connection between `nextX` clobbering and broken keyboard movement is a hypothesis, not a proof.
  See hypothesis H001.
