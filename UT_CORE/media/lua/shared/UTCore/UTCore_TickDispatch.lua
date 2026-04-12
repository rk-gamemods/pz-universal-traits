-- UTCore_TickDispatch.lua
-- Central per-tick dispatch for Universal Traits.
--
-- ARCHITECTURE: Instead of 42+ independent OnPlayerUpdate handlers each making
-- their own Java interop calls, this module provides:
--   1. A SINGLE OnPlayerUpdate handler that builds a shared tick context ONCE
--   2. A registration API for trait handlers
--   3. Core handler dispatch for UT_CORE's own hooks (bleed, pain, freeze, etc.)
--   4. Active-only handler array: only traits the player actually has are iterated
--
-- PERFORMANCE (Phase 1+2+4):
--   Phase 1: Core handlers share tick context → eliminates ~50 redundant Java calls/tick
--   Phase 2: Active-only array → iterate 3-8 handlers instead of 42
--   Phase 4: Direct calls (no pcall) in production → eliminates pcall overhead per handler
--
-- PROFILING: External profiling via 00_ModProfiler. Internal per-handler
-- timing removed (v2) to eliminate ~40 getTimestampMs() Java calls/tick.

UTCore = UTCore or {}

---------------------------------------------------------------------
-- Trait handler registry
---------------------------------------------------------------------
local _handlers = {}
local _handlerCount = 0

--- Register a trait's per-tick handler.
-- Central dispatch calls hasTrait automatically (or skips it if active-only
-- array is built); the handler itself should NOT repeat that check.
--
-- @param traitId  string   full namespaced trait ID (used for hasTrait gate + perf key)
-- @param fn       function(player, tick)  the handler
-- @param opts     table    optional:
--   vehicleAware=true  — run even when player is in a vehicle
--   anyTrait={id,...}  — fire if player has ANY of these traits (for multi-tier traits)
--   throttle=N         — fire every Nth tick (0 = every tick). Dispatch manages counter.
--   heavy=true         — marks handler as expensive (inventory scan etc.).
--                         Heavy handlers are staggered so at most 1 runs per tick.
function UTCore.registerTickHandler(traitId, fn, opts)
    opts = opts or {}
    _handlerCount = _handlerCount + 1
    _handlers[_handlerCount] = {
        id           = traitId,
        fn           = fn,
        vehicleAware = opts.vehicleAware == true,
        anyTrait     = opts.anyTrait,
        throttle     = opts.throttle or 0,
        heavy        = opts.heavy == true,
        _offset      = 0,
    }
end

--- Return the current handler count (for testing/diagnostics).
function UTCore.getTickHandlerCount()
    return _handlerCount
end

---------------------------------------------------------------------
-- Active-only handler arrays (Phase 2 + Phase 3)
--
-- Built once per OnCreatePlayer (new game / save load).
-- Contains only the handlers whose trait the player actually has.
-- Split into light and heavy:
--   Light: run every tick (or at dispatch-managed throttle interval)
--   Heavy: staggered offsets guarantee max 1 heavy handler per tick
--
-- Eliminates 42-handler iteration + hasTrait gate on every tick.
---------------------------------------------------------------------
local _activeLight = nil
local _activeLightCount = 0
local _activeHeavy = nil
local _activeHeavyCount = 0

