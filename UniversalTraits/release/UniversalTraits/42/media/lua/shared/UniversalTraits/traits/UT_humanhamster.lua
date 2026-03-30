-- UT_humanhamster.lua
-- Human hamster: increased carry weight

local TRAIT_ID = "UniversalTraits:UT_humanhamster"

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 2)
    player:getModData()["UT_hamsterMode"] = true
end

Events.OnCreatePlayer.Add(onCreatePlayer)
