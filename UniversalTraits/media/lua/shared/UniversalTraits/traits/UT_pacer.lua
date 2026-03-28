-- UT_pacer.lua
-- +15% movement speed modifier

local TRAIT_ID = "UniversalTraits:UT_pacer"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_speedMod"] = 0.15
end

Events.OnNewGame.Add(onNewGame)
