-- UT_fasthands.lua
-- 40% faster item transfers and reloads

local TRAIT_ID = "UniversalTraits:UT_fasthands"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyTransferSpeedMultiplier(player, 0.6, TRAIT_ID)
end

local function onNewGame(player)
    applyTrait(player)
end

local function onCreatePlayer(_playerIndex, player)
    applyTrait(player)
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
