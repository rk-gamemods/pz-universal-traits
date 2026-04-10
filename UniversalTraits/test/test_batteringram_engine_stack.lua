-- test_batteringram_engine_stack.lua
-- Engine-contract + behavioral tests for the battering ram collision stack.
--
-- Covers: IsoMovingObject.separate() bump conditions, BumpedState lifecycle,
-- tick ordering, suppression timeline, bumpedChr re-assertion, and edge cases.
--
-- Run via: dofile from UniversalTraits/test/run_tests.lua

-- Path to decompiled PZ Java source
local PZ_JAVA = "C:/Users/Admin/Documents/GIT/GameMods/PZMods/PZCodebase/Java/source/zombie/"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then
        error("ENGINE CONTRACT: Cannot open " .. path ..
              "\nIs the PZCodebase decompiled source present?")
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function assertContains(content, needle, msg)
    if not content:find(needle, 1, true) then
        error(msg .. "\nNeedle not found: " .. needle, 2)
    end
end

local function extractMethodBlock(content, methodSig)
    local start = content:find(methodSig, 1, true)
    if not start then return nil end
    local braceStart = content:find("{", start)
    if not braceStart then return nil end
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

-- Load engine sources once
local isoMovingObjectSrc = readFile(PZ_JAVA .. "iso/IsoMovingObject.java")
local isoPlayerSrc       = readFile(PZ_JAVA .. "characters/IsoPlayer.java")
local isoGameCharSrc     = readFile(PZ_JAVA .. "characters/IsoGameCharacter.java")

-- Simulates PZ's separate() re-bump guard (line 1222)
local function wouldSeparateRebump(player, zombie)
    return player:getBumpedChr() ~= zombie
end

-- Simulates a full collision → hook → suppression tick sequence
local function simulateTick(player, opts)
    opts = opts or {}
    if opts.setBump then
        player:setBumpType(opts.bumpType or "stagger")
        player:setBumpedChr(opts.zombie)
        player._blockMovement = true
    end
    Events.OnPlayerUpdate:fire(player)
end

-- =====================================================================
-- ENGINE CONTRACTS: separate() bump conditions
-- These parse decompiled Java to detect PZ updates that would break
-- the battering ram's collision interception.
-- =====================================================================

test("ENGINE CONTRACT [RAM]: separate() uses getBumpedChr() != obj as re-bump guard", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found in IsoMovingObject.java")
    assertContains(separateBody, "getBumpedChr()",
        "separate() must reference getBumpedChr() — this is the re-bump guard our fix relies on")
end)

test("ENGINE CONTRACT [RAM]: separate() calls setBumpedChr on collision", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found")
    assertContains(separateBody, "setBumpedChr(",
        "separate() must call setBumpedChr() when triggering a bump")
end)

test("ENGINE CONTRACT [RAM]: separate() calls setBumpType on collision", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found")
    assertContains(separateBody, "setBumpType(",
        "separate() must call setBumpType() to trigger BumpedState")
end)

test("ENGINE CONTRACT [RAM]: separate() checks runningTime for bump eligibility", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found")
    assertContains(separateBody, "runningTime",
        "separate() must check runningTime — bump only triggers above threshold")
end)

test("ENGINE CONTRACT [RAM]: separate() checks WalkSpeed for bump eligibility", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found")
    assertContains(separateBody, "WalkSpeed",
        "separate() must check WalkSpeed variable — bump requires WalkSpeed > 0.2")
end)

test("ENGINE CONTRACT [RAM]: separate() reports wasBumped event", function()
    local separateBody = extractMethodBlock(isoMovingObjectSrc, "public void separate(")
    assert(separateBody, "separate() method not found")
    assertContains(separateBody, 'reportEvent("wasBumped")',
        "separate() must report wasBumped event after triggering bump")
end)

-- =====================================================================
-- ENGINE CONTRACTS: BumpedState lifecycle
-- BumpedState never exiting is the ROOT CAUSE of the freeze bug.
-- enter() sets BumpDone=false; the animation state machine holds the
-- player until BumpDone becomes true; doDeferredMovement() drives
-- position from animation (zero for bump), so the player is physically
-- frozen. Our fix forces BumpDone=true to trigger the exit transition.
-- These contracts detect if PZ changes any of this behavior.
-- =====================================================================

local bumpedStateSrc = readFile(PZ_JAVA .. "ai/states/BumpedState.java")

