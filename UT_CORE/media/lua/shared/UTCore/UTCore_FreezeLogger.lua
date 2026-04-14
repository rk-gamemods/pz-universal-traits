-- UTCore_FreezeLogger.lua
-- Targeted diagnostic logger: detects TRUE movement freeze and dumps full state.
--
-- DETECTION: a freeze is when the player is ACTIVELY PRESSING movement keys
-- (isMoving() == true) but position does not change. This distinguishes a
-- real engine freeze from normal stops (looting, aiming, opening inventory,
-- standing still). The old detection based on historical "_wasMoving" flag
-- produced massive false positives because it fired on every intentional stop.
--
-- The dump captures everything needed to diagnose what blocked movement:
-- position, pending movement delta, animation state machine, all movement
-- flags, all UT_ modData, zombie count, weapon info, and whether the
-- engine's OnPlayerMove event fired.
--
-- USAGE: always-on (minimal overhead during normal play). When the user
-- experiences a freeze, check Zomboid/console.txt for "[FREEZE]" lines.

UTCore = UTCore or {}

local FREEZE_DETECT_TICKS = 5        -- ticks with isMoving+no position change = freeze
local FREEZE_LOG_INTERVAL = 30       -- while frozen, log state every N ticks
local MAX_FREEZE_LOGS     = 20       -- stop logging after this many dumps per freeze

-- Recovery constants
local RECOVERY_TICK_1     = 15       -- first recovery attempt (~0.5s into freeze)
local RECOVERY_TICK_2     = 45       -- second attempt (~1.5s)
local RECOVERY_TICK_3     = 90       -- third attempt (~3s)
local MAX_RECOVERY        = 3        -- stop trying after this many attempts per freeze

