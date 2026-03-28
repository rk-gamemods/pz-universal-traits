-- UT_selfdestructive.lua
-- Self-Destructive: random spikes of stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_selfdestructive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if ZombRand(10) < 2 then
        local stats = player:getStats()
        stats:setStress(math.min(1, stats:getStress() + 0.1))
        stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
