-- UT_quickworker.lua
-- +30% work speed

local TRAIT_ID = "UniversalTraits:UT_quickworker"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, 0.3)
end

Events.OnNewGame.Add(onNewGame)
