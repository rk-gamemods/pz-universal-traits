-- UTCore_FreezeLogger.lua
-- Targeted diagnostic logger: detects movement freeze and dumps full state.
--
-- DETECTION: tracks player position each tick. When position is unchanged
-- for FREEZE_DETECT_TICKS while the player was previously moving, triggers
-- a detailed state dump to the PZ console (console.txt).
--
-- The dump captures everything needed to diagnose what blocked movement:
-- position, pending movement, all movement flags, all UT_ modData,
-- zombie count, weapon info, and whether OnPlayerMove fired.
--
-- USAGE: always-on (minimal overhead during normal play). When the user
-- experiences a freeze, check Zomboid/console.txt for "[FREEZE]" lines.

UTCore = UTCore or {}

local FREEZE_DETECT_TICKS = 3        -- ticks without position change = freeze
local FREEZE_LOG_INTERVAL = 30       -- while frozen, log state every N ticks
local MAX_FREEZE_LOGS     = 20       -- stop logging after this many dumps per freeze
local STUCK_RECOVERY_TICKS = 120     -- ~2 seconds at 60fps: force-recover stuck bump state

-- State tracking
local _prevX, _prevY = nil, nil
local _wasMoving = false
local _stuckCount = 0
local _freezeLogCount = 0
local _onPlayerMoveFired = false      -- set by OnPlayerMove hook, read by OnPlayerUpdate
local _prevMoveX, _prevMoveY = nil, nil -- position last OnPlayerMove saw
local _recoveryFired = false          -- prevents recovery from firing repeatedly

---------------------------------------------------------------------------
-- Safe method caller — returns nil instead of crashing on missing methods
---------------------------------------------------------------------------
local function safeCall(obj, method, ...)
    if not obj then return nil end
    local fn = obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function safeStr(val)
    if val == nil then return "nil" end
    if type(val) == "boolean" then return val and "true" or "false" end
    return tostring(val)
end

