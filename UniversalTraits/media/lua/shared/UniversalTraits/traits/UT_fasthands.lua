-- UT_fasthands.lua
-- 40% faster item transfers and reloads

local TRAIT_ID = "UniversalTraits:UT_fasthands"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_transferSpeedMult"] = 0.6
end

Events.OnNewGame.Add(onNewGame)