test("ENGINE CONTRACT [RAM]: BumpedState.exit() clears bumpType", function()
    local exitBody = extractMethodBlock(bumpedStateSrc, "public void exit(")
    assert(exitBody, "BumpedState.exit() not found")
    assertContains(exitBody, 'setBumpType("")',
        "BumpedState.exit() must clear bumpType — our hook detects this via isBumped()")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.exit() clears bumpedChr to null", function()
    local exitBody = extractMethodBlock(bumpedStateSrc, "public void exit(")
    assert(exitBody, "BumpedState.exit() not found")
    assertContains(exitBody, "setBumpedChr(null)",
        "CRITICAL: BumpedState.exit() must clear bumpedChr — this is WHY we re-assert it")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.exit() clears blockMovement via helper", function()
    local exitBody = extractMethodBlock(bumpedStateSrc, "public void exit(")
    assert(exitBody, "BumpedState.exit() not found")
    -- B42: uses setCharacterBlockMovement(owner, false) which delegates to player.setBlockMovement
    assertContains(exitBody, "setCharacterBlockMovement(owner, false)",
        "BumpedState.exit() must clear blockMovement via setCharacterBlockMovement")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.enter() sets blockMovement true via helper", function()
    local enterBody = extractMethodBlock(bumpedStateSrc, "public void enter(")
    assert(enterBody, "BumpedState.enter() not found")
    -- B42: uses setCharacterBlockMovement(owner, true)
    assertContains(enterBody, "setCharacterBlockMovement(owner, true)",
        "BumpedState.enter() must set blockMovement — this is what causes the freeze")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.execute() toggles blockMovement per tick", function()
    local executeBody = extractMethodBlock(bumpedStateSrc, "public void execute(")
    assert(executeBody, "BumpedState.execute() not found")
    assertContains(executeBody, "isBumpFall()",
        "BumpedState.execute() must check isBumpFall for blockMovement toggle")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.enter() sets BumpDone false", function()
    local enterBody = extractMethodBlock(bumpedStateSrc, "public void enter(")
    assert(enterBody, "BumpedState.enter() not found")
    assertContains(enterBody, "setBumpDone(false)",
        "CRITICAL: BumpedState.enter() sets BumpDone=false — this is the ROOT CAUSE of the " ..
        "freeze. Without forcing BumpDone=true, the animation state machine never exits " ..
        "BumpedState and doDeferredMovement() freezes the player in the bump animation.")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.enter() sets BumpFallAnimFinished false", function()
    local enterBody = extractMethodBlock(bumpedStateSrc, "public void enter(")
    assert(enterBody, "BumpedState.enter() not found")
    assertContains(enterBody, '"BumpFallAnimFinished"',
        "BumpedState.enter() must reference BumpFallAnimFinished — it resets the " ..
        "animation completion flag that keeps the player in the stagger animation")
end)

test("ENGINE CONTRACT [RAM]: BumpedState.exit() clears BumpAnimFinished", function()
    local exitBody = extractMethodBlock(bumpedStateSrc, "public void exit(")
    assert(exitBody, "BumpedState.exit() not found")
    assertContains(exitBody, '"BumpAnimFinished"',
        "BumpedState.exit() must reference BumpAnimFinished — confirms this variable " ..
        "is part of the BumpedState lifecycle and safe for our fix to set to true")
end)

test("ENGINE CONTRACT [RAM]: doDeferredMovement runs before OnPlayerUpdate", function()
    -- doDeferredMovement() must appear at a LOWER line number than OnPlayerUpdate
    -- in IsoPlayer.java. This confirms that animation-driven movement applies
    -- BEFORE our hook fires, meaning the bump animation controls position.
    local deferPos = isoPlayerSrc:find("this.doDeferredMovement()", 1, true)
    local hookPos  = isoPlayerSrc:find('triggerEvent("OnPlayerUpdate"', 1, true)
    assert(deferPos, "doDeferredMovement() not found in IsoPlayer.java")
    assert(hookPos, "OnPlayerUpdate trigger not found in IsoPlayer.java")
    assert(deferPos < hookPos,
        "CRITICAL: doDeferredMovement() must run BEFORE OnPlayerUpdate.\n" ..
        "While in BumpedState, the bump animation drives position via deferred movement.\n" ..
        "doDeferredMovement at byte " .. deferPos .. ", OnPlayerUpdate at byte " .. hookPos)
end)

-- =====================================================================
-- ENGINE CONTRACTS: IsoGameCharacter bump API
-- =====================================================================

