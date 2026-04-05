-- UT_adaptivemetabolism.lua
-- Adaptive Metabolism: body adjusts hunger based on recent food intake

local TRAIT_ID = "UniversalTraits:UT_adaptivemetabolism"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local hunger = stats:getHunger()
    if hunger > 0.7 then
        -- Body adapts to scarcity, reduces hunger sensation
        stats:setHunger(math.max(0, hunger - 0.05))
    elseif hunger < 0.1 then
        -- Body maintains appetite when well-fed
        stats:setHunger(math.min(1, hunger + 0.02))
    end
end

Events.EveryHours.Add(handler)
