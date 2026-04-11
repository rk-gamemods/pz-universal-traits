-- UT_glassbody.lua
-- +50% damage taken multiplier

local TRAIT_ID = "UniversalTraits:UT_glassbody"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_damageMult"] = 1.5
end

Events.OnNewGame.Add(onNewGame)
