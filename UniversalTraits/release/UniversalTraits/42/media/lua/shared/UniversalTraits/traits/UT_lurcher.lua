-- UT_lurcher.lua
-- -15% work speed and -15% movement speed

local TRAIT_ID = "UniversalTraits:UT_lurcher"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, -0.15)
    player:getModData()["UT_speedMod"] = -0.15
end

Events.OnNewGame.Add(onNewGame)
