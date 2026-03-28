-- UT_sensitivestomach.lua
-- Sensitive stomach: food reaction

local TRAIT_ID = "UniversalTraits:UT_sensitivestomach"

local function onEat(player, food)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(stats:getStress() + 0.05)
end

Events.OnEat.Add(onEat)
