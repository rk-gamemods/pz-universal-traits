-- UT_mundane.lua
-- -20% XP gain across common skills

local TRAIT_ID = "UniversalTraits:UT_mundane"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyXPMultiplier(player, "Woodwork", 0.8)
    UTCore.applyXPMultiplier(player, "Cooking", 0.8)
    UTCore.applyXPMultiplier(player, "Doctor", 0.8)
    UTCore.applyXPMultiplier(player, "Mechanics", 0.8)
    UTCore.applyXPMultiplier(player, "Electrical", 0.8)
    UTCore.applyXPMultiplier(player, "Aiming", 0.8)
    UTCore.applyXPMultiplier(player, "Reloading", 0.8)
end

Events.OnNewGame.Add(onNewGame)
