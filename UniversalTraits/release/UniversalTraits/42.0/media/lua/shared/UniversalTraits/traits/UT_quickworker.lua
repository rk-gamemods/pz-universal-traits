-- UT_quickworker.lua
-- +30% work speed

local TRAIT_ID = "UniversalTraits:UT_quickworker"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, -0.3, TRAIT_ID)
end

local function onNewGame(player)
    applyTrait(player)
end

local function onCreatePlayer(_playerIndex, player)
    applyTrait(player)
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
