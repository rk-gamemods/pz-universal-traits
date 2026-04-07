-- UT_cangrabless.lua
-- Source: MoreSimpleTraits "CanGrabLess" — applies a -1 carry weight penalty from the default base of 8.

local TRAIT_ID = "UniversalTraits:UT_cangrabless"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, -1, TRAIT_ID)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
