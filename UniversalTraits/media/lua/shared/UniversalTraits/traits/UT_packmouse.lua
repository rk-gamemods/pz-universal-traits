-- UT_packmouse.lua
-- Source: MoreTraits MoreTraits_UCWF.lua — packmouse carry weight penalty.
-- OnNewGame: UTCore.applyCarryWeight(player, -2)

local TRAIT_ID = "UniversalTraits:UT_packmouse"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, -2)
end

Events.OnNewGame.Add(onNewGame)
