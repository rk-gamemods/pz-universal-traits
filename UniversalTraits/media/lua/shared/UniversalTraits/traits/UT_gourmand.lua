-- UT_gourmand.lua
-- Gourmand: slight boredom reduction and hunger bonus, checked periodically.
-- No OnEat event exists in B42; effects applied via EveryTenMinutes.

local TRAIT_ID = "UniversalTraits:UT_gourmand"

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    -- Reduce boredom slightly (enjoying food and life)
    stats:setBoredom(math.max(0, stats:getBoredom() - 0.05))
    -- Mild hunger relief bonus
    local hunger = stats:getHunger()
    if hunger > 0 then
        stats:setHunger(math.max(0, hunger - 0.03))
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
