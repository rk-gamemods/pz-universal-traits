-- UTCore_Events.lua
-- Centralized event listener registration and timer dispatcher.
-- Phase 2 implementation.

UTCore = UTCore or {}
UTCore._periodicHandlers = UTCore._periodicHandlers or {}

local function periodicHandlerKey(traitId, intervalEvent)
    return traitId .. "::" .. intervalEvent
end

local function requireString(value, name)
    if type(value) ~= "string" or value == "" then
        error("UTCore periodic handler " .. name .. " must be a non-empty string", 3)
    end
end

local function eventContract(intervalEvent)
    if type(Events) ~= "table" then
        error("UTCore periodic handler Events table is unavailable", 3)
    end

    local event = Events[intervalEvent]
    if type(event) ~= "table" then
        error("UTCore periodic handler event is unavailable: " .. intervalEvent, 3)
    end
    if type(event.Add) ~= "function" then
        error("UTCore periodic handler event Add is not callable: " .. intervalEvent, 3)
    end
    if type(event.Remove) ~= "function" then
        error("UTCore periodic handler event Remove is not callable: " .. intervalEvent, 3)
    end

    return event.Add, event.Remove
end

local function removeEntry(key, entry)
    local remove = entry.remove
    if type(remove) ~= "function" then
        local _, currentRemove = eventContract(entry.event)
        remove = currentRemove
    end

    remove(entry.wrapped)
    UTCore._periodicHandlers[key] = nil
end

-- Registers a periodic handler for a trait.
-- traitId:       string key, e.g. "UT_depressive"
-- intervalEvent: one of "EveryOneMinute", "EveryTenMinutes", "EveryHours", "OnPlayerUpdate"
-- handlerFn:     function(player) called on each event tick
function UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)
    requireString(traitId, "traitId")
    requireString(intervalEvent, "intervalEvent")
    if type(handlerFn) ~= "function" then
        error("UTCore periodic handler handlerFn must be callable", 2)
    end

    local key = periodicHandlerKey(traitId, intervalEvent)
    local add, remove = eventContract(intervalEvent)
    local existing = UTCore._periodicHandlers[key]

    -- Identical duplicate registration is a no-op. A reload or replacement
    -- removes the exact previously registered closure before adding the new one.
    if existing then
        if existing.fn == handlerFn and existing.event == intervalEvent then
            return false
        end
        removeEntry(key, existing)
    end

    -- Build the wrapped function that resolves the player at call time
    local wrappedFn = function()
        if type(getPlayer) ~= "function" then
            error("UTCore periodic handler getPlayer is unavailable", 2)
        end
        local player = getPlayer()
        if not player then return end
        handlerFn(player)
    end

    -- Add first: a failed engine registration must never leave a registry-only
    -- entry that blocks a later deterministic retry.
    add(wrappedFn)
    UTCore._periodicHandlers[key] = {
        traitId   = traitId,
        event     = intervalEvent,
        fn        = handlerFn,
        wrapped   = wrappedFn,
        remove    = remove,
    }
    return true
end

-- Unregisters a previously registered periodic handler.
function UTCore.unregisterPeriodicHandler(traitId, intervalEvent)
    requireString(traitId, "traitId")
    if intervalEvent ~= nil then
        requireString(intervalEvent, "intervalEvent")
    end

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
        table.sort(keys)
    end

    for _, key in ipairs(keys) do
        local entry = UTCore._periodicHandlers[key]
        if entry then
            removeEntry(key, entry)
        end
    end
end