test("ENGINE CONTRACT [RAM]: isBumped() checks bumpType is non-empty", function()
    local body = extractMethodBlock(isoGameCharSrc, "public boolean isBumped()")
    assert(body, "isBumped() not found in IsoGameCharacter.java")
    assertContains(body, "getBumpType()",
        "isBumped() must delegate to getBumpType() — clearing bumpType clears isBumped")
end)

test("ENGINE CONTRACT [RAM]: setBumpType triggers setBumpStaggered", function()
    local body = extractMethodBlock(isoGameCharSrc, "public void setBumpType(")
    assert(body, "setBumpType() not found in IsoGameCharacter.java")
    assertContains(body, "setBumpStaggered(",
        "setBumpType() must auto-call setBumpStaggered — affects BumpedState.execute() blockMovement")
end)

-- =====================================================================
-- ENGINE CONTRACTS: Tick ordering in IsoPlayer.updateInternal2()
-- Our hook fires at OnPlayerUpdate, BEFORE separate() runs.
-- If PZ swaps the order, the hook would fire on stale state.
-- =====================================================================

test("ENGINE CONTRACT [RAM]: OnPlayerUpdate fires before separate() in tick order", function()
    -- OnPlayerUpdate must appear at a LOWER line number than separate() call
    local hookPos = isoPlayerSrc:find('triggerEvent("OnPlayerUpdate"', 1, true)
    local sepPos  = isoPlayerSrc:find("this.separate()", 1, true)
    assert(hookPos, "OnPlayerUpdate trigger not found in IsoPlayer.java")
    assert(sepPos, "this.separate() call not found in IsoPlayer.java")
    assert(hookPos < sepPos,
        "CRITICAL: OnPlayerUpdate must fire BEFORE separate().\n" ..
        "OnPlayerUpdate at byte " .. hookPos .. ", separate() at byte " .. sepPos)
end)

test("ENGINE CONTRACT [RAM]: stateMachine.update() is in IsoGameCharacter (runs after IsoPlayer.separate)", function()
    -- separate() is called in IsoPlayer.updateInternal2() (line ~2634)
    -- stateMachine.update() is in IsoGameCharacter (line ~9764), called via
    -- super chain AFTER IsoPlayer's own update logic completes.
    -- We verify both exist in the expected files.
    local sepPos = isoPlayerSrc:find("this.separate()", 1, true)
    assert(sepPos, "this.separate() not found in IsoPlayer.java")
    local smPos = isoGameCharSrc:find("this.stateMachine.update()", 1, true)
    assert(smPos, "this.stateMachine.update() not found in IsoGameCharacter.java")
end)

-- =====================================================================
-- BEHAVIORAL: Suppression timeline — multi-tick simulations
-- =====================================================================

-- Helper: reset event handlers and reload hook + trait fresh.
-- Returns a restore function that MUST be called at end of test to
-- put the original event tables back for subsequent tests.
local function makeEventTable()
    local handlers = {}
    local tbl
    tbl = {
        Add    = function(fn) table.insert(handlers, fn) end,
        Remove = function(fn)
            for i, v in ipairs(handlers) do
                if v == fn then table.remove(handlers, i) return end
            end
        end,
        fire   = function(...)
            -- Strip implicit self arg from colon-call syntax,
            -- matching UTTestMocks.fireHandlers behavior.
            local args = { ... }
            if args[1] == tbl then table.remove(args, 1) end
            for _, fn in ipairs(handlers) do fn(table.unpack(args)) end
        end,
    }
    return tbl
end

local function resetAndLoadHook()
    local saved = {
        OnPlayerUpdate = Events.OnPlayerUpdate,
        OnCreatePlayer = Events.OnCreatePlayer,
        EveryOneMinute = Events.EveryOneMinute,
    }
    Events.OnPlayerUpdate = makeEventTable()
    Events.OnCreatePlayer = makeEventTable()
    Events.EveryOneMinute = makeEventTable()
    UTCore._zombieCollisionCallbacks = {}
    dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_batteringram.lua")
    return function()
        Events.OnPlayerUpdate = saved.OnPlayerUpdate
        Events.OnCreatePlayer = saved.OnCreatePlayer
        Events.EveryOneMinute = saved.EveryOneMinute
    end
end

-- Wrapper: run a function with fresh hook+events, auto-restore afterward
local function withFreshHook(fn)
    local restore = resetAndLoadHook()
    local ok, err = pcall(fn)
    restore()
    if not ok then error(err, 2) end
end

