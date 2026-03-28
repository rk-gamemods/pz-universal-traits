-- UT_heavilybleedingwounds.lua
-- 200% bleed rate (wounds bleed much faster)

local TRAIT_ID = "UniversalTraits:UT_heavilybleedingwounds"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedRate(player, 2.0)
end

Events.OnNewGame.Add(onNewGame)
