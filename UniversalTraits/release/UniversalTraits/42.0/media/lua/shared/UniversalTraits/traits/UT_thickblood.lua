-- UT_thickblood.lua
-- Dense, slow-clotting blood. Two effects:
-- 1. bleedingTime decays 1.5x faster regardless of bandage state (blood clots faster).
-- 2. Active bleed death rate reduced to 0.5x (bleeds slower, harder to bleed out).
-- Stacks with UT_staunch: while bandaged, decay = 1.5x (thickblood) + 2x extra (staunch) = 4.5x total.
-- Mutually exclusive with heavilybleedingwounds.

local TRAIT_ID = "UniversalTraits:UT_thickblood"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDecayMult(player, 1.5, false)
    UTCore.applyBleedDrainMult(player, 0.5)
end

Events.OnNewGame.Add(onNewGame)
