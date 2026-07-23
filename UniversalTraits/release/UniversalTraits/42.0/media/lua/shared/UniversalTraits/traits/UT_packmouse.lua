-- UT_packmouse.lua
-- Source: MoreTraits MoreTraits_UCWF.lua: packmouse carry weight penalty.
-- OnNewGame: UTCore.applyCarryWeight(player, -2)

local TRAIT_ID = "UniversalTraits:UT_packmouse"
UTPackMouseLifecycle = UTPackMouseLifecycle or {}
local state = UTPackMouseLifecycle

local function syncOwnedCarry(player, value)
    if not player then return false end
    return pcall(function()
        UTCore.applyCarryWeight(player, value, TRAIT_ID)
        UTCore.reconcileAggregatedModifiers(player)
    end)
end

local function clearTrackedPlayer()
    local player = state.player
    state.player = nil
    if player then
        syncOwnedCarry(player, nil)
    end
end

local retainedHandler = state.onCreatePlayer
if retainedHandler then
    local removed = Events.OnCreatePlayer
        and Events.OnCreatePlayer.Remove
        and pcall(Events.OnCreatePlayer.Remove, retainedHandler)
    clearTrackedPlayer()
    if not removed then
        return
    end
end

local function onCreatePlayer(_playerIndex, player)
    if state.player and state.player ~= player then
        clearTrackedPlayer()
    end

    local active = false
    local valid = player ~= nil
    if valid and player.isDead then
        local deadOk, dead = pcall(player.isDead, player)
        valid = deadOk and not dead
    end
    if valid then
        local traitOk, hasTrait = pcall(UTCore.hasTrait, player, TRAIT_ID)
        active = traitOk and hasTrait == true
    end

    if not active then
        if state.player == player then
            clearTrackedPlayer()
        end
        return
    end

    state.player = player
    syncOwnedCarry(player, -2)
end

state.onCreatePlayer = onCreatePlayer
Events.OnCreatePlayer.Add(onCreatePlayer)
