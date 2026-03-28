-- UT_optimist.lua
-- Optimist: naturally sheds stress and panic over time

local TRAIT_ID = "UniversalTraits:UT_optimist"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.max(0, stats:getStress() - 0.06))
    stats:setPanic(math.max(0, stats:getPanic() - 0.04))
end

Events.EveryTenMinutes.Add(handler)