test("TIMELINE: full 30-tick suppression cycle clears bump every tick", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        player._blockMovement = true
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        assert_true(md.UT_bumpSuppress > 0, "expected suppression active after callback")
        assert_eq(md.UT_bumpGuardZombie, zombie, "expected guard zombie stored")
        local startSuppress = md.UT_bumpSuppress

        for tick = 1, startSuppress do
            player:setBumpType("stagger")
            player._blockMovement = true
            Events.OnPlayerUpdate:fire(player)
            assert_eq(player._bumpType, "", "tick " .. tick .. ": bumpType should be cleared")
            assert_eq(player._blockMovement, false, "tick " .. tick .. ": blockMovement should be false")
        end

        assert_eq(md.UT_bumpSuppress, 0, "expected suppression expired")
    end)
end)

test("TIMELINE: BumpedState.exit() at tick 25 — bumpedChr re-asserted", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        for _ = 1, 24 do
            Events.OnPlayerUpdate:fire(player)
        end

        player:setBumpedChr(nil)
        assert_eq(player:getBumpedChr(), nil, "precondition: exit() cleared bumpedChr")

        Events.OnPlayerUpdate:fire(player)
        assert_eq(player:getBumpedChr(), zombie,
            "expected bumpedChr re-asserted after BumpedState.exit()")
        assert_eq(wouldSeparateRebump(player, zombie), false,
            "expected engine re-bump guard restored")
    end)
end)

-- =====================================================================
-- EDGE CASES: conditions that should NOT trigger or should be safe
-- =====================================================================

test("EDGE: walking player does not trigger batteringram", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        local zombie = MockZombie()
        local fn = UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"]
        local result = fn(player, zombie)
        assert_eq(result, false, "walking should not activate batteringram")
        assert_eq(#zombie:getKnockDownCalls(), 0, "no knockdown when walking")
    end)
end)

test("EDGE: exhausted endurance still allows charge (endurance=0)", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" }, { endurance = 0 })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local fn = UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"]
        local result = fn(player, zombie)
        assert_eq(result, true, "charge should still work at zero endurance")
        assert_eq(#zombie:getKnockDownCalls(), 1, "zombie should still get knocked down")
        assert_eq(player:getStats():get(CharacterStat.ENDURANCE), 0,
            "endurance should not go negative")
    end)
end)

test("EDGE: non-zombie bumpedChr does not fire callback", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local md = player:getModData()
        local otherPlayer = MockPlayer({})
        player:setBumpType("stagger")
        player:setBumpedChr(otherPlayer)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)
        assert_eq(md.UT_bumpSuppress or 0, 0,
            "expected no suppression for non-zombie bump")
    end)
end)

test("EDGE: nil bumpedChr does not fire callback", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        local md = player:getModData()
        player:setBumpType("stagger")
        player:setBumpedChr(nil)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)
        assert_eq(md.UT_bumpSuppress or 0, 0,
            "expected no suppression when bumpedChr is nil")
    end)
end)

-- =====================================================================
-- CLUSTER: multiple zombies in rapid succession
-- =====================================================================

test("CLUSTER: second zombie bump during suppression is cleared", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombieA = MockZombie()
        local zombieB = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombieA)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)
        assert_true(md.UT_bumpSuppress > 0, "suppression active after A")

        player:setBumpType("stagger")
        player:setBumpedChr(zombieB)
        player._blockMovement = true

        Events.OnPlayerUpdate:fire(player)
        assert_eq(player._bumpType, "", "suppression should clear B's bump")
        assert_eq(player._blockMovement, false, "movement should be unblocked")
    end)
end)

test("CLUSTER: guard zombie matches original after cluster re-bumps", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombieA = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombieA)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        assert_eq(md.UT_bumpGuardZombie, zombieA,
            "guard zombie should be the original collision zombie")
    end)
end)

-- =====================================================================
-- REGRESSION: specific bug scenarios from fix history
-- =====================================================================

test("REGRESSION: freeze loop — separate() re-bumps after BumpedState.exit()", function()
    -- THE BUG: BumpedState.exit() calls setBumpedChr(null).
    -- separate() sees getBumpedChr() != zombie → re-bumps → new BumpedState
    -- → exit() clears again → infinite loop = freeze.
    -- THE FIX: suppression re-asserts bumpedChr each tick.
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        local freezeDetected = false
        for tick = 1, 30 do
            if tick == 20 then
                player:setBumpedChr(nil)
            end
            if wouldSeparateRebump(player, zombie) then
                player:setBumpType("stagger")
                player._blockMovement = true
            end
            Events.OnPlayerUpdate:fire(player)
            if player._blockMovement then
                freezeDetected = true
                break
            end
        end
        assert_eq(freezeDetected, false,
            "REGRESSION: freeze loop detected — movement was blocked during suppression")
        assert_eq(player:getBumpedChr(), zombie,
            "bumpedChr must be re-asserted to prevent re-bump loop")
    end)
