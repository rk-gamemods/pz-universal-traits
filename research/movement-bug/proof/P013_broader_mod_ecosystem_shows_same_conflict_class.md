# P013: Broader Mod Ecosystem Shows the Same Conflict Class

**Status:** PROVEN from local source scan  
**Question answered:** Are we overfitting the analysis to the current trimmed test loadout?  
**Answer:** No. The current active list is valid for reproduction, but the compatibility boundary is broader: multiple installed mods and libraries use the same general pattern of per-frame movement scaling plus absolute position rewrite.

## Claim

The dangerous pattern is **not** "any mod that ever calls `setX()`".

The dangerous pattern is:

1. Run every frame or movement tick (`OnPlayerMove`, `OnPlayerUpdate`, or equivalent)
2. Read current or previous player position to derive a delta
3. Apply a speed modifier or correction
4. Write the result back with `setX()` / `setY()`

That is the same family of logic used by UT Core and TchernoLib, and it already appears in other installed mods.

## Search Scope

Scanned local mod roots, not just the currently active save loadout:

- `C:\Users\Admin\Zomboid\mods`
- `C:\Steam\steamapps\workshop\content\108600`

Search terms included:

- `SetPlayerSpeed(`
- `WalkSpeedTuning.activate(`
- `OnPlayerMove.Add`
- `OnPlayerUpdate.Add`
- `player:setX(` / `player:setY(`
- `setNextX(` / `setNextY(`

## Hard Receipts

### 1. UT Core uses the conflict pattern in the failing case

`UTCore_SpeedHook.lua` computes a delta from previous position, scales it, then rewrites absolute position during `OnPlayerMove`:

```lua
local dx = newX - prevX
local dy = newY - prevY
...
local newPosX = prevX + dx * factor
local newPosY = prevY + dy * factor
player:setX(newPosX)
player:setY(newPosY)
```

Source:

- `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua`
- `player:setX(newPosX)` / `player:setY(newPosY)`
- event registration: `Events.OnPlayerMove.Add(onPlayerMove)`

### 2. TchernoLib is one instance of the same pattern, but still not proven active

`WalkSpeedTuningHook.lua` registers a movement hook:

```lua
if doActivate then
    Events.OnPlayerMove.Add(WalkSpeedTuning.update)
end
```

`SpeedFramework.lua` applies scaled movement by rewriting absolute position:

```lua
player:setX(player:getX()+deltaX);
player:setY(player:getY()+deltaY);
```

Source:

- `2986578314/mods/TchernoLib/media/lua/shared/Movement/WalkSpeedTuningHook.lua:5-9`
- `2986578314/mods/TchernoLib/media/lua/shared/Movement/SpeedFramework.lua:45-46`

**Important limit:** a full scan for `SetPlayerSpeed(` and `WalkSpeedTuning.activate(` across installed mods found only the TchernoLib definitions, not external consumers. So TchernoLib remains a structural risk, not a proven active participant.

### 3. Lifestyle contains an active non-UT example of the same family

`LSWanderer.lua` turns the helper on:

```lua
local LSMovUtil = require('Helper/MovementUtil')
LSMovUtil.setRunning(true)
```

`MovementUtil.lua` then hooks `OnPlayerUpdate`, derives movement from last position, and rewrites absolute position:

```lua
local dx, dy = LSMovUtil.getMovDeltas(player, lastPos, movSpeedMod)
if LSMovUtil.hasMov(dx, dy) and LSMovUtil.canDoMov(player, dx, dy) then
    player:setX(player:getX() + dx)
    player:setY(player:getY() + dy)
end
```

The same helper explicitly changes behavior when pathfinding is active:

```lua
local deltaX, deltaY, multiplier = player:getX() - lastPos.x, player:getY() - lastPos.y,
    (LSMovUtil.isPathfinding(player) and (movSpeedMod - 1)) or ((movSpeedMod - 1) * 2 + 1)
```

Source:

- `3009257662/mods/Lifestyle/media/lua/client/ISAmbt/LSWanderer.lua:28-30`
- `3009257662/mods/Lifestyle/media/lua/client/Helper/MovementUtil.lua:44, 74, 82`

### 4. More Traits contains the same design, but its installed B42 file has the relevant hooks commented out

The Build 42 file still contains `fast()` / `gimp()` logic that computes delta from prior position and rewrites `setX()` / `setY()`:

```lua
player:setX((oldx + xdif * modifier));
player:setY((oldy + ydif * modifier));
```

But the corresponding event registrations are commented in the installed B42 file:

```lua
--Events.OnPlayerMove.Add(gimp);
--Events.OnPlayerMove.Add(fast);
```

Source:

- `1299328280/mods/More Traits/42/media/lua/client/MoreTraits .lua:2390-2420`
- `1299328280/mods/More Traits/42/media/lua/client/MoreTraits .lua:4599-4600`

This is still useful evidence because it shows the pattern is not unique to UT or TchernoLib.

### 5. One-shot reposition systems are a different class and should not be conflated with this bug

Example: Aquatsar Yacht Club uses `OnPlayerMove` for swim stamina effects, but its direct `setX()` / `setY()` fast-swim jump is bound to key input, not the movement event itself:

```lua
Events.OnPlayerMove.Add(AquatsarYachts.Swim.OnPlayerMove)
Events.OnKeyStartPressed.Add(fastSwim)
```

The actual position write is in the key handler:

```lua
player:setX(x)
player:setY(y)
```

Source:

- `2392987599/mods/AquatsarYachtClub/media/lua/client/Swim/AquaSwim.lua:172-173`
- `2392987599/mods/AquatsarYachtClub/media/lua/client/Swim/AquaSwim.lua:268-269`

This is a useful contrast case: not every `setX()` call implies the same frame-clobber risk.

## Conclusion

The current trimmed active list is enough to prove the UT root cause, but it is **not** the right design boundary for the fix.

The real compatibility boundary is broader:

- Any system that **continuously** modifies movement by deriving deltas from live position and then writing back through `setX()` / `setY()` is in the same hazard class.
- TchernoLib is only one member of that class.
- A robust UT fix should remove absolute position rewriting entirely so it cannot collide with future mod stacks that use similar movement hooks.