-- test_engine_contracts.lua
-- Engine Contract Verification Tests
--
-- PURPOSE: Detect ANY change in the PZ Java engine code that our SpeedHook
-- depends on. These tests parse the decompiled Java source and verify the
-- exact patterns, method signatures, and frame-pipeline order that make
-- our nextX/nextY delta-scaling approach safe.
--
-- If ANY of these tests fail after a PZ update, the SpeedHook MUST be
-- re-validated before deployment. A failure means the engine assumption
-- that our code relies on may have changed.
--
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" test/run_tests.lua
--
-- ==================== ENGINE DEPENDENCIES ====================
-- Our SpeedHook (UTCore_SpeedHook.lua) depends on these engine contracts:
--
-- 1. IsoMovingObject.setX() clobbers x, nextX, AND scriptNextX
--    → If this changes, setX() might become safe (and our fix unnecessary)
--
-- 2. IsoMovingObject.setNextX() ONLY sets nx (does NOT touch x or scriptNextX)
--    → If this changes, our fix might break something else
--
-- 3. IsoMovingObject.preupdate() resets nextX = x at frame start
--    → Our delta reading (nextX - x) depends on this reset
--
-- 4. IsoMovingObject.moveUnmoddedInternal() writes additively to nextX
--    → Deferred movement accumulates in nextX during update()
--
-- 5. Frame order: preupdate() → update() → postupdate()
--    → OnPlayerMove fires during update(), before postupdate()
--
-- 6. IsoPlayer.updateInternal2() fires OnPlayerMove AFTER doDeferredMovement
--    → Our hook sees the animation delta in nextX when it runs
--
-- 7. IsoMovingObject.getNextX()/getNextY() are public (Lua-callable)
--    → Our hook must be able to read pending movement
-- =============================================================

-- Path to decompiled PZ Java source
local PZ_JAVA = "C:/Users/Admin/Documents/GIT/GameMods/PZMods/PZCodebase/Java/source/zombie/"

-- Helper: read entire file into string
local function readFile(path)
    local f = io.open(path, "r")
    if not f then
        error("ENGINE CONTRACT: Cannot open " .. path .. "\nIs the PZCodebase decompiled source present?")
    end
    local content = f:read("*a")
    f:close()
    return content
end

-- Helper: check if a plain string exists in file content (no Lua pattern matching)
local function assertContains(content, needle, msg)
    if not content:find(needle, 1, true) then
        error(msg .. "\nNeedle not found: " .. needle, 2)
    end
end

-- Helper: assert a plain string does NOT exist in content
local function assertNotContains(content, needle, msg)
    if content:find(needle, 1, true) then
        error(msg .. "\nUnexpected needle found: " .. needle, 2)
    end
end

-- Helper: extract a specific method body (simple heuristic: from method signature to next method or class end)
local function extractMethodBlock(content, methodSig)
    local start = content:find(methodSig, 1, true)
    if not start then return nil end
    -- Find the opening brace
    local braceStart = content:find("{", start)
    if not braceStart then return nil end
    -- Count braces to find matching close
    local depth = 1
    local pos = braceStart + 1
    while depth > 0 and pos <= #content do
        local ch = content:sub(pos, pos)
        if ch == "{" then depth = depth + 1
        elseif ch == "}" then depth = depth - 1 end
        pos = pos + 1
    end
    return content:sub(start, pos - 1)
end

-- =====================================================================
-- Load source files once (shared across all contract tests)
-- =====================================================================

local isoMovingObjectSrc = readFile(PZ_JAVA .. "iso/IsoMovingObject.java")
local isoPlayerSrc = readFile(PZ_JAVA .. "characters/IsoPlayer.java")
local isoGameCharSrc = readFile(PZ_JAVA .. "characters/IsoGameCharacter.java")

-- =====================================================================
-- CONTRACT 1: setX() clobbers nextX and scriptNextX
-- If this contract breaks, setX() might have become safe — but our
-- SpeedHook should still avoid it since the old behavior could return.
-- =====================================================================

