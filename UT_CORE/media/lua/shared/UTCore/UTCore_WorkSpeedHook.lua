-- UTCore_WorkSpeedHook.lua
-- At Events.OnGameBoot, wraps getDuration() on all global TimedAction tables.
-- Reads UT_workSpeedMod (general), UT_readSpeedMod (ISReadABook only), and
-- UT_transferSpeedMult (ISInventoryTransferAction / ISReloadWeaponAction only).
-- Modifiers are additive deltas: -0.5 = 50% faster, +0.5 = 50% slower.
-- UT_transferSpeedMult is a multiplier (0.6 = 40% faster = delta -0.4).
-- Minimum returned duration is always 1.

UTCore = UTCore or {}

-- Apply work/read speed modifiers to a base duration.
-- timedAction: the TimedAction instance (has .character and .Type fields)
-- base: the original duration from the unpatched getDuration()
function UTCore.applyWorkDuration(timedAction, base)
    if not base or base < 1 then return 1 end
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

    local totalMod = workMod + readMod + transferMod
    if totalMod == 0 then return base end

    return math.max(1, math.floor(base * (1.0 + totalMod)))
end

local function patchTimedActions()
    for _, v in pairs(_G) do
        if type(v) == "table" and type(v.getDuration) == "function" then
            local orig = v.getDuration
            v.getDuration = function(self)
                local base = orig(self)
                return UTCore.applyWorkDuration(self, base)
            end
        end
    end
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(patchTimedActions)
end
