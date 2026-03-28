-- UT_idealweight.lua
-- +1 carry weight and slightly better fatigue rate from ideal fitness

local TRAIT_ID = "UniversalTraits:UT_idealweight"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 1)
    player:getModData()["UT_fatigueRate"] = 0.85
end

Events.OnNewGame.Add(onNewGame)
