-- UT_luddite.lua
-- -40% electrical XP gain

local TRAIT_ID = "UniversalTraits:UT_luddite"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyXPMultiplier(player, "Electricity", 0.6)
end

Events.OnNewGame.Add(onNewGame)