---------------------------------------------------------------------------
-- State snapshot
---------------------------------------------------------------------------
local function captureState(player)
    local x   = safeCall(player, "getX") or 0
    local y   = safeCall(player, "getY") or 0
    local z   = safeCall(player, "getZ") or 0
    local nx  = safeCall(player, "getNextX") or 0
    local ny  = safeCall(player, "getNextY") or 0
    local dx  = nx - x
    local dy  = ny - y

    local state = {
        x = x, y = y, z = z,
        nx = nx, ny = ny,
        dx = string.format("%.6f", dx),
        dy = string.format("%.6f", dy),
        isMoving     = safeStr(safeCall(player, "isMoving")),
        isRunning    = safeStr(safeCall(player, "isRunning")),
        isSprinting  = safeStr(safeCall(player, "isSprinting")),
        isAiming     = safeStr(safeCall(player, "isAiming")),
        isDead       = safeStr(safeCall(player, "isDead")),
        hasVehicle   = safeStr(safeCall(player, "getVehicle") ~= nil),
        blockMovement   = safeStr(safeCall(player, "isBlockMovement")),
        blockMovement2  = safeStr(safeCall(player, "getBlockMovement")),
        hitReaction     = safeStr(safeCall(player, "getHitReaction")),
        bumpDone        = safeStr(safeCall(player, "isBumpDone")),
        bumpedChr       = safeStr(safeCall(player, "getBumpedChr")),
        onPlayerMoveFired = safeStr(_onPlayerMoveFired),
    }

    -- BumpType, BumpFall via animation variables
    state.varBumpDone = safeStr(safeCall(player, "getVariable", "BumpDone"))
    state.varBumpFall = safeStr(safeCall(player, "getVariable", "BumpFall"))
    state.varBumpFallAnimFinished = safeStr(safeCall(player, "getVariable", "BumpFallAnimFinished"))
    state.varIsAiming = safeStr(safeCall(player, "getVariable", "IsAiming"))

    -- Spotted list (zombie count)
    local sl = safeCall(player, "getSpottedList")
    if sl then
        state.spottedCount = safeCall(sl, "size") or "?"
    else
        state.spottedCount = "no_method"
    end

    -- Weapon info
    local weapon = safeCall(player, "getPrimaryHandItem")
    if weapon then
        state.weapon = safeStr(safeCall(weapon, "getType") or safeCall(weapon, "getName") or weapon)
    else
        state.weapon = "none"
    end

    -- All UT_ moddata keys
    local md = safeCall(player, "getModData")
    state.utModData = {}
    if md and type(md) == "table" then
        for k, v in pairs(md) do
            if type(k) == "string" and k:sub(1, 3) == "UT_" then
                state.utModData[k] = safeStr(v)
            end
        end
    end

    -- Zombie collision handler info
    state.zombieCollisionHandlers = {}
    if UTCore._zombieCollisionCallbacks then
        for traitId, _ in pairs(UTCore._zombieCollisionCallbacks) do
            state.zombieCollisionHandlers[#state.zombieCollisionHandlers + 1] = traitId
        end
    end

    return state
end

---------------------------------------------------------------------------
-- Output formatting
---------------------------------------------------------------------------
local function dumpState(prefix, state)
    print(prefix .. " pos=(" .. state.x .. "," .. state.y .. "," .. state.z .. ")"
        .. " next=(" .. state.nx .. "," .. state.ny .. ")"
        .. " dx=" .. state.dx .. " dy=" .. state.dy)
    print(prefix .. " isMoving=" .. state.isMoving
        .. " isRunning=" .. state.isRunning
        .. " isSprinting=" .. state.isSprinting
        .. " isAiming=" .. state.isAiming)
    print(prefix .. " blockMovement=" .. state.blockMovement
        .. " blockMovement2=" .. state.blockMovement2
        .. " hitReaction=" .. state.hitReaction)
    print(prefix .. " bumpDone=" .. state.bumpDone
        .. " bumpedChr=" .. state.bumpedChr
        .. " OnPlayerMove=" .. state.onPlayerMoveFired)
    print(prefix .. " var:BumpDone=" .. state.varBumpDone
        .. " var:BumpFall=" .. state.varBumpFall
        .. " var:BumpFallAnimFinished=" .. state.varBumpFallAnimFinished
        .. " var:IsAiming=" .. state.varIsAiming)
    print(prefix .. " weapon=" .. state.weapon
        .. " spottedCount=" .. safeStr(state.spottedCount))

    -- UT_ moddata
    local mdParts = {}
    for k, v in pairs(state.utModData) do
        mdParts[#mdParts + 1] = k .. "=" .. v
    end
    if #mdParts > 0 then
        table.sort(mdParts)
        print(prefix .. " modData: " .. table.concat(mdParts, ", "))
    end

    -- Zombie collision handlers
    if #state.zombieCollisionHandlers > 0 then
        print(prefix .. " zombieCollisionHandlers: "
            .. table.concat(state.zombieCollisionHandlers, ", "))
    else
        print(prefix .. " zombieCollisionHandlers: NONE")
    end
end

---------------------------------------------------------------------------
-- OnPlayerMove tracker — detects if engine calls OnPlayerMove
---------------------------------------------------------------------------
local function onPlayerMove()
    _onPlayerMoveFired = true
    local player = getPlayer()
    if player then
        _prevMoveX = safeCall(player, "getX")
        _prevMoveY = safeCall(player, "getY")
    end
end

---------------------------------------------------------------------------
-- Main tick handler
---------------------------------------------------------------------------
local function onPlayerUpdate(player)
    if not player then return end
    if safeCall(player, "isDead") then
        _stuckCount = 0
        _wasMoving = false
        return
    end
    if safeCall(player, "getVehicle") ~= nil then
        _stuckCount = 0
        _wasMoving = false
        return
    end

    local x = safeCall(player, "getX") or 0
    local y = safeCall(player, "getY") or 0

    if _prevX == nil then
        _prevX, _prevY = x, y
        _onPlayerMoveFired = false
        return
    end

    local moved = (x ~= _prevX or y ~= _prevY)

    if moved then
        -- Player moved this tick — reset freeze tracking
        _stuckCount = 0
        _freezeLogCount = 0
        _wasMoving = true
        _recoveryFired = false
    else
        -- Position unchanged
        _stuckCount = _stuckCount + 1

        -- Freeze transition: was moving, now stuck
        if _wasMoving and _stuckCount == FREEZE_DETECT_TICKS then
            print("[FREEZE] ===== FREEZE DETECTED at tick " .. _stuckCount .. " =====")
            local state = captureState(player)
            dumpState("[FREEZE]", state)
            _freezeLogCount = 1
            -- Dump ring buffer for pre-freeze event history
            if UTCore.dumpDiagnostics then
                UTCore.dumpDiagnostics()
            end
            if UTCore.diagLog then
                UTCore.diagLog("FreezeLog", "freeze_detected",
                    "blockMov=" .. state.blockMovement
                    .. " bumpedChr=" .. state.bumpedChr
                    .. " bumpDone=" .. state.bumpDone)
            end
        end

        -- Periodic logging while frozen
        if _stuckCount > FREEZE_DETECT_TICKS
            and _freezeLogCount > 0
            and _freezeLogCount < MAX_FREEZE_LOGS
            and _stuckCount % FREEZE_LOG_INTERVAL == 0 then
            print("[FREEZE] ===== STILL FROZEN tick=" .. _stuckCount .. " =====")
            local state = captureState(player)
            dumpState("[FREEZE]", state)
            _freezeLogCount = _freezeLogCount + 1
        end

        -- STUCK BUMP RECOVERY: if frozen for STUCK_RECOVERY_TICKS with
        -- blockMovement=true, the bump state is genuinely stuck.
        -- Force-clear to restore movement. This handles:
        --   - Engine-initiated bumps where BumpDone never fires
        --   - Our setBumpedChr guard interfering with active BumpedState
        --   - Any other state where blockMovement gets stuck
        if not _recoveryFired
            and _stuckCount >= STUCK_RECOVERY_TICKS
            and safeCall(player, "isBlockMovement") then

            _recoveryFired = true
            print("[FREEZE] ===== STUCK BUMP RECOVERY at tick " .. _stuckCount .. " =====")

            -- Mirror what BumpedState.exit() does:
            --   setBlockMovement(false)
            --   setBumpedChr(null)
            --   setBumpDone(true)
            --   clear BumpFall, BumpFallAnimFinished variables
            pcall(function() player:setBlockMovement(false) end)
            pcall(function() player:setBumpedChr(nil) end)
            pcall(function() player:setBumpDone(true) end)
            pcall(function() player:setVariable("BumpDone", "true") end)
            pcall(function() player:setVariable("BumpFall", "false") end)
            pcall(function() player:setVariable("BumpFallAnimFinished", "true") end)

            local state = captureState(player)
            dumpState("[FREEZE] POST-RECOVERY", state)

            if UTCore.diagLog then
                UTCore.diagLog("FreezeLog", "stuck_recovery",
                    "tick=" .. _stuckCount
                    .. " blockMov=" .. state.blockMovement
                    .. " bumpedChr=" .. state.bumpedChr)
            end
        end

        -- After prolonged freeze, stop periodic logging
        if _freezeLogCount >= MAX_FREEZE_LOGS and _stuckCount % (FREEZE_LOG_INTERVAL * 10) == 0 then
            print("[FREEZE] (logging paused, " .. _stuckCount .. " ticks frozen)")
        end
    end

    _prevX, _prevY = x, y
    _onPlayerMoveFired = false  -- reset for next tick
end

-- Register EARLY so we see state before other hooks modify it
-- (Events.OnPlayerUpdate processes in registration order)
if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end

-- Expose for testing
UTCore._freezeLoggerOnPlayerUpdate = onPlayerUpdate
UTCore._freezeLoggerOnPlayerMove = onPlayerMove
UTCore._getFreezeLoggerStuckCount = function() return _stuckCount end
UTCore._resetFreezeLogger = function()
    _prevX, _prevY = nil, nil
    _wasMoving = false
    _stuckCount = 0
    _freezeLogCount = 0
    _onPlayerMoveFired = false
    _recoveryFired = false
end
