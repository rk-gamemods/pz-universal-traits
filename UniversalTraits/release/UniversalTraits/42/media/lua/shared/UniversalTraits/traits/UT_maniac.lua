-- UT_maniac.lua
-- Maniac: combat mood boost on kill

local TRAIT_ID = "UniversalTraits:UT_maniac"

local function onKill(player, zombie)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getStats():setStress(math.max(0, player:getStats():getStress() - 0.15))
    player:getStats():setBoredom(math.max(0, player:getStats():getBoredom() - 0.2))
end

Events.OnZombieDead.Add(onKill)
