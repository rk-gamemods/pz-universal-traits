-- UT_lesssweaty.lua
-- Source: MoreSimpleTraits MSTMainFile.lua — lesssweatytrait().
-- EveryOneMinute: reduces wetness passively when not sleeping.

local TRAIT_ID = "UniversalTraits:UT_lesssweaty"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isAsleep() then return end
    local stats = player:getStats()
    local wetness = stats:get(CharacterStat.WETNESS)
    if wetness <= 0 then return end
    local reduction = 3
    if player:isOutside() and isRaining() then
        reduction = 0.5
    elseif player:isOutside() then
        reduction = 1.5
    end
    stats:set(CharacterStat.WETNESS, math.max(0, wetness - reduction))
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