test("ENGINE CONTRACT: setX() calls setNextX(x)", function()
    local setXBody = extractMethodBlock(isoMovingObjectSrc, "public float setX(float")
    assert(setXBody, "setX(float) method not found in IsoMovingObject.java")
    assertContains(setXBody, "this.setNextX(x)",
        "setX() must call setNextX(x) — this is what makes setX dangerous during movement")
end)

test("ENGINE CONTRACT: setX() calls setScriptNextX(x)", function()
    local setXBody = extractMethodBlock(isoMovingObjectSrc, "public float setX(float")
    assert(setXBody, "setX(float) method not found in IsoMovingObject.java")
    assertContains(setXBody, "this.setScriptNextX(x)",
        "setX() must call setScriptNextX(x) — triple-clobber behavior")
end)

-- =====================================================================
-- CONTRACT 2: setNextX() ONLY sets nx (does NOT touch x or scriptNextX)
-- This is the safe alternative our SpeedHook uses.
-- =====================================================================

test("ENGINE CONTRACT: setNextX() exists as a public method", function()
    assertContains(isoMovingObjectSrc, "public float setNextX(float",
        "setNextX must be public (Lua-callable)")
end)

test("ENGINE CONTRACT: setNextX() does NOT call setX()", function()
    local setNextXBody = extractMethodBlock(isoMovingObjectSrc, "public float setNextX(float")
    assert(setNextXBody, "setNextX(float) method not found")
    -- setNextX should NOT contain a call to setX — that would make it unsafe
    local hasSetX = setNextXBody:find("this.setX(", 1, true) or setNextXBody:find("this.x =", 1, true)
    assert(not hasSetX,
        "CRITICAL: setNextX() now writes to x! Our SpeedHook assumes it only writes to nx.\n" ..
        "Method body:\n" .. setNextXBody)
end)

test("ENGINE CONTRACT: setNextX() does NOT call setScriptNextX()", function()
    local setNextXBody = extractMethodBlock(isoMovingObjectSrc, "public float setNextX(float")
    assert(setNextXBody, "setNextX(float) method not found")
    local hasScriptNext = setNextXBody:find("this.setScriptNextX(", 1, true)
    assert(not hasScriptNext,
        "CRITICAL: setNextX() now writes to scriptNextX! This changes its safety profile.\n" ..
        "Method body:\n" .. setNextXBody)
end)

-- =====================================================================
-- CONTRACT 3: preupdate() resets nextX = x
-- Our delta reading (nextX - x) depends on this reset at frame start.
-- =====================================================================

test("ENGINE CONTRACT: preupdate() resets nextX from x", function()
    local preupdateBody = extractMethodBlock(isoMovingObjectSrc, "public void preupdate()")
    assert(preupdateBody, "preupdate() method not found in IsoMovingObject.java")
    assertContains(preupdateBody, "this.setNextX(this.getX())",
        "preupdate() must reset nextX to current x at frame start")
end)

test("ENGINE CONTRACT: preupdate() resets nextY from y", function()
    local preupdateBody = extractMethodBlock(isoMovingObjectSrc, "public void preupdate()")
    assert(preupdateBody, "preupdate() method not found in IsoMovingObject.java")
    assertContains(preupdateBody, "this.setNextY(this.getY())",
        "preupdate() must reset nextY to current y at frame start")
end)

-- =====================================================================
-- CONTRACT 4: moveUnmoddedInternal() writes additively to nextX
-- Deferred movement must be ADDITIVE into nextX, not a replacement.
-- =====================================================================

test("ENGINE CONTRACT: moveUnmoddedInternal() adds to nextX", function()
    local moveBody = extractMethodBlock(isoMovingObjectSrc, "protected final void moveUnmoddedInternal(")
    assert(moveBody, "moveUnmoddedInternal() not found in IsoMovingObject.java")
    assertContains(moveBody, "this.setNextX(this.getNextX() + dirx)",
        "moveUnmoddedInternal must ADDITIVELY accumulate into nextX")
end)

