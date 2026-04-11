-- UT_cangrabmore.lua
-- Source: MoreSimpleTraits "CanGrabMore" — adds +1 carry weight from the default base of 8.

local TRAIT_ID = "UniversalTraits:UT_cangrabmore"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 1, TRAIT_ID)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
