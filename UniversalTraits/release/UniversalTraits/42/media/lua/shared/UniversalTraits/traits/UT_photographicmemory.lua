-- UT_photographicmemory.lua
-- Global learning and reading powerhouse.

local TRAIT_ID = "UniversalTraits:UT_photographicmemory"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    md["UT_xpMult_All"] = 1.5
    md["UT_readSpeedMod"] = -0.6666667
    md["UT_readCalm"] = true
    md["UT_readMoodBonus"] = 5
end

local function onNewGame(player)
    applyTrait(player)
end

local function onCreatePlayer(_playerIndex, player)
    applyTrait(player)
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
