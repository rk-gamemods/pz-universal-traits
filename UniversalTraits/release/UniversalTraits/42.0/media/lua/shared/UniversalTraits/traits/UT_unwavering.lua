-- UT_unwavering.lua
-- 40% panic resistance

local TRAIT_ID = "UniversalTraits:UT_unwavering"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyPanicResistance(player, 0.4)
end

Events.OnNewGame.Add(onNewGame)
