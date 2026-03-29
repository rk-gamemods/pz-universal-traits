-- UT_lesssweaty.lua
-- Source: MoreSimpleTraits MSTMainFile.lua — lesssweatytrait().
-- EveryOneMinute: reduces wetness passively when not sleeping.

local TRAIT_ID = "UniversalTraits:UT_lesssweaty"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isSleeping() then return end
    local bd = player:getBodyDamage()
    if not bd then return end
    local wetness = bd:getWetness()
    if wetness <= 0 then return end
    local reduction = 0.03
    if player:isOutside() and isRaining() then
        reduction = 0.005
    elseif player:isOutside() then
        reduction = 0.015
    end
    bd:setWetness(math.max(0, wetness - reduction))
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
