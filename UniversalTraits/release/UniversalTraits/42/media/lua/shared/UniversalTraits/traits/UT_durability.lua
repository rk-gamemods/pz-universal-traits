-- UT_durability.lua
-- Items degrade 25% slower

local TRAIT_ID = "UniversalTraits:UT_durability"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_itemDurabilityMult"] = 1.25
end

Events.OnNewGame.Add(onNewGame)
