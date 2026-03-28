-- UT_gourmand.lua
-- Gains 30% bonus hunger relief and slight boredom reduction when eating

local TRAIT_ID = "UniversalTraits:UT_gourmand"

local function onEat(player, food)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    -- Mark that bonus hunger effect is applied
    player:getModData()["UT_lastMealBonus"] = 0.3

    -- Reduce boredom slightly
    local stats = player:getStats()
    stats:setBoredom(math.max(0, stats:getBoredom() - 0.05))
end

Events.OnEat.Add(onEat)
