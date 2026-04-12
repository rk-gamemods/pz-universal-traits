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
local FRAME_BUDGET_MS      = 16.67 -- 60fps frame budget
local FRAME_WARN_PCT       = 50    -- warn if UT overhead exceeds this % of frame

-- Per-tick aggregate tracking
local _frameMs = {}        -- array of per-tick total UT ms values this window
local _heavyFrames = 0     -- frames where UT exceeded FRAME_WARN_PCT of budget
local _peakFrameMs = 0     -- single-frame peak UT overhead this window
local _currentTickMs = 0   -- accumulator for current tick
local FRAME_BUDGET_MS      = 16.67 -- 60fps frame budget
local FRAME_WARN_PCT       = 50    -- warn if UT overhead exceeds this % of frame

-- Per-tick aggregate tracking
local _frameMs = {}        -- array of per-tick total UT ms values this window
local _heavyFrames = 0     -- frames where UT exceeded FRAME_WARN_PCT of budget
local _peakFrameMs = 0     -- single-frame peak UT overhead this window
local _currentTickMs = 0   -- accumulator for current tick

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

    -- Accumulate into current tick total
    _currentTickMs = _currentTickMs + dt
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
    _frameMs = {}
    _heavyFrames = 0
    _peakFrameMs = 0
    _currentTickMs = 0
end

--- Force an immediate performance report to console.
--- @param force boolean  if true, reports even when nothing is slow
function UTCore.dumpPerfReport(force)
    local totalAllMs = 0
    local hookCount = 0
    local hookLines = {}
    local warnCount = 0

    for name, stats in pairs(_perfStats) do
        if stats.count > 0 then
            hookCount = hookCount + 1
            local avgMs = stats.totalMs / stats.count
            totalAllMs = totalAllMs + stats.totalMs

            local isWarn = (avgMs >= PERF_WARN_AVG_MS or stats.peakMs >= PERF_WARN_PEAK_MS)
            if isWarn then warnCount = warnCount + 1 end

            hookLines[#hookLines + 1] = string.format(
                "  %s%s: avg=%.2fms peak=%.1fms calls=%d total=%.1fms",
                isWarn and "! " or "  ",
                name, avgMs, stats.peakMs, stats.count, stats.totalMs
            )
        end
    end

    -- Frame budget analysis
    local avgMsPerTick = totalAllMs / math.max(1, PERF_REPORT_INTERVAL)
    local framePct = (avgMsPerTick / FRAME_BUDGET_MS) * 100
    local peakPct = (_peakFrameMs / FRAME_BUDGET_MS) * 100
    local shouldReport = force or warnCount > 0
        or framePct >= FRAME_WARN_PCT or _heavyFrames > 0

    if shouldReport then
        print("[PERF] ===== UT OVERHEAD (" .. hookCount .. " hooks, "
            .. PERF_REPORT_INTERVAL .. " ticks) =====")
        table.sort(hookLines)
        for _, line in ipairs(hookLines) do
            print("[PERF]" .. line)
        end
        print("[PERF] total: " .. string.format("%.1f", totalAllMs)
            .. "ms over " .. PERF_REPORT_INTERVAL .. " ticks"
            .. " (avg " .. string.format("%.2f", avgMsPerTick)
            .. "ms/tick = " .. string.format("%.1f%%", framePct)
            .. " of " .. string.format("%.1f", FRAME_BUDGET_MS) .. "ms frame)")
        if _peakFrameMs > 0 then
            print("[PERF] peak frame: " .. string.format("%.2f", _peakFrameMs)
                .. "ms (" .. string.format("%.1f%%", peakPct) .. " of frame)")
        end
        if _heavyFrames > 0 then
            print("[PERF] WARNING: " .. _heavyFrames .. " heavy frames (>"
                .. FRAME_WARN_PCT .. "% of " .. string.format("%.1f", FRAME_BUDGET_MS)
                .. "ms budget) in last " .. PERF_REPORT_INTERVAL .. " ticks")
        end

        UTCore.diagLog("PERF", "report",
            hookCount .. " hooks, totalMs=" .. string.format("%.1f", totalAllMs)
            .. " avgPct=" .. string.format("%.1f", framePct)
            .. " peakFrame=" .. string.format("%.2f", _peakFrameMs)
            .. " heavy=" .. _heavyFrames)
    end

    -- Reset for next window
    for _, stats in pairs(_perfStats) do
        stats.totalMs = 0
        stats.count = 0
        stats.peakMs = 0
    end
    _perfTick = 0
    _frameMs = {}
    _heavyFrames = 0
    _peakFrameMs = 0
end

---------------------------------------------------------------------------
-- Periodic perf reporting (OnPlayerUpdate handler)
-- Registered LAST among UT hooks so it runs after all profiled handlers,
-- captures the per-tick total, and triggers the periodic report.
---------------------------------------------------------------------------
local function onPlayerUpdate(player)
    if not player then return end

    -- Close out current tick: record aggregate and check for heavy frames
    if _currentTickMs > 0 then
        _frameMs[#_frameMs + 1] = _currentTickMs
        if _currentTickMs > _peakFrameMs then
            _peakFrameMs = _currentTickMs
        end
        local pct = (_currentTickMs / FRAME_BUDGET_MS) * 100
        if pct >= FRAME_WARN_PCT then
            _heavyFrames = _heavyFrames + 1
        end
    end
    _currentTickMs = 0

    _perfTick = _perfTick + 1
    if _perfTick >= PERF_REPORT_INTERVAL then
        UTCore.dumpPerfReport(false)
    end
end

-- Perf reporting OnPlayerUpdate removed (v2): external profiling via
-- 00_ModProfiler eliminates the need for an always-on internal tick counter.
-- The perfEnter/perfExit/dumpPerfReport API remains available for manual use.

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

--- Wrap a handler that takes variable arguments (hit events, XP events, etc.).
--- Same as profiledHandler but passes all args through.
--- Usage: Events.OnWeaponHitCharacter.Add(UTCore.profiledHandlerV("FractureHook", fn))
--- @param name string  unique hook name for perf stats
--- @param fn   function(...)  the original handler
--- @return function  wrapped handler with profiling
function UTCore.profiledHandlerV(name, fn)
    return function(...)
        UTCore.perfEnter(name)
        local ok, err = pcall(fn, ...)
        UTCore.perfExit(name)
        if not ok then
            UTCore.diagLog("PERF", "hook_error", name .. ": " .. tostring(err))
        end
    end
end

--- Get frame budget tracking state (for testing).
function UTCore.getFrameBudgetState()
    return {
        heavyFrames = _heavyFrames,
        peakFrameMs = _peakFrameMs,
        currentTickMs = _currentTickMs,
        frameCount = #_frameMs,
    }
end
