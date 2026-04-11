-- UT_maniac.lua
-- Maniac: combat mood boost on kill

local TRAIT_ID = "UniversalTraits:UT_maniac"

local function onKill(player, zombie)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getStats():set(CharacterStat.STRESS, math.max(0, player:getStats():get(CharacterStat.STRESS) - 0.15))
    player:getStats():set(CharacterStat.BOREDOM, math.max(0, player:getStats():get(CharacterStat.BOREDOM) - 0.2))
end

Events.OnZombieDead.Add(onKill)
