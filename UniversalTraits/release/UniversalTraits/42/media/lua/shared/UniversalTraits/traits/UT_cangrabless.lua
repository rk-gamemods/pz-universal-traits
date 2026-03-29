-- UT_cangrabless.lua
-- Source: MoreSimpleTraits "CanGrabLess" — sets max carry weight base to 7 (default 8).

local TRAIT_ID = "UniversalTraits:UT_cangrabless"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:setMaxWeightBase(7)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
