-- UT_quickrest.lua
-- +30% sleep quality modifier

local TRAIT_ID = "UniversalTraits:UT_quickrest"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySleepQuality(player, 0.3)
end

Events.OnNewGame.Add(onNewGame)
