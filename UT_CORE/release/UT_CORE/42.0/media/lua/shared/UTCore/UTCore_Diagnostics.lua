-- UTCore_Diagnostics.lua
-- Ring buffer event log + per-hook performance profiler.
--
-- RING BUFFER: fixed-size circular log of recent events. Auto-dumps to
-- console when a freeze is detected to show the exact sequence of events
-- leading up to it. Avoids accumulating thousands of log entries.
--
-- PERFORMANCE PROFILER: per-hook timing to identify stutter culprits.
-- Uses getTimestampMs() (ms resolution). Over PERF_REPORT_INTERVAL ticks,
-- even sub-ms handlers accumulate measurable totals. Reports via [PERF]
-- console lines every reporting window.
--
-- USAGE:
--   UTCore.diagLog("source", "event", "optional details")
--   UTCore.perfEnter("hookName")
--   ... hook body ...
--   UTCore.perfExit("hookName")
--   UTCore.dumpDiagnostics()      -- manual dump
--   UTCore.dumpPerfReport(true)   -- force immediate perf report

UTCore = UTCore or {}

---------------------------------------------------------------------------
-- Ring Buffer
---------------------------------------------------------------------------
local RING_SIZE = 200

local _ring = {}
local _ringHead = 0
local _ringCount = 0

local function ringPush(entry)
    _ringHead = (_ringHead % RING_SIZE) + 1
    _ring[_ringHead] = entry
    if _ringCount < RING_SIZE then _ringCount = _ringCount + 1 end
end

--- Log an event to the ring buffer.
--- @param source string  e.g. "ZCollision", "FreezeLog", "bouncer"
--- @param event  string  e.g. "setBumpedChr", "blockMovement", "recovery"
--- @param data   string  optional details
function UTCore.diagLog(source, event, data)
    ringPush({
        t   = getTimestampMs(),
        src = tostring(source),
        evt = tostring(event),
        dat = data and tostring(data) or "",
    })
end

--- Dump the ring buffer contents to console.
--- Auto-called on freeze detection; also callable manually.
function UTCore.dumpDiagnostics()
    if _ringCount == 0 then
        print("[DIAG] Ring buffer empty")
        return
    end

    print("[DIAG] ===== RING BUFFER DUMP (" .. _ringCount .. " entries) =====")

    -- Walk from oldest to newest
    local startIdx
    if _ringCount < RING_SIZE then
        startIdx = 1
    else
        startIdx = (_ringHead % RING_SIZE) + 1
    end

    for i = 0, _ringCount - 1 do
        local idx = ((startIdx - 1 + i) % RING_SIZE) + 1
        local e = _ring[idx]
        if e then
            print(string.format("[DIAG] t=%d %s | %s | %s",
                e.t or 0, e.src, e.evt, e.dat))
        end
    end

    print("[DIAG] ===== END RING BUFFER =====")
end

--- Get current ring buffer count (for testing).
function UTCore.diagRingCount()
    return _ringCount
end

--- Get a specific ring entry by age (0 = newest, 1 = second newest, etc.)
--- Returns nil if index out of range.
function UTCore.diagRingGet(age)
    if age < 0 or age >= _ringCount then return nil end
    local idx = ((_ringHead - age - 1) % RING_SIZE) + 1
    return _ring[idx]
end

--- Reset ring buffer (for testing).
function UTCore.diagResetRing()
    _ring = {}
    _ringHead = 0
    _ringCount = 0
end

---------------------------------------------------------------------------
-- Performance Profiler
---------------------------------------------------------------------------
local _perfStats = {}      -- { name => { totalMs, count, peakMs } }
local _perfActive = {}     -- { name => startMs } (current enter without exit)
local _perfTick = 0

local PERF_REPORT_INTERVAL = 300  -- ticks between reports (~5 sec at 60fps)
local PERF_WARN_AVG_MS     = 0.5  -- warn if per-call average > 0.5ms
local PERF_WARN_PEAK_MS    = 3.0  -- warn if any single call > 3ms

