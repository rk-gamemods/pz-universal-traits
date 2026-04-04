-- UT_melancholic.lua
-- Melancholic: mild steady unhappiness increase

local TRAIT_ID = "UniversalTraits:UT_melancholic"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local body = player:getBodyDamage()
    body:setUnhappinessLevel(math.min(100, body:getUnhappinessLevel() + 5))
end

Events.EveryTenMinutes.Add(handler)
