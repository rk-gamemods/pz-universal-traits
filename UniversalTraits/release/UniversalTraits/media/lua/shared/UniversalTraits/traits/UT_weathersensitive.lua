-- UT_weathersensitive.lua
-- Weather Sensitive: random weather-triggered mood fluctuations

local TRAIT_ID = "UniversalTraits:UT_weathersensitive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if ZombRand(3) == 0 then
        local stats = player:getStats()
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
