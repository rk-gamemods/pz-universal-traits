-- UT_coldsensitive.lua
-- Cold Sensitive: low body temperature causes stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_coldsensitive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:getBodyTemperature() < 36.0 then
        local stats = player:getStats()
        stats:setStress(math.min(1, stats:getStress() + 0.08))
        stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
