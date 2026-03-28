-- UT_flatearther.lua
-- -30% MetaGame XP and -30% reading speed

local TRAIT_ID = "UniversalTraits:UT_flatearther"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyXPMultiplier(player, "MetaGame", 0.7)
    player:getModData()["UT_readSpeedMod"] = -0.3
end

Events.OnNewGame.Add(onNewGame)
