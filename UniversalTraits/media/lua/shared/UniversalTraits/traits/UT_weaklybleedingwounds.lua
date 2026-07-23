-- UT_weaklybleedingwounds.lua
-- Wounds bleed with less force than normal.
-- Active bleeding causes 0.6x the normal general-health loss.
-- This gives about 66.7 percent more time before bleeding out when bleeding
-- is the only health-loss source.
-- No effect on wound clotting speed or bandaged wound healing.
-- Mutually exclusive with thickblood and heavilybleedingwounds.

local TRAIT_ID = "UniversalTraits:UT_weaklybleedingwounds"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDrainMult(player, 0.6)
end

Events.OnNewGame.Add(onNewGame)
