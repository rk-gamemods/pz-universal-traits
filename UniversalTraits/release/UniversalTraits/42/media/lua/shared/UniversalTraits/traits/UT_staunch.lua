-- UT_staunch.lua
-- Source: FillerTraits — medical skill, not a physiological condition.
-- OnCreatePlayer: bleedingTime decays 3x faster when bandaged.
-- Correct bandaging technique closes wounds much faster, reducing infection window
-- and bandage consumption. No effect on unbandaged wounds or active bleed death rate.

local TRAIT_ID = "UniversalTraits:UT_staunch"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDecayMult(player, 3.0, true)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
