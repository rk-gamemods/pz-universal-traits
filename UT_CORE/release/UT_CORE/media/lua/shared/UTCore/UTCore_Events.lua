-- UTCore_Events.lua
-- Centralized event listener registration and timer dispatcher.
-- Phase 2 implementation.

UTCore = UTCore or {}
UTCore._periodicHandlers = UTCore._periodicHandlers or {}

-- Registers a periodic handler for a trait.
-- traitId:       string key, e.g. "UT_depressive"
-- intervalEvent: one of "EveryOneMinute", "EveryTenMinutes", "EveryHours", "OnPlayerUpdate"
-- handlerFn:     function(player) called on each event tick
function UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)
    -- Idempotent: skip if already registered for this traitId
    if UTCore._periodicHandlers[traitId] then
        return
    end

    -- Build the wrapped function that resolves the player at call time
    local wrappedFn = function()
        if getPlayer then
            handlerFn(getPlayer())
        end
    end

    UTCore._periodicHandlers[traitId] = {
        event     = intervalEvent,
        fn        = handlerFn,
        wrapped   = wrappedFn,
    }

    -- Register with PZ Events system when available
    if Events then
        Events[intervalEvent].Add(wrappedFn)
    end
end

-- Unregisters a previously registered periodic handler.
function UTCore.unregisterPeriodicHandler(traitId)
    local entry = UTCore._periodicHandlers[traitId]
    if not entry then return end

    -- Remove from PZ Events system when available
    if Events then
        Events[entry.event].Remove(entry.wrapped)
    end

    UTCore._periodicHandlers[traitId] = nil
end
