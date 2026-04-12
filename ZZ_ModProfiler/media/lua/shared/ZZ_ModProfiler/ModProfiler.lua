-- ModProfiler.lua
-- Universal mod callback profiler for Project Zomboid Build 42.
--
-- HOW IT WORKS: Intercepts Events.X.Add() for high-impact events and wraps
-- each incoming callback with a timing closure. Periodically dumps a report
-- of the top offenders sorted by total time consumed.
--
-- REQUIREMENT: This mod must be FIRST in your mod load order so it intercepts
-- registrations from all other mods. Callbacks registered before this mod
-- loads cannot be profiled.
--
-- OVERHEAD: ~0.002ms per wrapped callback invocation (two getTimestampMs()
-- calls). Safe for per-frame events. Per-entity events (OnZombieUpdate) are
-- excluded by default to avoid distorting results.

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

-- Events to profile. Per-frame events are safe. Per-entity events
-- (OnZombieUpdate, OnAIStateExecute, OnNPCSurvivorUpdate) are excluded
-- by default because wrapping overhead multiplied by entity count
-- would itself cause lag.
local PROFILED_EVENTS = {
    -- Per-frame (highest impact)
    "OnTick",
    "OnTickEvenPaused",
    "OnPlayerUpdate",
    "OnRenderUpdate",
    "OnRenderTick",
    "OnPreUIDraw",
    "OnPostUIDraw",
    -- Periodic / burst
    "EveryOneMinute",
    "EveryTenMinutes",
    "EveryHours",
    "LoadGridsquare",
    "ReuseGridsquare",
    -- Collision / movement
    "OnCharacterCollide",
    "OnPlayerMove",
    -- Game lifecycle (startup lag)
    "OnGameStart",
    "OnGameBoot",
    "OnCreatePlayer",
    "OnInitWorld",
    "OnPreMapLoad",
    "OnPostMapLoad",
    -- Climate / weather
    "OnClimateTick",
    -- Container / inventory
    "OnRefreshInventoryWindowContainers",
    "OnFillInventoryObjectContextMenu",
    "OnFillWorldObjectContextMenu",
}

local REPORT_INTERVAL    = 300  -- ticks between reports
local SPIKE_THRESHOLD_MS = 3    -- immediate log for callbacks above this

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------
local _profileData     = {}   -- [eventName][callbackId] = { file, line, totalMs, calls, peakMs }
local _callbackId      = 0
local _tickCount       = 0
local _originalAdds    = {}   -- [eventName] = original Add function
local _originalRemoves = {}   -- [eventName] = original Remove function
local _origToWrapper   = {}   -- original callback → wrapper
local _wrapperToOrig   = {}   -- wrapper → original callback
local _interceptedCount = 0

---------------------------------------------------------------------------
-- Interceptor installation
---------------------------------------------------------------------------
local function interceptEvent(eventName)
    local eventTable = Events[eventName]
    if not eventTable then return end

    local origAdd = eventTable.Add
    local origRemove = eventTable.Remove
    if not origAdd then return end

    _originalAdds[eventName] = origAdd
    _originalRemoves[eventName] = origRemove
    _profileData[eventName] = {}

    -- Intercept Add: wrap each callback with timing
    eventTable.Add = function(callback)
        -- Capture source attribution BEFORE wrapping
        local sourceFile = "unknown"
        local sourceLine = 0
        pcall(function()
            sourceFile = getFilenameOfClosure(callback) or "unknown"
            sourceLine = getFirstLineOfClosure(callback) or 0
        end)

        _callbackId = _callbackId + 1
        local id = _callbackId
        local perfEntry = {
            file    = sourceFile,
            line    = sourceLine,
            totalMs = 0,
            calls   = 0,
            peakMs  = 0,
        }
        _profileData[eventName][id] = perfEntry

        -- Timed wrapper
        local wrapped = function(...)
            local start = getTimestampMs()
            callback(...)
            local elapsed = getTimestampMs() - start
            perfEntry.calls   = perfEntry.calls + 1
            perfEntry.totalMs = perfEntry.totalMs + elapsed
            if elapsed > perfEntry.peakMs then
                perfEntry.peakMs = elapsed
            end
            if elapsed >= SPIKE_THRESHOLD_MS then
                print(string.format(
                    "[MODPROFILER] SPIKE %s: %dms — %s:%d",
                    eventName, elapsed, sourceFile, sourceLine
                ))
            end
        end

        _origToWrapper[callback] = wrapped
        _wrapperToOrig[wrapped]  = callback
        origAdd(wrapped)
    end

    -- Intercept Remove: translate original → wrapper before removing
    if origRemove then
        eventTable.Remove = function(callback)
            local wrapper = _origToWrapper[callback]
            if wrapper then
                origRemove(wrapper)
                _origToWrapper[callback] = nil
                _wrapperToOrig[wrapper]  = nil
            else
                origRemove(callback)
            end
        end
    end

    _interceptedCount = _interceptedCount + 1
end

-- Install interceptors for all configured events
for _, eventName in ipairs(PROFILED_EVENTS) do
    interceptEvent(eventName)
end

---------------------------------------------------------------------------
-- Periodic report (fires on OnTick)
---------------------------------------------------------------------------
local function dumpReport()
    print("[MODPROFILER] ===== CALLBACK PROFILER REPORT (" .. REPORT_INTERVAL .. " ticks) =====")

    local entries = {}
    local grandTotalMs = 0

    for eventName, callbacks in pairs(_profileData) do
        for id, perf in pairs(callbacks) do
            if perf.calls > 0 then
                grandTotalMs = grandTotalMs + perf.totalMs
                entries[#entries + 1] = {
                    event = eventName,
                    file  = perf.file,
                    line  = perf.line,
                    avg   = perf.totalMs / perf.calls,
                    peak  = perf.peakMs,
                    calls = perf.calls,
                    total = perf.totalMs,
                }
            end
        end
    end

    -- Sort by total time descending (biggest offenders first)
    table.sort(entries, function(a, b) return a.total > b.total end)

    if #entries == 0 then
        print("[MODPROFILER]   (no callbacks fired)")
    else
        local showCount = math.min(#entries, 25)
        for i = 1, showCount do
            local e = entries[i]
            local flag = e.peak >= SPIKE_THRESHOLD_MS and "!" or " "
            print(string.format(
                "[MODPROFILER] %s %-20s | %-60s:%d | avg=%.1fms peak=%dms calls=%d total=%dms",
                flag, e.event, e.file, e.line, e.avg, e.peak, e.calls, e.total
            ))
        end
        if #entries > showCount then
            print(string.format("[MODPROFILER]   ... and %d more callbacks", #entries - showCount))
        end
    end

    print(string.format(
        "[MODPROFILER] ===== GRAND TOTAL: %dms across %d active callbacks =====",
        grandTotalMs, #entries
    ))

    -- Reset counters for next interval
    for eventName, callbacks in pairs(_profileData) do
        for id, perf in pairs(callbacks) do
            perf.totalMs = 0
            perf.calls   = 0
            perf.peakMs  = 0
        end
    end
end

-- Register the report tick handler using the already-intercepted OnTick.Add
Events.OnTick.Add(function()
    _tickCount = _tickCount + 1
    if _tickCount >= REPORT_INTERVAL then
        _tickCount = 0
        dumpReport()
    end
end)

print(string.format(
    "[MODPROFILER] Installed interceptors for %d/%d events (%d callbacks wrapped so far)",
    _interceptedCount, #PROFILED_EVENTS, _callbackId
))
