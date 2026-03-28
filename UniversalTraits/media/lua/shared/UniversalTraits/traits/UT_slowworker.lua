-- UT_slowworker.lua
-- -25% work speed

local TRAIT_ID = "UniversalTraits:UT_slowworker"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, 0.5)
end

Events.OnNewGame.Add(onNewGame)
