-- UT_mstoptimist.lua
-- Silver Lining: stress reduction amplifies when stress is high

local TRAIT_ID = "UniversalTraits:UT_mstoptimist"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if stats:getStress() > 0.6 then
        stats:setStress(math.max(0, stats:getStress() - 0.08))
    else
        stats:setStress(math.max(0, stats:getStress() - 0.03))
    end
end

Events.EveryTenMinutes.Add(handler)