-- State tracking
local _prevX, _prevY = nil, nil
local _stuckCount = 0
local _freezeLogCount = 0
local _onPlayerMoveFired = false      -- set by OnPlayerMove hook, read by OnPlayerUpdate
local _prevMoveX, _prevMoveY = nil, nil -- position last OnPlayerMove saw
local _recoveryAttempts = 0           -- recovery attempts this freeze event

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

    -- Animation variables: use getVariableBoolean for booleans (getVariable
    -- returns the AnimationVariableSlot Java object, not the boolean value)
    state.varBumpDone = safeStr(safeCall(player, "getVariableBoolean", "BumpDone"))
    state.varBumpFall = safeStr(safeCall(player, "getVariableBoolean", "BumpFall"))
    state.varBumpFallAnimFinished = safeStr(safeCall(player, "getVariableBoolean", "BumpFallAnimFinished"))
    state.varIsAiming = safeStr(safeCall(player, "getVariableBoolean", "IsAiming"))
    -- String animation variables for movement/combat state diagnosis
    state.varBumpType = safeStr(safeCall(player, "getVariable", "BumpType"))
    state.varMovementState = safeStr(safeCall(player, "getVariable", "MovementState"))

    -- Player state machine: getCurrentState returns a Java State object
    -- whose tostring gives us the class name (e.g. IdleState, PlayerHitReactionState)
    local curState = safeCall(player, "getCurrentState")
    state.currentState = curState and tostring(curState) or "nil"
    local prevState = safeCall(player, "getPreviousStateName")
    state.prevState = safeStr(prevState)

    -- Extra movement diagnostics
    state.isPathing = safeStr(safeCall(player, "isPathing"))
    state.isHostileAnim = safeStr(safeCall(player, "isPerformingHostileAnimation"))
    state.isAttackAnim  = safeStr(safeCall(player, "isPerformingAttackAnimation"))

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
    print(prefix .. " var:BumpType=" .. state.varBumpType
        .. " var:MovementState=" .. state.varMovementState)
    print(prefix .. " currentState=" .. state.currentState
        .. " prevState=" .. state.prevState
        .. " isPathing=" .. state.isPathing
        .. " hostileAnim=" .. state.isHostileAnim
        .. " attackAnim=" .. state.isAttackAnim)
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
-- Recovery: attempt to unstick the player from a confirmed freeze
---------------------------------------------------------------------------
local function attemptRecovery(player)
    -- Safety: never recover dead players or vehicle occupants
    if safeCall(player, "isDead") then return false end
    if safeCall(player, "getVehicle") ~= nil then return false end

    -- Safety: skip if a timed action is running (door anim, crafting, etc.)
    local ok, busy = pcall(function() return player:hasTimedActions() end)
    if ok and busy then return false end

    _recoveryAttempts = _recoveryAttempts + 1
    print("[FREEZE:RECOVERY] Attempt " .. _recoveryAttempts .. " at tick " .. _stuckCount)

    -- Step 1: Clear all known blocking state variables
    pcall(player.setBlockMovement, player, false)
    if player.setBumpDone then pcall(player.setBumpDone, player, true) end
    pcall(player.setVariable, player, "BumpDone", true)
    pcall(player.setVariable, player, "BumpFallAnimFinished", true)
    pcall(player.setVariable, player, "BumpAnimFinished", true)
    if player.setHitReaction then pcall(player.setHitReaction, player, "") end
    pcall(player.setIsAiming, player, false)

    -- Step 2: If stuck in IdleState, force transition to PlayerMovementState
    local curState = safeCall(player, "getCurrentState")
    local stateStr = curState and tostring(curState) or ""
    if stateStr:find("IdleState") then
        -- PlayerMovementState is exposed to Lua via LuaManager.setExposed()
        local ok2, pms = pcall(function() return PlayerMovementState.instance() end)
        if ok2 and pms then
            pcall(player.changeState, player, pms)
            print("[FREEZE:RECOVERY] Forced changeState IdleState -> PlayerMovementState")
            if UTCore.diagLog then
                UTCore.diagLog("FreezeRecovery", "changeState", "IdleState->PlayerMovementState attempt=" .. _recoveryAttempts)
            end
            return true
        else
            -- Fallback: re-enter IdleState to trigger setParams re-initialization
            local ok3, idle = pcall(function() return IdleState.instance() end)
            if ok3 and idle then
                pcall(player.changeState, player, idle)
                print("[FREEZE:RECOVERY] Forced IdleState re-entry (PlayerMovementState unavailable)")
            end
        end
    else
        print("[FREEZE:RECOVERY] Not in IdleState (" .. stateStr .. "), cleared blocking vars only")
    end

    if UTCore.diagLog then
        UTCore.diagLog("FreezeRecovery", "attempt", "state=" .. stateStr .. " attempt=" .. _recoveryAttempts)
    end
    return true
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
local function onPlayerUpdate(player, tick)
    -- Core handler: centralDispatch already skips dead players.
    -- Vehicle check: reset freeze state when driving (can't freeze in vehicle).
    local vehicle = tick and tick.vehicle or safeCall(player, "getVehicle")
    if vehicle ~= nil then
        _stuckCount = 0
        _recoveryAttempts = 0
        return
    end

    -- Timed action check: player is intentionally immobile during door
    -- animations, crafting, etc. Don't count these as freezes.
    local okTA, hasTimed = pcall(function() return player:hasTimedActions() end)
    if okTA and hasTimed then
        _stuckCount = 0
        return
    end

    local x = tick and tick.x or safeCall(player, "getX") or 0
    local y = tick and tick.y or safeCall(player, "getY") or 0

    if _prevX == nil then
        _prevX, _prevY = x, y
        _onPlayerMoveFired = false
        return
    end

    local moved = (x ~= _prevX or y ~= _prevY)
    local wantsToMove = tick and tick.isMoving or safeCall(player, "isMoving") or false

    if moved then
        -- Player actually moved — reset everything
        if _recoveryAttempts > 0 then
            print("[FREEZE:RECOVERY] Player moved after " .. _recoveryAttempts .. " recovery attempt(s) — freeze cleared")
        end
        _stuckCount = 0
        _freezeLogCount = 0
        _recoveryAttempts = 0
    elseif wantsToMove then
        -- Player is PRESSING movement keys but position didn't change — real stuck
        _stuckCount = _stuckCount + 1

        if _stuckCount == FREEZE_DETECT_TICKS then
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

        -- After prolonged freeze, stop periodic logging
        if _freezeLogCount >= MAX_FREEZE_LOGS and _stuckCount % (FREEZE_LOG_INTERVAL * 10) == 0 then
            print("[FREEZE] (logging paused, " .. _stuckCount .. " ticks frozen)")
        end

        -- Recovery: attempt to unstick the player at progressive intervals
        if _recoveryAttempts < MAX_RECOVERY
            and (_stuckCount == RECOVERY_TICK_1
              or _stuckCount == RECOVERY_TICK_2
              or _stuckCount == RECOVERY_TICK_3) then
            attemptRecovery(player)
        end
    else
        -- Player is NOT pressing movement keys and not moving — normal idle, reset
        _stuckCount = 0
        _freezeLogCount = 0
        _recoveryAttempts = 0
    end

    _prevX, _prevY = x, y
    _onPlayerMoveFired = false  -- reset for next tick
end

-- Register as high-priority core handler so we see state before other hooks
-- modify it. Priority 100 ensures FreezeLogger runs first among core handlers.
if UTCore.registerCoreHandler then
    UTCore.registerCoreHandler("FreezeLogger", onPlayerUpdate, { priority = 100 })
else
    if Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
end
if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end

-- Expose for testing
UTCore._freezeLoggerOnPlayerUpdate = onPlayerUpdate
UTCore._freezeLoggerOnPlayerMove = onPlayerMove
UTCore._freezeLoggerAttemptRecovery = attemptRecovery
UTCore._getFreezeLoggerStuckCount = function() return _stuckCount end
UTCore._getFreezeLoggerRecoveryAttempts = function() return _recoveryAttempts end
UTCore._resetFreezeLogger = function()
    _prevX, _prevY = nil, nil
    _stuckCount = 0
    _freezeLogCount = 0
    _onPlayerMoveFired = false
    _recoveryAttempts = 0
end
UTCore.FREEZE_RECOVERY_TICK_1 = RECOVERY_TICK_1
UTCore.FREEZE_RECOVERY_TICK_2 = RECOVERY_TICK_2
UTCore.FREEZE_RECOVERY_TICK_3 = RECOVERY_TICK_3
UTCore.FREEZE_MAX_RECOVERY = MAX_RECOVERY
