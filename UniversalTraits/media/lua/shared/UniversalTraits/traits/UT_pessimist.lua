-- UT_pessimist.lua
-- Pessimist: mild steady stress increase from negative outlook

local TRAIT_ID = "UniversalTraits:UT_pessimist"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.05))
end

Events.EveryTenMinutes.Add(handler)
