-- UT_gimp.lua
-- Source: MoreTraits MT_FastGimpTraits() — movement speed reduction.
-- OnCreatePlayer: applySpeedModifier(-0.5). SpeedHook applies flat movement reduction.

local TRAIT_ID = "UniversalTraits:UT_gimp"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySpeedModifier(player, -0.5)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
