-- UT_sensitivestomach.lua
-- Sensitive stomach: slow ongoing stress increase.
-- No OnEat event in B42; effect applied via EveryTenMinutes.

local TRAIT_ID = "UniversalTraits:UT_sensitivestomach"

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.min(1, stats:getStress() + 0.05))
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
