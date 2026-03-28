-- UT_fitted.lua
-- -2 effective carry weight from poor fit/encumbrance

local TRAIT_ID = "UniversalTraits:UT_fitted"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, -2)
end

Events.OnNewGame.Add(onNewGame)
