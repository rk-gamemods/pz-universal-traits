-- UT_heavilybleedingwounds.lua
-- Wounds bleed with twice the lethal force.
-- Active bleed death rate 2x — bleeds out in roughly half the normal time.
-- No effect on wound healing speed once bandaged.
-- Mutually exclusive with thickblood and weaklybleedingwounds.

local TRAIT_ID = "UniversalTraits:UT_heavilybleedingwounds"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDrainMult(player, 2.0)
end

Events.OnNewGame.Add(onNewGame)
