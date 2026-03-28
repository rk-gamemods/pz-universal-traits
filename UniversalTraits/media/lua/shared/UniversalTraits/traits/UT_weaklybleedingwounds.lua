-- UT_weaklybleedingwounds.lua
-- 60% bleed rate (wounds bleed slightly slower)

local TRAIT_ID = "UniversalTraits:UT_weaklybleedingwounds"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedRate(player, 0.6)
end

Events.OnNewGame.Add(onNewGame)
