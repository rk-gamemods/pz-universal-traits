-- UT_slack.lua
-- -20% work speed

local TRAIT_ID = "UniversalTraits:UT_slack"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, 0.4)
end

Events.OnNewGame.Add(onNewGame)
