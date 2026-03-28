-- UT_accmetabolism.lua
-- Accelerated Metabolism: burns through food and water faster

local TRAIT_ID = "UniversalTraits:UT_accmetabolism"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setHunger(math.min(1, stats:getHunger() + 0.05))
    stats:setThirst(math.min(1, stats:getThirst() + 0.03))
end

Events.EveryTenMinutes.Add(handler)
