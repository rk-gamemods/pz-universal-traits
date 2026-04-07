# P004: UTCore_SpeedHook Calls setX/setY on OnPlayerMove

**Proven on:** 2026-04-06  
**Proven by:** Source code inspection  
**Source:** `UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua:51-62`

## Code

```lua
if dx ~= 0 or dy ~= 0 then
    local factor = 1.0 + mod
    local newPosX = prevX + dx * factor
    local newPosY = prevY + dy * factor
    player:setX(newPosX)
    player:setY(newPosY)
    md["UT_prevX"] = newPosX
    md["UT_prevY"] = newPosY
else
    md["UT_prevX"] = newX
    md["UT_prevY"] = newY
end
```

## Fact

When `UT_speedMod ~= 0` (any speed-modifying trait is active), the SpeedHook:
1. Computes a movement delta from stored previous position
2. Multiplies by `(1.0 + UT_speedMod)` 
3. Calls `player:setX()` and `player:setY()` to reposition the player

This fires inside `Events.OnPlayerMove`, which triggers at `IsoPlayer.java:2166`.

## Guard Conditions

The `setX()`/`setY()` calls are ONLY reached when:
- `mod ~= nil` AND `mod ~= 0` (line 26)
- `dx ~= 0` OR `dy ~= 0` (line 51)
- delta is within teleport guard of 5 tiles (line 45)

When `UT_speedMod == 0`, the function early-returns at line 26-29 without calling setX/setY.

## What Sets UT_speedMod

`UTCore_StatModifiers.lua:133` writes `md["UT_speedMod"] = speedMod` where `speedMod` is the
clamped sum of the speed bucket. Speed bucket entries are added by:
- `UTCore.applySpeedModifier(player, amount, sourceId)` — called by individual traits

Known traits that call applySpeedModifier:
- `UT_fast.lua:8` → `applySpeedModifier(player, 0.3, TRAIT_ID)`
- `UT_lurcher.lua:10` → `applySpeedModifier(player, -0.15, TRAIT_ID)`

## Critical Open Question

**Does the bug reproduce when no speed-modifying UT traits are selected?**
If yes → the SpeedHook is not the cause (it's a no-op when speedMod==0).
If no → the SpeedHook's setX/setY calls are the primary suspect.
