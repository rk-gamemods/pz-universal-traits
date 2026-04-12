-- UTCore_TickDispatch.lua
-- Central per-tick dispatch for Universal Traits.
--
-- ARCHITECTURE: Instead of 42+ independent OnPlayerUpdate handlers each making
-- their own Java interop calls, this module provides:
--   1. A SINGLE OnPlayerUpdate handler that builds a shared tick context ONCE
--   2. A registration API for trait handlers
--   3. Per-handler profiling with automatic spike detection
--
-- PERFORMANCE: With 50+ traits active, this eliminates ~200+ redundant Java
-- interop calls per tick (shouldSkipTick 40x->1x, getModData 30x->1x,
-- getStats 18x->1x, getPrimaryHandItem 17x->1x, spottedList iteration 3x->1x).

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
    -- Initialize perf slot
    if not _handlerPerf then _handlerPerf = {} end
    _handlerPerf[traitId] = { totalMs = 0, calls = 0, peakMs = 0 }
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

    -- Spotted list: iterate ONCE, pre-filter dead, pre-compute distances.
    -- This replaces 3+ independent iterations (bouncer, actionhero, scardycat).
    t.livingEnemies    = {}
    t.livingEnemyCount = 0
    t.totalSpotted     = 0
    pcall(function()
        local list = player:getSpottedList()
        local size = list:size()
        t.totalSpotted = size
        for i = 0, size - 1 do
            local enemy = list:get(i)
            if not enemy:isDead() then
                local n = t.livingEnemyCount + 1
                t.livingEnemyCount = n
                t.livingEnemies[n] = {
                    zombie = enemy,
                    dist   = player:DistTo(enemy),
                }
            end
        end
    end)

    return t
end

---------------------------------------------------------------------
-- Per-handler profiling
---------------------------------------------------------------------
local _handlerPerf = {}
local _dispatchPerf = {
    ticks      = 0,
    totalMs    = 0,
    peakMs     = 0,
    cacheMs    = 0,
    spikeCount = 0,
}
local REPORT_INTERVAL    = 300
local SPIKE_THRESHOLD_MS = 3.0

local function resetPerfCounters()
    for id, _ in pairs(_handlerPerf) do
        _handlerPerf[id] = { totalMs = 0, calls = 0, peakMs = 0 }
    end
    _dispatchPerf = {
        ticks      = 0,
        totalMs    = 0,
        peakMs     = 0,
        cacheMs    = 0,
        spikeCount = 0,
    }
end

local function dumpTraitPerfReport()
    local lines = {}
    local totalHandlerMs = 0
    for i = 1, _handlerCount do
        local h = _handlers[i]
        local p = _handlerPerf[h.id]
        if p and p.calls > 0 then
            local avg = p.totalMs / p.calls
            totalHandlerMs = totalHandlerMs + p.totalMs
            local flag = (p.peakMs >= SPIKE_THRESHOLD_MS) and " !" or "  "
            lines[#lines + 1] = string.format(
                "%s %s: avg=%.2fms peak=%.1fms calls=%d total=%.1fms",
                flag, h.id:match(":(.+)$") or h.id,
                avg, p.peakMs, p.calls, p.totalMs
            )
        end
    end

    local dp = _dispatchPerf
    local ticks = math.max(dp.ticks, 1)
    local avgTick = dp.totalMs / ticks
    local pctFrame = (avgTick / 16.7) * 100

    print(string.format(
        "[TRAITS] ===== TRAIT DISPATCH (%d handlers, %d ticks) =====",
        _handlerCount, dp.ticks
    ))
    print(string.format(
        "[TRAITS]   cache build: avg=%.2fms total=%.1fms",
        dp.cacheMs / ticks, dp.cacheMs
    ))
    for _, line in ipairs(lines) do
        print("[TRAITS]" .. line)
    end
    print(string.format(
        "[TRAITS] total: %.1fms over %d ticks (avg %.2fms/tick = %.1f%% of 16.7ms frame)",
        dp.totalMs, dp.ticks, avgTick, pctFrame
    ))
    print(string.format(
        "[TRAITS] peak tick: %.2fms (%.1f%% of frame) spikes(>%.1fms): %d",
        dp.peakMs, (dp.peakMs / 16.7) * 100, SPIKE_THRESHOLD_MS, dp.spikeCount
    ))

    resetPerfCounters()
end

---------------------------------------------------------------------
-- Central dispatch (ONE OnPlayerUpdate handler for ALL traits)
---------------------------------------------------------------------
local function centralDispatch(player)
    if not player then return end
    if _handlerCount == 0 then return end

    local dispatchStart = getTimestampMs()

    -- Build shared tick context ONCE
    local cacheStart = getTimestampMs()
    local tick = buildTickContext(player)
    local cacheMs = getTimestampMs() - cacheStart
    _dispatchPerf.cacheMs = _dispatchPerf.cacheMs + cacheMs

    -- Dead = skip everything
    if tick.shouldSkip then return end

    local inVehicle = tick.vehicle ~= nil
    local slowParts = nil

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
            local hStart = getTimestampMs()
            local ok, err = pcall(h.fn, player, tick)
            local hMs = getTimestampMs() - hStart

            -- Track per-handler timing
            local perf = _handlerPerf[h.id]
            if not perf then
                perf = { totalMs = 0, calls = 0, peakMs = 0 }
                _handlerPerf[h.id] = perf
            end
            perf.totalMs = perf.totalMs + hMs
            perf.calls   = perf.calls + 1
            if hMs > perf.peakMs then perf.peakMs = hMs end

            -- Collect slow handler names for spike log
            if hMs >= 1.0 then
                if not slowParts then slowParts = {} end
                slowParts[#slowParts + 1] = (h.id:match(":(.+)$") or h.id)
                    .. "=" .. string.format("%.1f", hMs) .. "ms"
            end

            if not ok then
                UTCore.diagLog("DISPATCH", "handler_error",
                    h.id .. ": " .. tostring(err))
            end
            end -- match
        end -- vehicle gate
    end

    -- Aggregate tick timing
    local totalMs = getTimestampMs() - dispatchStart
    local dp = _dispatchPerf
    dp.ticks   = dp.ticks + 1
    dp.totalMs = dp.totalMs + totalMs
    if totalMs > dp.peakMs then dp.peakMs = totalMs end

    -- Spike detection: immediate log with handler breakdown
    if totalMs >= SPIKE_THRESHOLD_MS then
        dp.spikeCount = dp.spikeCount + 1
        local detail = string.format("%.1fms cache=%.1fms enemies=%d",
            totalMs, cacheMs, tick.livingEnemyCount)
        if slowParts then
            detail = detail .. " slow: " .. table.concat(slowParts, ", ")
        end
        UTCore.diagLog("TICK", "SPIKE", detail)
    end

    -- Periodic report
    if dp.ticks >= REPORT_INTERVAL then
        dumpTraitPerfReport()
    end
end

Events.OnPlayerUpdate.Add(centralDispatch)
