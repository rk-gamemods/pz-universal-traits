-- UTCore_Events.lua
-- Centralized event listener registration and timer dispatcher.
-- Phase 2 implementation.

UTCore = UTCore or {}
UTCore._periodicHandlers = UTCore._periodicHandlers or {}

local function periodicHandlerKey(traitId, intervalEvent)
    return traitId .. "::" .. intervalEvent
end

-- Registers a periodic handler for a trait.
-- traitId:       string key, e.g. "UT_depressive"
-- intervalEvent: one of "EveryOneMinute", "EveryTenMinutes", "EveryHours", "OnPlayerUpdate"
-- handlerFn:     function(player) called on each event tick
function UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)
    local key = periodicHandlerKey(traitId, intervalEvent)

    -- Idempotent: skip if already registered for this traitId
    if UTCore._periodicHandlers[key] then
        return
    end

    -- Build the wrapped function that resolves the player at call time
    local wrappedFn = function()
        if getPlayer then
            handlerFn(getPlayer())
        end
    end

    UTCore._periodicHandlers[key] = {
        traitId   = traitId,
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
function UTCore.unregisterPeriodicHandler(traitId, intervalEvent)
    local keys = {}

    if intervalEvent then
        keys[1] = periodicHandlerKey(traitId, intervalEvent)
    else
        local prefix = traitId .. "::"
        for key in pairs(UTCore._periodicHandlers) do
            if key:sub(1, #prefix) == prefix then
                keys[#keys + 1] = key
            end
        end
    end

    for _, key in ipairs(keys) do
        local entry = UTCore._periodicHandlers[key]
        if entry and Events then
            Events[entry.event].Remove(entry.wrapped)
        end
        UTCore._periodicHandlers[key] = nil
    end
end