end)

test("REGRESSION: guard cleanup after suppression expires", function()
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        md.UT_bumpSuppress = 0
        Events.OnPlayerUpdate:fire(player)

        assert_eq(md.UT_bumpGuardZombie, nil,
            "guard zombie must be cleaned up after suppression expires")
    end)
end)

-- =====================================================================
-- ROOT CAUSE FIX: BumpDone forced to true
-- THE PRIMARY FIX. Without setBumpDone(true), BumpedState never exits
-- and doDeferredMovement() keeps the player frozen in the bump animation.
-- =====================================================================

test("ROOT CAUSE FIX: BumpDone set to true on initial callback tick", function()
    -- This is THE critical test. The freeze was caused by BumpedState never
    -- exiting because BumpDone stayed false. Our fix must set it to true
    -- on the SAME tick the rising edge is detected and callbacks fire.
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        -- Simulate engine bump
        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        player._bumpDone = false  -- BumpedState.enter() sets this
        md.UT_prevBumped = false

        Events.OnPlayerUpdate:fire(player)

        assert_eq(player._bumpDone, true,
            "CRITICAL: BumpDone must be true after callback handles collision. " ..
            "Without this, BumpedState never exits and the player is permanently " ..
            "frozen because doDeferredMovement() drives zero-movement from the " ..
            "bump animation.")
    end)
end)

test("ROOT CAUSE FIX: BumpDone re-set to true every suppression tick", function()
    -- Even if something re-enters BumpedState (e.g. multi-zombie bump),
    -- BumpDone must be forced true every suppression tick.
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        -- Trigger initial bump
        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        md.UT_prevBumped = false
        Events.OnPlayerUpdate:fire(player)

        -- Simulate BumpedState.enter() re-setting BumpDone=false
        -- (e.g. from a multi-zombie re-bump via separate())
        player._bumpDone = false

        -- Next suppression tick should force it back to true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(player._bumpDone, true,
            "BumpDone must be re-forced to true on every suppression tick")
    end)
end)

test("ROOT CAUSE FIX: single zombie — full freeze scenario prevented", function()
    -- Simulates the exact scenario reported by the user:
    -- Sprint into ONE zombie → character locks up.
    -- The fix must prevent the freeze by forcing BumpedState to exit.
    withFreshHook(function()
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        local zombie = MockZombie()
        local md = player:getModData()

        -- TICK 0: Engine triggers bump (separate() runs AFTER OnPlayerUpdate)
        -- Our hook sees no bump yet on this tick.
        Events.OnPlayerUpdate:fire(player)  -- hook fires, no bump detected

        -- After hook: separate() bumps player (simulated)
        player:setBumpType("stagger")
        player:setBumpedChr(zombie)
        player._blockMovement = true
        player._bumpDone = false  -- BumpedState.enter()

        -- TICK 1: Hook fires, detects rising edge
        Events.OnPlayerUpdate:fire(player)

        -- Verify fix applied
        assert_eq(player._bumpDone, true,
            "BumpDone must be true — this forces BumpedState to exit")
        assert_eq(player._bumpType, "",
            "bumpType must be cleared — clears isBumped and bumpStaggered")
        assert_eq(player._bumpFall, false,
            "bumpFall must be cleared")
        assert_eq(player._blockMovement, false,
            "blockMovement must be cleared")
        assert_eq(#zombie:getKnockDownCalls(), 1,
            "zombie must be knocked down by the charge")
        assert_true(md.UT_bumpSuppress > 0,
            "suppression must be active to prevent re-bump")

        -- TICKS 2-31: Verify player stays unfrozen during entire suppression
        for tick = 2, 31 do
            -- Simulate separate() re-asserting a bump (won't happen with guard,
            -- but test the suppression path anyway)
            player._bumpDone = false
            player._blockMovement = true
            Events.OnPlayerUpdate:fire(player)
            assert_eq(player._bumpDone, true,
                "tick " .. tick .. ": BumpDone must stay true during suppression")
            assert_eq(player._blockMovement, false,
                "tick " .. tick .. ": blockMovement must stay false during suppression")
        end
    end)
end)
