-- UT_ravenous.lua
-- Ravenous: hunger builds faster than normal

local TRAIT_ID = "UniversalTraits:UT_ravenous"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setHunger(math.min(1, stats:getHunger() + 0.1))
end

Events.EveryTenMinutes.Add(handler)
