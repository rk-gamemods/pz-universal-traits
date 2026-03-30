-- UT_sorelegs.lua
-- -2 carry weight and -20% movement speed

local TRAIT_ID = "UniversalTraits:UT_sorelegs"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, -2)
    player:getModData()["UT_speedMod"] = -0.2
end

Events.OnCreatePlayer.Add(onCreatePlayer)
