-- UT_preparedpack.lua
-- +3 carry weight from being well-prepared

local TRAIT_ID = "UniversalTraits:UT_preparedpack"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 3)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
