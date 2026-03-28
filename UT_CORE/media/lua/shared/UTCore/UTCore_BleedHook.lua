-- UTCore_BleedHook.lua
-- Applies UT_bleedMult moddata to active bleeding body parts.
-- Throttled: fires every 30 OnPlayerUpdate ticks.
-- mult < 1.0: counteracts bleeding via AddHealth (slows bleed)
-- mult > 1.0: accelerates bleeding via ReduceHealth (speeds bleed)
-- Neck body part receives 2x adjustment.

UTCore = UTCore or {}

local THROTTLE = 30
local _tickCounter = 0

local function onPlayerUpdate(player)
    if not player then return end

    _tickCounter = _tickCounter + 1
    if _tickCounter < THROTTLE then return end
    _tickCounter = 0

    local md = player:getModData()
    local mult = md["UT_bleedMult"]
    if not mult or mult == 1.0 then return end

    local bd = player:getBodyDamage()
    if not bd then return end
    if bd:getNumPartsBleeding() == 0 then return end

    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part:bleeding() and not part:IsBleedingStemmed() then
            local neckMult = (part:getType() == BodyPartType.Neck) and 2.0 or 1.0
            if mult < 1.0 then
                part:AddHealth(0.002 * (1.0 - mult) * neckMult)
            else
                part:ReduceHealth(0.001 * (mult - 1.0) * neckMult)
            end
        end
    end
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
