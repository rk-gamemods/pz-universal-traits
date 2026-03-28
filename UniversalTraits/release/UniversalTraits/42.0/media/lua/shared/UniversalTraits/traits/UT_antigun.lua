-- UT_antigun.lua
-- -50% XP gain for Aiming and Reloading

local TRAIT_ID = "UniversalTraits:UT_antigun"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyXPMultiplier(player, "Aiming", 0.5)
    UTCore.applyXPMultiplier(player, "Reloading", 0.5)
end

Events.OnNewGame.Add(onNewGame)
