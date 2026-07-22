-- UT_staunch.lua
-- Source: FillerTraits; medical skill, not a physiological condition.
-- OnCreatePlayer: bleedingTime decays 3x faster when bandaged.
-- Correct bandaging technique closes wounds much faster, reducing infection window
-- and bandage consumption. No effect on unbandaged wounds or active bleed death rate.

local TRAIT_ID = "UniversalTraits:UT_staunch"

UTCore._staunchState = UTCore._staunchState or {}
local state = UTCore._staunchState

local function clearModifier()
    if not state.player then return end
    UTCore.applyBleedDecayMult(state.player, nil, true, TRAIT_ID)
    state.player = nil
end

local function applyModifier(player)
    if state.player and state.player ~= player then clearModifier() end
    state.player = player
    UTCore.applyBleedDecayMult(player, 3.0, true, TRAIT_ID)
end

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    applyModifier(player)
end

if UTCore.unregisterTickHandler then
    UTCore.unregisterTickHandler(TRAIT_ID, "reload")
end
if state.onCreatePlayer and Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Remove(state.onCreatePlayer)
end
state.onCreatePlayer = onCreatePlayer
Events.OnCreatePlayer.Add(onCreatePlayer)
UTCore.registerTickHandler(TRAIT_ID, applyModifier, {
    throttle = 30,
    vehicleAware = true,
    teardown = clearModifier,
})