--- Rebuild the active handler arrays for a player.
--- Called on OnCreatePlayer and when traits change.
function UTCore.rebuildActiveHandlers(player)
    _activeLight = {}
    _activeLightCount = 0
    _activeHeavy = {}
    _activeHeavyCount = 0

    -- Pass 1: match traits, separate into light/heavy
    for i = 1, _handlerCount do
        local h = _handlers[i]
        local match = false
        if h.anyTrait then
            for _, tid in ipairs(h.anyTrait) do
                if UTCore.hasTrait(player, tid) then
                    match = true
                    break
                end
            end
        else
            match = UTCore.hasTrait(player, h.id)
        end
        if match then
            if h.heavy then
                _activeHeavyCount = _activeHeavyCount + 1
                _activeHeavy[_activeHeavyCount] = h
            else
                _activeLightCount = _activeLightCount + 1
                _activeLight[_activeLightCount] = h
            end
        end
    end

    -- Pass 2: assign staggered offsets for light handlers (by throttle group)
    local lightGroups = {}  -- [throttle] = { h1, h2, ... }
    for i = 1, _activeLightCount do
        local h = _activeLight[i]
        local t = h.throttle
        if t > 0 then
            if not lightGroups[t] then lightGroups[t] = {} end
            local g = lightGroups[t]
            g[#g + 1] = h
        end
    end
    for t, group in pairs(lightGroups) do
        local n = #group
        for idx = 1, n do
            group[idx]._offset = math.floor((idx - 1) * t / n)
        end
    end

    -- Pass 3: assign globally staggered offsets for heavy handlers
    -- Uses min throttle across all heavy handlers so no two fire on the same tick
    if _activeHeavyCount > 1 then
        local minThrottle = math.huge
        for i = 1, _activeHeavyCount do
            local t = _activeHeavy[i].throttle
            if t > 0 and t < minThrottle then minThrottle = t end
        end
        if minThrottle == math.huge then minThrottle = 30 end
        for i = 1, _activeHeavyCount do
            _activeHeavy[i]._offset = math.floor((i - 1) * minThrottle / _activeHeavyCount)
        end
    end
end

--- Return active handler count (testing/diagnostics).
function UTCore.getActiveHandlerCount()
    return _activeLightCount + _activeHeavyCount
end

--- Return active heavy handler count (testing/diagnostics).
function UTCore.getActiveHeavyCount()
    return _activeHeavyCount
end

---------------------------------------------------------------------
-- Tick context builder (called ONCE per frame)
---------------------------------------------------------------------
local _tickCount = 0
local _coreHandlersSorted = false

local function buildTickContext(player)
    _tickCount = _tickCount + 1
    local t = {}

    -- Tick counter for throttle checks
    t.tickCount = _tickCount

    -- Core state
    t.isDead    = player:isDead()
    t.vehicle   = player:getVehicle()
    t.shouldSkip = t.isDead  -- dead = always skip; vehicle handled per-handler

    -- Shared references (1 Java call each instead of N)
    t.modData    = player:getModData()
    t.stats      = player:getStats()
    t.bodyDamage = player:getBodyDamage()

    -- Position (used by FreezeLogger, ZombieCollision)
    t.x = player:getX()
    t.y = player:getY()
    t.z = player:getZ()

    -- Movement state
    t.isMoving    = player:isMoving()
    t.isSprinting = player:isSprinting()
    t.isRunning   = player:isRunning()

    -- Weapon state
    t.primaryWeapon   = player:getPrimaryHandItem()
    t.secondaryWeapon = player:getSecondaryHandItem()

    -- Animation state (bouncer freeze guard)
    t.isHostileAnim = player:isPerformingHostileAnimation()

    -- Spotted list: LAZY — built on first access via getLivingEnemies().
    -- Only 3 traits (bouncer, actionhero, scardycat) use enemy data;
    -- skip the pcall + Java list iteration + isDead/DistTo per enemy
    -- on every tick when those traits aren't active.
    t.livingEnemies    = nil  -- populated lazily
    t.livingEnemyCount = 0
    t.totalSpotted     = 0
    t._player          = player
    t._enemiesBuilt    = false

    return t
end

--- Build the enemy list on demand. Call from trait handlers that need it.
--- @param tick table  the tick context returned by buildTickContext
local function buildEnemyList(tick)
    if tick._enemiesBuilt then return end
    tick._enemiesBuilt = true
    tick.livingEnemies = {}
    local player = tick._player
    pcall(function()
        local list = player:getSpottedList()
        local size = list:size()
        tick.totalSpotted = size
        for i = 0, size - 1 do
            local enemy = list:get(i)
            if not enemy:isDead() then
                local n = tick.livingEnemyCount + 1
                tick.livingEnemyCount = n
                tick.livingEnemies[n] = {
                    zombie = enemy,
                    dist   = player:DistTo(enemy),
                }
            end
        end
    end)
end

--- Public accessor for lazy enemy list.
--- Trait handlers should call UTCore.getLivingEnemies(tick) instead of
--- accessing tick.livingEnemies directly.
function UTCore.getLivingEnemies(tick)
    if not tick._enemiesBuilt then
        buildEnemyList(tick)
    end
    return tick.livingEnemies, tick.livingEnemyCount
end

---------------------------------------------------------------------
-- Central dispatch (ONE OnPlayerUpdate handler for ALL of UTCore)
---------------------------------------------------------------------
local function centralDispatch(player)
    if not player then return end

    -- Sort core handlers by priority once (highest first)
    if not _coreHandlersSorted and UTCore._coreHandlerCount > 1 then
        table.sort(UTCore._coreHandlers, function(a, b)
            return (a.priority or 0) > (b.priority or 0)
        end)
        _coreHandlersSorted = true
    end

    -- Build shared tick context ONCE
    local tick = buildTickContext(player)

    -- Dead = skip everything
    if tick.shouldSkip then return end

    local debugMode = UTCore._debugDispatch
    local tc = _tickCount

    -- ── Core handlers ────────────────────────────────────────────
    local coreCount = UTCore._coreHandlerCount
    if coreCount > 0 then
        local coreHandlers = UTCore._coreHandlers
        for i = 1, coreCount do
            local h = coreHandlers[i]
            if h.throttle == 0 or tc % h.throttle == 0 then
                if debugMode then
                    local ok, err = pcall(h.fn, player, tick)
                    if not ok and UTCore.diagLog then
                        UTCore.diagLog("DISPATCH", "core_handler_error",
                            h.id .. ": " .. tostring(err))
                    end
                else
                    h.fn(player, tick)
                end
            end
        end
    end

    -- ── Trait handlers ───────────────────────────────────────────
    local inVehicle = tick.vehicle ~= nil

    if _activeLight then
        -- Phase 2+3: active-only arrays with dispatch-managed throttle

        -- Light handlers: all fire (subject to throttle + vehicle gate)
        for i = 1, _activeLightCount do
            local h = _activeLight[i]
            if not inVehicle or h.vehicleAware then
                if h.throttle == 0 or (tc + h._offset) % h.throttle == 0 then
                    if debugMode then
                        local ok, err = pcall(h.fn, player, tick)
                        if not ok and UTCore.diagLog then
                            UTCore.diagLog("DISPATCH", "handler_error",
                                h.id .. ": " .. tostring(err))
                        end
                    else
                        h.fn(player, tick)
                    end
                end
            end
        end

        -- Heavy handlers: staggered offsets guarantee max 1 per tick
        for i = 1, _activeHeavyCount do
            local h = _activeHeavy[i]
            if not inVehicle or h.vehicleAware then
                if h.throttle == 0 or (tc + h._offset) % h.throttle == 0 then
                    if debugMode then
                        local ok, err = pcall(h.fn, player, tick)
                        if not ok and UTCore.diagLog then
                            UTCore.diagLog("DISPATCH", "handler_error",
                                h.id .. ": " .. tostring(err))
                        end
                    else
                        h.fn(player, tick)
                    end
                end
            end
        end
    else
        -- Fallback: full loop with trait gate (before rebuildActiveHandlers)
        for i = 1, _handlerCount do
            local h = _handlers[i]
            -- Dispatch-managed throttle (offset defaults to 0 in fallback)
            if h.throttle > 0 and (tc + (h._offset or 0)) % h.throttle ~= 0 then
                -- skip: not this handler's throttle tick
            elseif inVehicle and not h.vehicleAware then
                -- skip
            else
                local match = false
                if h.anyTrait then
                    for _, tid in ipairs(h.anyTrait) do
                        if UTCore.hasTrait(player, tid) then
                            match = true
                            break
                        end
                    end
                else
                    match = UTCore.hasTrait(player, h.id)
                end
                if match then
                    if debugMode then
                        local ok, err = pcall(h.fn, player, tick)
                        if not ok and UTCore.diagLog then
                            UTCore.diagLog("DISPATCH", "handler_error",
                                h.id .. ": " .. tostring(err))
                        end
                    else
                        h.fn(player, tick)
                    end
                end
            end
        end
    end
end

Events.OnPlayerUpdate.Add(centralDispatch)

-- Build active handler array on character creation / save load
if not UTCore._dispatchCreatePlayerRegistered then
    local function onCreatePlayerDispatch(_playerIndex, player)
        if not player then return end
        UTCore.rebuildActiveHandlers(player)
    end
    if Events and Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayerDispatch)
    end
    UTCore._dispatchCreatePlayerRegistered = true
end
