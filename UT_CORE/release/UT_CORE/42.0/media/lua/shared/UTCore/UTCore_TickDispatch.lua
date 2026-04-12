-- UTCore_TickDispatch.lua
-- Central per-tick dispatch for Universal Traits.
--
-- ARCHITECTURE: Instead of 42+ independent OnPlayerUpdate handlers each making
-- their own Java interop calls, this module provides:
--   1. A SINGLE OnPlayerUpdate handler that builds a shared tick context ONCE
--   2. A registration API for trait handlers
--
-- PERFORMANCE: With 50+ traits active, this eliminates ~200+ redundant Java
-- interop calls per tick (shouldSkipTick 40x->1x, getModData 30x->1x,
-- getStats 18x->1x, getPrimaryHandItem 17x->1x, spottedList iteration 3x->1x).
--
-- PROFILING: External profiling via 00_ModProfiler. Internal per-handler
-- timing removed (v2) to eliminate ~40 getTimestampMs() Java calls/tick.

UTCore = UTCore or {}

---------------------------------------------------------------------
-- Handler registry
---------------------------------------------------------------------
local _handlers = {}
local _handlerCount = 0

--- Register a trait's per-tick handler.
-- Central dispatch calls shouldSkipTick and hasTrait automatically;
-- the handler itself should NOT repeat those checks.
--
-- @param traitId  string   full namespaced trait ID (used for hasTrait gate + perf key)
-- @param fn       function(player, tick)  the handler
-- @param opts     table    optional:
--   vehicleAware=true  — run even when player is in a vehicle
--   anyTrait={id,...}  — fire if player has ANY of these traits (for multi-tier traits)
function UTCore.registerTickHandler(traitId, fn, opts)
    opts = opts or {}
    _handlerCount = _handlerCount + 1
    _handlers[_handlerCount] = {
        id           = traitId,
        fn           = fn,
        vehicleAware = opts.vehicleAware == true,
        anyTrait     = opts.anyTrait,
    }
end

--- Return the current handler count (for testing/diagnostics).
function UTCore.getTickHandlerCount()
    return _handlerCount
end

---------------------------------------------------------------------
-- Tick context builder (called ONCE per frame)
---------------------------------------------------------------------
local function buildTickContext(player)
    local t = {}

    -- Core state
    t.isDead    = player:isDead()
    t.vehicle   = player:getVehicle()
    t.shouldSkip = t.isDead  -- dead = always skip; vehicle handled per-handler

    -- Shared references (1 Java call each instead of N)
    t.modData    = player:getModData()
    t.stats      = player:getStats()
    t.bodyDamage = player:getBodyDamage()

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
-- Central dispatch (ONE OnPlayerUpdate handler for ALL traits)
---------------------------------------------------------------------
local function centralDispatch(player)
    if not player then return end
    if _handlerCount == 0 then return end

    -- Build shared tick context ONCE
    local tick = buildTickContext(player)

    -- Dead = skip everything
    if tick.shouldSkip then return end

    local inVehicle = tick.vehicle ~= nil

    for i = 1, _handlerCount do
        local h = _handlers[i]

        -- Vehicle gate: skip non-vehicle-aware handlers when in vehicle
        if inVehicle and not h.vehicleAware then
            -- skip
        else
            -- Trait gate: anyTrait means "fire if player has ANY of these"
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
                local ok, err = pcall(h.fn, player, tick)
                if not ok and UTCore.diagLog then
                    UTCore.diagLog("DISPATCH", "handler_error",
                        h.id .. ": " .. tostring(err))
                end
            end -- match
        end -- vehicle gate
    end
end

Events.OnPlayerUpdate.Add(centralDispatch)
