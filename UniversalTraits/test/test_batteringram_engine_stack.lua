-- test_batteringram_engine_stack.lua
-- Engine contracts + behavioral tests for preemptive runningTime bump prevention.
-- Run via: dofile from UniversalTraits/test/run_tests.lua

local PZ_JAVA = "C:/Users/Admin/Documents/GIT/GameMods/PZMods/PZCodebase/Java/source/zombie/"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then error("Cannot open " .. path) end
    local content = f:read("*a")
    f:close()
    return content
end

local function assertContains(content, needle, msg)
    if not content:find(needle, 1, true) then
        error(msg .. "\nNeedle not found: " .. needle, 2)
    end
end

local isoMovingObjectSrc = readFile(PZ_JAVA .. "iso/IsoMovingObject.java")
local isoPlayerSrc       = readFile(PZ_JAVA .. "characters/IsoPlayer.java")

-- =====================================================================
-- ENGINE CONTRACTS: separate() bump conditions
-- =====================================================================

test("ENGINE CONTRACT [RAM]: separate() checks runningTime for bump", function()
    assertContains(isoMovingObjectSrc, "runningTime",
        "separate() checks runningTime for bump condition")
end)

test("ENGINE CONTRACT [RAM]: separate() checks WalkSpeed for bump", function()
    assertContains(isoMovingObjectSrc, "WalkSpeed",
        "separate() must check WalkSpeed — bump requires WalkSpeed > 0.2")
end)

test("ENGINE CONTRACT [RAM]: OnPlayerUpdate fires before separate()", function()
    local hookPos = isoPlayerSrc:find('triggerEvent("OnPlayerUpdate"', 1, true)
    local sepPos  = isoPlayerSrc:find("this.separate()", 1, true)
    assert(hookPos and sepPos, "OnPlayerUpdate or separate() not found")
    assert(hookPos < sepPos, "OnPlayerUpdate must fire BEFORE separate()")
end)

test("ENGINE CONTRACT [RAM]: runningTime is a public field on IsoPlayer", function()
    assertContains(isoPlayerSrc, "public float runningTime",
        "runningTime is public (Kahlua can read but NOT write Java fields)")
end)

test("ENGINE CONTRACT [RAM]: separate() checks getBumpedChr for re-bump guard", function()
    assertContains(isoMovingObjectSrc, "getBumpedChr",
        "separate() uses getBumpedChr() != obj — our hook sets this via setBumpedChr")
end)

-- =====================================================================
-- BEHAVIORAL: preemptive runningTime prevention
-- =====================================================================

local function makeEventTable()
    local handlers = {}
    local tbl
    tbl = {
        Add = function(fn) table.insert(handlers, fn) end,
        Remove = function(fn)
            for i, v in ipairs(handlers) do
                if v == fn then table.remove(handlers, i) return end
            end
        end,
        fire = function(...)
            local args = { ... }
            if args[1] == tbl then table.remove(args, 1) end
            for _, fn in ipairs(handlers) do fn(table.unpack(args)) end
        end,
    }
    return tbl
end

local function withFreshHook(fn)
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
    local ok, err = pcall(fn)
    Events.OnPlayerUpdate = saved.OnPlayerUpdate
    Events.OnCreatePlayer = saved.OnCreatePlayer
    Events.EveryOneMinute = saved.EveryOneMinute
    if not ok then error(err, 2) end
end

-- Setup: player at (5,5,0), zombie at (5.3,5,0) = within 0.7 range
local function setupCollision(playerOpts)
    local zombie = MockZombie({ x = 5.3, y = 5, z = 0 })
    local sq = MockCollisionSquare(5, 5, 0, { zombie })
    _G._mockCell = MockCell({ ["5,5,0"] = sq })
    playerOpts = playerOpts or {}
    playerOpts.x = 5
    playerOpts.y = 5
    playerOpts.square = sq
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" }, playerOpts)
    return player, zombie
end

