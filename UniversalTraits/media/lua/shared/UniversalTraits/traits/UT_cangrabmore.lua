-- UT_cangrabmore.lua
-- Source: MoreSimpleTraits "CanGrabMore" — sets max carry weight base to 9 (default 8).
-- OnCreatePlayer: hard-set, not a delta.

local TRAIT_ID = "UniversalTraits:UT_cangrabmore"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:setMaxWeightBase(9)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