test("ENGINE CONTRACT: moveUnmoddedInternal() adds to nextY", function()
    local moveBody = extractMethodBlock(isoMovingObjectSrc, "protected final void moveUnmoddedInternal(")
    assert(moveBody, "moveUnmoddedInternal() not found in IsoMovingObject.java")
    assertContains(moveBody, "this.setNextY(this.getNextY() + diry)",
        "moveUnmoddedInternal must ADDITIVELY accumulate into nextY")
end)

-- =====================================================================
-- CONTRACT 5: getNextX()/getNextY() are public (Lua-callable)
-- =====================================================================

test("ENGINE CONTRACT: getNextX() is public", function()
    assertContains(isoMovingObjectSrc, "public float getNextX()",
        "getNextX must be public for Lua access")
end)

test("ENGINE CONTRACT: getNextY() is public", function()
    assertContains(isoMovingObjectSrc, "public float getNextY()",
        "getNextY must be public for Lua access")
end)

-- =====================================================================
-- CONTRACT 6: setNextY() is safe (same contract as setNextX for Y axis)
-- =====================================================================

test("ENGINE CONTRACT: setNextY() exists as a public method", function()
    assertContains(isoMovingObjectSrc, "public float setNextY(float",
        "setNextY must be public (Lua-callable)")
end)

test("ENGINE CONTRACT: setNextY() does NOT call setY()", function()
    local setNextYBody = extractMethodBlock(isoMovingObjectSrc, "public float setNextY(float")
    assert(setNextYBody, "setNextY(float) method not found")
    local hasSetY = setNextYBody:find("this.setY(", 1, true) or setNextYBody:find("this.y =", 1, true)
    assert(not hasSetY,
        "CRITICAL: setNextY() now writes to y! Our SpeedHook assumes it only writes to ny.\n" ..
        "Method body:\n" .. setNextYBody)
end)

-- =====================================================================
-- CONTRACT 7: IsoGameCharacter.doDeferredMovement() calls MoveUnmodded
-- This is where the animation delta is written into nextX via the
-- moveUnmoddedInternal chain.
-- =====================================================================

test("ENGINE CONTRACT: doDeferredMovement() calls MoveUnmodded", function()
    -- PZ svn-964 (2026-05) decompiles this as lowercase moveUnmodded; older builds emit MoveUnmodded.
    -- Either spelling is fine as long as the call chain into moveUnmoddedInternal is preserved.
    local hasCall = isoGameCharSrc:find("this.MoveUnmodded(", 1, true)
        or isoGameCharSrc:find("this.moveUnmodded(", 1, true)
    assert(hasCall,
        "doDeferredMovement must call moveUnmodded/MoveUnmodded to write animation delta into nextX")
end)

-- =====================================================================
-- CONTRACT 8: IsoPlayer fires OnPlayerMove during update
-- Our hook runs here — after doDeferredMovement, before postupdate.
-- =====================================================================

test("ENGINE CONTRACT: IsoPlayer fires OnPlayerMove event", function()
    assertContains(isoPlayerSrc, '"OnPlayerMove"',
        "IsoPlayer must fire the OnPlayerMove event that our SpeedHook listens on")
end)

test("ENGINE CONTRACT: OnPlayerMove fires with player as argument", function()
    -- The event trigger passes 'this' (the player) as argument via LuaEventManager
    assertContains(isoPlayerSrc, 'triggerEvent("OnPlayerMove", this)',
        "OnPlayerMove must pass the player as first argument")
end)

-- =====================================================================
-- CONTRACT 9: doDeferredMovement appears BEFORE OnPlayerMove in source
-- This proves the frame order: animation delta is in nextX when our hook runs.
-- Note: source ordering in a single method = execution ordering.
-- =====================================================================