-- Setup: player at (5,5,0), zombie at (5.3,5,0) = within 0.7 range
local function setupCollision(playerOpts)
    local zombie = MockZombie({ x = 5.3, y = 5, z = 0 })
    local sq = MockCollisionSquare(5, 5, 0, { zombie })
    _G._mockCell = MockCell({ ["5,5,0"] = sq })
    playerOpts = playerOpts or {}
    playerOpts.x = 5
    playerOpts.y = 5
    playerOpts.square = sq
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" }, playerOpts)
    return player, zombie
end

test("PREEMPT: knockdown fires when sprinting near zombie (v4)", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        -- v4: hook must NOT touch player bump state
        assert_eq(player:getBumpedChr(), nil,
            "v4 hook must NOT set bumpedChr — knockdown-only defense")
        -- Callback should have knocked down the zombie
        assert_true(zombie:isKnockedDown(),
            "batteringram should knock down zombie on sprint collision")
    end)
end)

test("PREEMPT: knockdown fires when running near zombie (v4)", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._running = true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(player:getBumpedChr(), nil,
            "v4 hook must NOT set bumpedChr when running")
        assert_true(zombie:isKnockedDown(),
            "batteringram should knock down zombie on run collision")
    end)
end)

test("PREEMPT: setBumpedChr NOT set when walking (not running/sprinting)", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        -- _sprinting and _running both false
        Events.OnPlayerUpdate:fire(player)
        assert_eq(player:getBumpedChr(), nil,
            "setBumpedChr should be nil when walking")
    end)
end)

test("PREEMPT: setBumpedChr NOT set when no zombies in range", function()
    withFreshHook(function()
        -- Zombie at (10,10) — far from player at (5,5)
        local zombie = MockZombie({ x = 10, y = 10, z = 0 })
        local sq = MockCollisionSquare(5, 5, 0, {})
        _G._mockCell = MockCell({ ["5,5,0"] = sq })
        local player = MockPlayer({ "UniversalTraits:UT_batteringram" },
            { x = 5, y = 5, square = sq })
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(player:getBumpedChr(), nil,
            "setBumpedChr should be nil when no zombies nearby")
    end)
end)

test("PREEMPT: zombie knocked down when entering range while sprinting", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(#zombie:getKnockDownCalls(), 1,
            "zombie should be knocked down on first proximity detection")
    end)
end)

test("PREEMPT: zombie NOT re-knocked on subsequent ticks (dedup)", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        Events.OnPlayerUpdate:fire(player)
        Events.OnPlayerUpdate:fire(player)
        assert_eq(#zombie:getKnockDownCalls(), 1,
            "callback should fire once per zombie, not every tick")
    end)
end)

test("PREEMPT: endurance drained on collision", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_true(player:getStats():get(CharacterStat.ENDURANCE) < 1.0,
            "endurance should be drained after collision")
    end)
end)

test("PREEMPT: sprint deals direct damage to zombie", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_true(zombie:getHealth() < 100,
            "zombie health should be reduced on sprint charge")
    end)
end)

test("PREEMPT: no bump state manipulation (no setBumpType/setBumpFall)", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        player._bumpType = "stagger"
        player._bumpFall = true
        Events.OnPlayerUpdate:fire(player)
        -- The new approach does NOT touch bump state at all
        assert_eq(player._bumpType, "stagger",
            "new approach should NOT manipulate bumpType")
        assert_eq(player._bumpFall, true,
            "new approach should NOT manipulate bumpFall")
    end)
end)

test("PREEMPT: dedup resets when player stops running", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(#zombie:getKnockDownCalls(), 1, "first knockdown")
        -- Player stops
        player._sprinting = false
        Events.OnPlayerUpdate:fire(player)
        -- Player starts sprinting again near same zombie
        player._sprinting = true
        Events.OnPlayerUpdate:fire(player)
        assert_eq(#zombie:getKnockDownCalls(), 2,
            "zombie should be knocked down again after player stopped and restarted")
    end)
end)

test("PREEMPT: walking player does NOT trigger callback", function()
    withFreshHook(function()
        local player, zombie = setupCollision()
        Events.OnCreatePlayer:fire(0, player)
        -- not sprinting, not running
        Events.OnPlayerUpdate:fire(player)
        assert_eq(#zombie:getKnockDownCalls(), 0,
            "walking should not trigger knockdown")
    end)
end)
