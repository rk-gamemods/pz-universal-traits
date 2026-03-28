-- UT_competitiveeater.lua
-- Competitive eater: food bonus on eat

local TRAIT_ID = "UniversalTraits:UT_competitiveeater"

local function onEat(player, food)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setBoredom(math.max(0, stats:getBoredom() - 0.1))
    stats:setHunger(math.max(0, stats:getHunger() - 0.05))
end

Events.OnEat.Add(onEat)
