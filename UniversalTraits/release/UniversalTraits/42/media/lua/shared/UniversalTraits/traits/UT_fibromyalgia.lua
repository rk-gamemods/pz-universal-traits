-- UT_fibromyalgia.lua
-- Fibromyalgia: chronic pain causes persistent stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_fibromyalgia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.min(1, stats:getStress() + 0.07))
    stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))
end

Events.EveryTenMinutes.Add(handler)
