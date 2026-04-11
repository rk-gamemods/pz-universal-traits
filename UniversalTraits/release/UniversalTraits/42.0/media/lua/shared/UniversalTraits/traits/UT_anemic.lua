-- UT_anemic.lua
-- Source: MoreTraits — chronic blood condition, not a skill issue.
-- OnCreatePlayer: bleedingTime decays 3x slower regardless of bandage state.
-- Wounds take much longer to close whether bandaged or not.
-- Does not affect active bleed death rate — combine with heavilybleedingwounds for that.

local TRAIT_ID = "UniversalTraits:UT_anemic"

local function onCreatePlayer(playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyBleedDecayMult(player, 0.33, false)
end

Events.OnCreatePlayer.Add(onCreatePlayer)
