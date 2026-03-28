-- UT_anorexy.lua
-- Anorexy: food restriction penalty on eat

local TRAIT_ID = "UniversalTraits:UT_anorexy"

local function onEat(player, food)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_anorexPenalty"] = true
    player:getStats():setStress(math.min(1, player:getStats():getStress() + 0.1))
end

Events.OnEat.Add(onEat)