--- Call before a hook executes.
function UTCore.perfEnter(name)
    _perfActive[name] = getTimestampMs()
end

--- Call after a hook finishes. Records elapsed time.
function UTCore.perfExit(name)
    local startMs = _perfActive[name]
    if not startMs then return end
    _perfActive[name] = nil

    local dt = getTimestampMs() - startMs

    local stats = _perfStats[name]
    if not stats then
        stats = { totalMs = 0, count = 0, peakMs = 0 }
        _perfStats[name] = stats
    end

    stats.totalMs = stats.totalMs + dt
    stats.count = stats.count + 1
    if dt > stats.peakMs then stats.peakMs = dt end
end

--- Get raw perf stats table (for testing).
function UTCore.getPerfStats()
    return _perfStats
end

--- Reset all performance stats (for testing).
function UTCore.resetPerfStats()
    _perfStats = {}
    _perfTick = 0
    _perfActive = {}
end

--- Force an immediate performance report to console.
--- @param force boolean  if true, reports even when nothing is slow
function UTCore.dumpPerfReport(force)
    local totalAllMs = 0
    local hookCount = 0
    local warnings = {}

    for name, stats in pairs(_perfStats) do
        if stats.count > 0 then
            hookCount = hookCount + 1
            local avgMs = stats.totalMs / stats.count
            totalAllMs = totalAllMs + stats.totalMs

            if avgMs >= PERF_WARN_AVG_MS or stats.peakMs >= PERF_WARN_PEAK_MS or force then
                warnings[#warnings + 1] = string.format(
                    "  %s: avg=%.2fms peak=%.1fms calls=%d total=%.1fms",
                    name, avgMs, stats.peakMs, stats.count, stats.totalMs
                )
            end
        end
    end

    if #warnings > 0 or force then
        print("[PERF] ===== HOOK TIMING (" .. hookCount .. " hooks, "
            .. PERF_REPORT_INTERVAL .. " ticks) =====")
        table.sort(warnings)
        for _, w in ipairs(warnings) do
            print("[PERF]" .. w)
        end
        print("[PERF] total UT overhead: " .. string.format("%.1f", totalAllMs)
            .. "ms over " .. PERF_REPORT_INTERVAL .. " ticks"
            .. " (avg " .. string.format("%.2f", totalAllMs / math.max(1, PERF_REPORT_INTERVAL))
            .. "ms/tick)")

        UTCore.diagLog("PERF", "report",
            hookCount .. " hooks, totalMs=" .. string.format("%.1f", totalAllMs))
    end

    -- Reset for next window
    for _, stats in pairs(_perfStats) do
        stats.totalMs = 0
        stats.count = 0
        stats.peakMs = 0
    end
    _perfTick = 0
end

---------------------------------------------------------------------------
-- Periodic perf reporting (OnPlayerUpdate handler)
---------------------------------------------------------------------------
local function onPlayerUpdate(player)
    if not player then return end
    _perfTick = _perfTick + 1
    if _perfTick >= PERF_REPORT_INTERVAL then
        UTCore.dumpPerfReport(false)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

---------------------------------------------------------------------------
-- Profiled handler wrapper
---------------------------------------------------------------------------
--- Wrap a handler function with automatic perfEnter/perfExit timing.
--- Usage: Events.OnPlayerUpdate.Add(UTCore.profiledHandler("BleedHook", fn))
--- @param name string  unique hook name for perf stats
--- @param fn   function(player)  the original handler
--- @return function  wrapped handler with profiling
function UTCore.profiledHandler(name, fn)
    return function(player)
        UTCore.perfEnter(name)
        local ok, err = pcall(fn, player)
        UTCore.perfExit(name)
        if not ok then
            UTCore.diagLog("PERF", "hook_error", name .. ": " .. tostring(err))
        end
    end
end
