-- UT_melancholic.lua
-- Melancholic: mild steady stress increase

local TRAIT_ID = "UniversalTraits:UT_melancholic"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.min(1, stats:getStress() + 0.05))
end

Events.EveryTenMinutes.Add(handler)
