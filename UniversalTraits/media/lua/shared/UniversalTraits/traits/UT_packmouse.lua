-- UT_packmouse.lua
-- Source: MoreTraits MoreTraits_UCWF.lua: packmouse carry weight penalty.
-- OnNewGame: UTCore.applyCarryWeight(player, -2)

local TRAIT_ID = "UniversalTraits:UT_packmouse"
UTPackMouseLifecycle = UTPackMouseLifecycle or {}
local state = UTPackMouseLifecycle

local function syncOwnedCarry(player, value)
    if not player then return false end
    local snapshotOk, hadSource, previousValue = pcall(function()
        local modData = player:getModData()
        local buckets = modData and modData["UT_modifierBuckets"]
        local carryBucket = type(buckets) == "table" and buckets["carryFlatAdd"] or nil
        if type(carryBucket) ~= "table" then
            return false, nil
        end
        return carryBucket[TRAIT_ID] ~= nil, carryBucket[TRAIT_ID]
    end)
    if not snapshotOk then return false end

    local applied = pcall(function()
        UTCore.applyCarryWeight(player, value, TRAIT_ID)
        UTCore.reconcileAggregatedModifiers(player)
    end)
    if applied then return true end

    pcall(function()
        UTCore.applyCarryWeight(player, hadSource and previousValue or nil, TRAIT_ID)
        UTCore.reconcileAggregatedModifiers(player)
    end)
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
