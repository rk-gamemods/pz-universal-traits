-- UT_packmule.lua
-- Source: MoreTraits MoreTraits_UCWF.lua — packmule carry weight bonus.
-- OnNewGame: UTCore.applyCarryWeight(player, +2)

local TRAIT_ID = "UniversalTraits:UT_packmule"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 2)
end

Events.OnNewGame.Add(onNewGame)
