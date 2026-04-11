-- UT_analgesia.lua
-- Pain immunity flag

local TRAIT_ID = "UniversalTraits:UT_analgesia"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_painImmune"] = true
end

Events.OnNewGame.Add(onNewGame)
