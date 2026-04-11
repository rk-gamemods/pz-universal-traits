-- UT_depressive.lua
-- Depressive: gradually increases stress over time

local TRAIT_ID = "UniversalTraits:UT_depressive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.08))
end

Events.EveryTenMinutes.Add(handler)
