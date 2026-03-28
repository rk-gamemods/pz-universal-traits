-- UT_photographicmemory.lua
-- +50% XP gain across knowledge-based skills

local TRAIT_ID = "UniversalTraits:UT_photographicmemory"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyXPMultiplier(player, "Woodwork", 1.5)
    UTCore.applyXPMultiplier(player, "Cooking", 1.5)
    UTCore.applyXPMultiplier(player, "Doctor", 1.5)
    UTCore.applyXPMultiplier(player, "Electrical", 1.5)
    UTCore.applyXPMultiplier(player, "Mechanics", 1.5)
end

Events.OnNewGame.Add(onNewGame)
