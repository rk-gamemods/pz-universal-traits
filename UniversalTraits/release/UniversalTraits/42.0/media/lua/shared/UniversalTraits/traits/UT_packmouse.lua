-- UT_packmouse.lua
-- Source: MoreTraits MoreTraits_UCWF.lua: packmouse carry weight penalty.
-- OnNewGame: UTCore.applyCarryWeight(player, -2)

local TRAIT_ID = "UniversalTraits:UT_packmouse"
UTPackMouseLifecycle = UTPackMouseLifecycle or {}
local state = UTPackMouseLifecycle

local SNAPSHOT_KEYS = {
    "UT_modifierBuckets",
    "UT_modifierBucketsVersion",
    "UT_speedMod",
    "UT_workSpeedMod",
    "UT_transferSpeedMult",
    "UT_carryFlatMod",
    "UT_carryStrengthBonus",
    "UT_carryTargetBase",
}

local function copyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[copyTable(key, seen)] = copyTable(entry, seen)
    end
    return copy
end

local function captureCarrySnapshot(player)
    local modData = player:getModData()
    local snapshot = { modData = modData, present = {}, values = {} }
    for _, key in ipairs(SNAPSHOT_KEYS) do
        snapshot.present[key] = modData[key] ~= nil
        snapshot.values[key] = copyTable(modData[key])
    end
    return snapshot
end

local function restoreCarrySnapshot(snapshot)
    for _, key in ipairs(SNAPSHOT_KEYS) do
        if snapshot.present[key] then
            snapshot.modData[key] = copyTable(snapshot.values[key])
        else
            snapshot.modData[key] = nil
        end
    end
end

local function syncOwnedCarry(player, value)
    if not player then return false end
    local snapshotOk, snapshot = pcall(captureCarrySnapshot, player)
    if not snapshotOk then return false end

    local applied = pcall(function()
        UTCore.applyCarryWeight(player, value, TRAIT_ID)
        UTCore.reconcileAggregatedModifiers(player)
    end)
    if applied then return true end

    restoreCarrySnapshot(snapshot)
    return false
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

    if syncOwnedCarry(player, -2) then
        state.player = player
    end
end

state.onCreatePlayer = onCreatePlayer
Events.OnCreatePlayer.Add(onCreatePlayer)
