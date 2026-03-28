-- UT_flailer.lua
-- -15% combat accuracy

local TRAIT_ID = "UniversalTraits:UT_flailer"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_combatAccuracyMod"] = -0.15
end

Events.OnNewGame.Add(onNewGame)
