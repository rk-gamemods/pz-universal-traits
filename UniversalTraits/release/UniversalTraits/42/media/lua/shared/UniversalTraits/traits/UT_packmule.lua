-- UT_packmule.lua
-- Source: MoreTraits MoreTraits_UCWF.lua — boosted packmule carry weight bonus.
-- OnCreatePlayer: UTCore.applyCarryWeight(player, +6)

local TRAIT_ID = "UniversalTraits:UT_packmule"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 6, TRAIT_ID)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
