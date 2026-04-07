# I001: Walk To vs Keyboard Frame Trace Plan

**Purpose:** close the final gap without jumping into a fix.  
**Open question:** what exact frame sequence allows right-click `Walk To` to make net progress while manual keyboard movement is pinned by `UTCore_SpeedHook`?

## Why This Is the Right Next Step

Source analysis has already established:

- UT Core's `setX()` / `setY()` clobber current-frame pending movement in `OnPlayerMove`.
- `Walk To` is a persistent pathfinding timed action, not synthetic keyboard input.
- The timed-action queue does **not** provide a secret second movement pass after world update.

The remaining unknown is now too frame-specific for more broad source search. It needs a short live trace.

## Test Matrix

Use the same failing save-backed character with `UT_fast` active.

### Test A: Keyboard only

1. Stand on open ground.
2. Hold a movement key for 2-3 seconds.
3. Capture log lines only for that window.

### Test B: Right-click Walk To

1. Same character, same area.
2. Right-click `Walk To` a short distance on open ground.
3. Capture log lines only for that window.

### Optional Test C: New character with UT enabled but no speed traits

This is still useful to separate "SpeedHook alone" from any second contributor, but it is not required to answer the Walk To nuance.

## Minimal Instrumentation Points

### 1. Log inside `UTCore_SpeedHook` at `OnPlayerMove`

Add temporary debug logging immediately before and after the `setX()` / `setY()` rewrite.

**Fields to log here:**

- `player:getX()` / `player:getY()`
- `player:getNextX()` / `player:getNextY()`
- `md["UT_prevX"]` / `md["UT_prevY"]`
- `md["UT_speedMod"]`
- computed `dx` / `dy`
- `player:isJustMoved()`
- `player:hasPath()`
- `player:pressedMovement(false)`
- `player:getPathFindBehavior2():shouldBeMoving()` when `hasPath()` is true

**Verified Lua-safe fields:**

- `getNextX()` / `getNextY()` are used from Lua in HorseMod.
- `isJustMoved()` is used from Lua in base game / mods.
- `pressedMovement(false)` is used from Lua in `WalkToTimedAction.lua` and `ISPathFindAction.lua`.
- `hasPath()` is used from Lua in Workshop mods.
- `getPathFindBehavior2()` is used throughout base-game Lua timed actions.

### 2. Add a temporary `OnPlayerUpdate` logger in UT debug code

This should log the same player state before the later local-player movement block fully settles for the next cycle.

**Goal:** confirm whether pathing re-primes `justMoved` / movement state across frames in a way keyboard movement does not.

### 3. Wrap `ISWalkToTimedAction:update()` or `ISPathFindAction:update()` in a temporary debug shim

Do **not** edit the decompiled base-game files directly. Instead, use a temporary UT-side monkeypatch/debug shim that logs:

- action type (`WalkToTimedAction`, `WalkToTimedActionF`, `ISPathFindAction`)
- `result` from `getPathFindBehavior2():update()`
- `character:hasPath()`
- `character:isJustMoved()`
- `character:pressedMovement(false)`
- `character:getPathFindBehavior2():shouldBeMoving()`

**Do not rely on** `isCurrentActionPathfinding()` in the first pass. It is source-proven on the Java side, but I did not find an existing Lua call site for it during this research pass.

## Expected Signatures

### If the current best model is correct

**Keyboard test should show:**

- `OnPlayerMove` fires repeatedly with `pressedMovement(false)=true`
- `UT_prevX ~= nil`
- `getX()` stays pinned or nearly pinned
- `getNextX()` differs before rewrite and is flattened by the hook
- `dx` trends toward `0` because `UT_prevX` keeps getting updated to the pinned position

**Walk To test should show:**

- `pressedMovement(false)=false`
- `hasPath()=true` during active pathing
- pathfinding action logs continue even without manual input
- some frame-to-frame pattern where `isJustMoved()` / `shouldBeMoving()` are re-established even though the current `OnPlayerMove` cycle already ran

### What would falsify the current best model

- `Walk To` logs look indistinguishable from keyboard logs and still produce net movement anyway.
- `hasPath()` / `shouldBeMoving()` are not materially different during the surviving movement window.
- `getNextX()` is already zeroed before the UT hook during `Walk To` frames.

## Logging Hygiene

- Prefix every line with a fixed tag, for example `UTDBG_MOV`.
- Keep logs to a short manual test window.
- Gate all logging behind a single temporary boolean such as `UT_DEBUG_MOVEMENT_TRACE`.
- Remove or disable the trace after the comparison run.

## Decision Rule After Logging

If the trace confirms the current model, we can move into fix design with much higher confidence and evaluate replacement strategies against the **broader movement-library conflict class**, not just the current debug loadout.

If the trace contradicts the model, the logs should be rich enough to point to the exact frame/state transition that source reading alone missed.