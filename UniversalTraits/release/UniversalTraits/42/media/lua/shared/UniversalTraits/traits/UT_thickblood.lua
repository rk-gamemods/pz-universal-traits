-- UT_thickblood.lua
-- 50% bleed rate (wounds clot faster)

local TRAIT_ID = "UniversalTraits:UT_thickblood"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedRate(player, 0.5)
end

Events.OnNewGame.Add(onNewGame)
