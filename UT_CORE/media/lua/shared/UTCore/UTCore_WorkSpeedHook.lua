-- UTCore_WorkSpeedHook.lua
-- At Events.OnGameBoot, wraps getDuration() on all global TimedAction tables.
-- Reads general and action-specific speed modifiers in one central hook.
-- General modifiers are additive deltas: -0.5 = 50% faster, +0.5 = 50% slower.
-- UT_transferSpeedMult is a multiplier (0.6 = 40% faster = delta -0.4).
-- Paramedic is an independent 0.5 multiplier for the exact medical action set.
-- Minimum returned duration is always 1.

UTCore = UTCore or {}

local MEDICAL_ACTION_TYPES = {
    ISMedicalCheckAction = true,
    ISApplyBandage = true,
    ISCleanBurn = true,
    ISComfreyCataplasm = true,
    ISGarlicCataplasm = true,
    ISPlantainCataplasm = true,
    ISDisinfect = true,
    ISRemoveBullet = true,
    ISRemoveGlass = true,
    ISSplint = true,
    ISStitch = true,
}

local CONSTRUCTOR_MEDICAL_ACTION_TYPES = {
    ISMedicalCheckAction = true,
    ISSplint = true,
}

local MECHANICS_ACTION_TYPES = {
    ISInstallVehiclePart = true,
    ISUninstallVehiclePart = true,
    ISFixVehiclePartAction = true,
}

local state = UTCore._workSpeedHookState
if not state then
    state = {
        eventInstalled = false,
        patchedGetDuration = {},
        patchedConstructors = {},
    }
    UTCore._workSpeedHookState = state
end

local function hasParamedic(timedAction)
    if type(timedAction) ~= "table"
    or not MEDICAL_ACTION_TYPES[timedAction.Type] then
        return false
    end

    local ok, result = pcall(function()
        return timedAction.character
        and UTCore.hasTrait(timedAction.character, "UniversalTraits:UT_paramedic")
    end)
    return ok and result == true
end

local function applyParamedicFactor(timedAction, duration)
    if type(duration) ~= "number" or duration < 0 then return duration end
    if timedAction._utParamedicDurationApplied or not hasParamedic(timedAction) then
        return duration
    end
    return math.max(1, math.floor(duration * 0.5))
end

-- Apply work/read speed modifiers to a base duration.
-- timedAction: the TimedAction instance (has .character and .Type fields)
-- base: the original duration from the unpatched getDuration()
function UTCore.applyWorkDuration(timedAction, base)
    if not base then return 1 end
    if base < 0 then return base end   -- preserve animation-driven durations (-1)
    if base < 1 then return 1 end
    local player = timedAction.character
    if not player then return base end

    if UTCore.refreshAggregatedModifierCache then
        UTCore.refreshAggregatedModifierCache(player)
    end

    local md = player:getModData()
    local workMod = md["UT_workSpeedMod"] or 0
    local readMod = 0
    if timedAction.Type == "ISReadABook" then
        readMod = md["UT_readSpeedMod"] or 0
    end

    -- Transfer speed: applies only to inventory moves and weapon reloads.
    -- UT_transferSpeedMult is a multiplier (0.6 = 40% faster), converted here to
    -- an additive delta so it combines correctly with the general work mod.
    local transferMod = 0
    if timedAction.Type == "ISInventoryTransferAction"
    or timedAction.Type == "ISReloadWeaponAction" then
        local mult = md["UT_transferSpeedMult"]
        if mult and mult ~= 1.0 then
            transferMod = mult - 1.0  -- e.g. 0.6 - 1.0 = -0.4 (40% faster)
        end
    end

    -- Pit Crew retains its existing additive composition. Paramedic is applied
    -- independently below so it always halves the duration produced by every
    -- unrelated work-speed source.
    local traitMod = 0
    if MECHANICS_ACTION_TYPES[timedAction.Type]
    and UTCore.hasTrait(player, "UniversalTraits:UT_pitcrew") then
        traitMod = traitMod - 0.5
    end

    local totalMod = workMod + readMod + transferMod + traitMod
    local duration = base
    if totalMod ~= 0 then
        duration = math.max(1, math.floor(base * (1.0 + totalMod)))
    end
    duration = applyParamedicFactor(timedAction, duration)
    if duration == base then return base end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("timed-action.runtime", timedAction.Type or "<unknown>")
    end

    return duration
end

local function patchGetDuration(actionClass)
    if state.patchedGetDuration[actionClass] then return end

    local ok, original = pcall(function() return actionClass.getDuration end)
    if not ok or type(original) ~= "function" then return end

    local wrapped = function(self, ...)
        local base = original(self, ...)
        return UTCore.applyWorkDuration(self, base)
    end
    local assigned = pcall(function() actionClass.getDuration = wrapped end)
    if assigned then state.patchedGetDuration[actionClass] = true end
end

local function patchConstructor(actionType)
    local ok, actionClass = pcall(function() return _G[actionType] end)
    if not ok or type(actionClass) ~= "table"
    or state.patchedConstructors[actionClass] then
        return
    end

    local gotOriginal, original = pcall(function() return actionClass.new end)
    if not gotOriginal or type(original) ~= "function" then return end

    local wrapped = function(...)
        local action = original(...)
        pcall(function()
            if type(action) ~= "table" then return end
            if action.Type == nil then action.Type = actionType end
            if not CONSTRUCTOR_MEDICAL_ACTION_TYPES[action.Type]
            or action._utParamedicDurationApplied
            or type(action.maxTime) ~= "number"
            or not hasParamedic(action) then
                return
            end
            action.maxTime = applyParamedicFactor(action, action.maxTime)
            action._utParamedicDurationApplied = true
        end)
        return action
    end
    local assigned = pcall(function() actionClass.new = wrapped end)
    if assigned then state.patchedConstructors[actionClass] = true end
end

local function patchTimedActions()
    for _, v in pairs(_G) do
        if type(v) == "table" then patchGetDuration(v) end
    end
    patchConstructor("ISMedicalCheckAction")
    patchConstructor("ISSplint")
end

if not state.eventInstalled and Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(patchTimedActions)
    state.eventInstalled = true
end
