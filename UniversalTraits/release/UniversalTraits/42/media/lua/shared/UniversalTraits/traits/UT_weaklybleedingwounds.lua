-- UT_weaklybleedingwounds.lua
-- Wounds bleed with less force than normal.
-- Active bleed death rate 0.6x — roughly 40% more time before bleeding out.
-- No effect on wound healing speed once bandaged.
-- Mutually exclusive with heavilybleedingwounds.

local TRAIT_ID = "UniversalTraits:UT_weaklybleedingwounds"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDrainMult(player, 0.6)
end

Events.OnNewGame.Add(onNewGame)
