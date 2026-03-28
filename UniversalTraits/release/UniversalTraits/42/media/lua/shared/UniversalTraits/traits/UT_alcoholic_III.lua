-- UT_alcoholic_III.lua
-- Alcoholic III: severe constant alcohol craving with stress and panic when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_III"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local drunkenness = stats:getDrunkenness()
    if drunkenness < 0.1 then
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
    if drunkenness < 0.05 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.03))
    end
end

Events.EveryOneMinute.Add(handler)
