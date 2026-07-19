-- UTCore_PainHook.lua
-- Reads UT_painImmune from player moddata every OnPlayerUpdate tick.
-- If true, zeroes out the pain stat so the player feels no pain regardless of injuries.
--
-- Pain in PZ is a 0–100 float (IsoStats.getPain/setPain).
-- This hook clears it every tick, overriding any native pain additions from wounds.
-- Note: this does NOT suppress the wound or injury itself — only the pain sensation.
-- The player can still die from blood loss; they just won't feel it.

UTCore = UTCore or {}

local HOOK_VERSION = 1
local previousState = UTCore._painHookState
if previousState and previousState.listener
        and Events and Events.OnPlayerUpdate and Events.OnPlayerUpdate.Remove then
    Events.OnPlayerUpdate.Remove(previousState.listener)
end

local state = previousState or {}
state.version = HOOK_VERSION
state.mode = nil
state.listener = nil
UTCore._painHookState = state

local function onPlayerUpdate(player, tick)
    local md = tick and tick.modData
    if not md then
        if not player then return end
        md = player:getModData()
    end
    if not md then return end
    if not md["UT_painImmune"] then return end

    local stats = tick and tick.stats
    if not stats then
        if not player then return end
        stats = player:getStats()
    end
    if not stats then return end

    if stats:get(CharacterStat.PAIN) > 0 then
        stats:set(CharacterStat.PAIN, 0)
    end
end

if UTCore.registerCoreHandler then
    local handlers = UTCore._coreHandlers
    local count = UTCore._coreHandlerCount
    local existingIndex = nil

    if type(handlers) == "table" and type(count) == "number" then
        for i = 1, count do
            local handler = handlers[i]
            if handler and handler.id == "PainHook" then
                if not existingIndex then
                    existingIndex = i
                    handler.fn = onPlayerUpdate
                    handler.throttle = 0
                    handler.priority = 0
                end
            end
        end

        for i = count, 1, -1 do
            local handler = handlers[i]
            if handler and handler.id == "PainHook" and i ~= existingIndex then
                table.remove(handlers, i)
                UTCore._coreHandlerCount = UTCore._coreHandlerCount - 1
            end
        end
    end

    if not existingIndex then
        UTCore.registerCoreHandler("PainHook", onPlayerUpdate, { priority = 0 })
    end
    state.mode = "core"
else
    if Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
        state.mode = "direct"
        state.listener = onPlayerUpdate
    end
end