test("ENGINE CONTRACT: doDeferredMovement() is called before OnPlayerMove in IsoPlayer", function()
    local deferredPos = isoPlayerSrc:find("this.doDeferredMovement(", 1, true)
    local playerMovePos = isoPlayerSrc:find('triggerEvent("OnPlayerMove"', 1, true)
    assert(deferredPos, "doDeferredMovement() call not found in IsoPlayer.java")
    assert(playerMovePos, "OnPlayerMove trigger not found in IsoPlayer.java")
    assert(deferredPos < playerMovePos,
        "CRITICAL: doDeferredMovement must appear BEFORE OnPlayerMove trigger.\n" ..
        "doDeferredMovement at char " .. deferredPos .. ", OnPlayerMove at char " .. playerMovePos ..
        "\nIf this order changed, our hook may run before the animation delta is in nextX.")
end)

-- =====================================================================
-- CONTRACT 10: setY() also clobbers nextY (symmetric with setX)
-- =====================================================================

test("ENGINE CONTRACT: setY() calls setNextY(y)", function()
    local setYBody = extractMethodBlock(isoMovingObjectSrc, "public float setY(float")
    assert(setYBody, "setY(float) method not found in IsoMovingObject.java")
    assertContains(setYBody, "this.setNextY(y)",
        "setY() must call setNextY(y) — symmetric with setX clobber behavior")
end)

-- =====================================================================
-- CONTRACT 11: Verify the scheduler runs preupdate → update → postupdate
-- This is the frame pipeline that makes our timing work.
-- =====================================================================

test("ENGINE CONTRACT: MovingObjectUpdateScheduler calls preupdate before update", function()
    local schedulerPath = PZ_JAVA .. "MovingObjectUpdateSchedulerUpdateBucket.java"
    local schedulerSrc = readFile(schedulerPath)
    local preupdatePos = schedulerSrc:find("preupdate()", 1, true)
    local updatePos = schedulerSrc:find(".update()", 1, true)
    assert(preupdatePos, "preupdate() call not found in scheduler")
    assert(updatePos, "update() call not found in scheduler")
    assert(preupdatePos < updatePos,
        "preupdate must be called before update in the scheduler bucket")
end)

-- =====================================================================
-- CONTRACT 12: Verify getX()/getY() are simple field getters
-- Our hook reads getX() to get the pre-movement position. If getX()
-- ever returns something derived (like nextX), our delta calc breaks.
-- =====================================================================

test("ENGINE CONTRACT: getX() returns this.x (simple field getter)", function()
    local getXBody = extractMethodBlock(isoMovingObjectSrc, "public float getX()")
    assert(getXBody, "getX() method not found")
    assertContains(getXBody, "return this.x",
        "getX() must be a simple field getter returning this.x")
end)

-- =====================================================================
-- CONTRACT 13: Verify IsoMovingObject has the postUpdate reconciliation
-- postupdate() must exist and do something with nextX to commit movement.
-- =====================================================================

test("ENGINE CONTRACT: IsoMovingObject has postupdate method", function()
    assertContains(isoMovingObjectSrc, "public void postupdate()",
        "postupdate() method must exist — this is where nextX→x reconciliation happens")
end)

-- =====================================================================
-- CONTRACT 14: Verify setMoveSpeed(0.06F) exists in BodyDamage
-- This confirms that direct moveSpeed manipulation gets overwritten,
-- validating our decision to NOT use setMoveSpeed().
-- =====================================================================

test("ENGINE CONTRACT: BodyDamage resets moveSpeed to 0.06F", function()
    local bdPath = PZ_JAVA .. "characters/BodyDamage/BodyDamage.java"
    local bdSrc = readFile(bdPath)
    assertContains(bdSrc, "setMoveSpeed(0.06F)",
        "BodyDamage must reset moveSpeed to 0.06F — confirms setMoveSpeed is unsafe for mods")
end)
