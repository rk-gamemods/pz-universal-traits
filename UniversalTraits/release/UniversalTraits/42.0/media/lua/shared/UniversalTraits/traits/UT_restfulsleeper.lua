-- UT_restfulsleeper.lua
-- +50% sleep quality modifier

local TRAIT_ID = "UniversalTraits:UT_restfulsleeper"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySleepQuality(player, 0.5)
end

Events.OnNewGame.Add(onNewGame)
