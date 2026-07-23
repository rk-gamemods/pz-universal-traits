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
    "UT_inventoryCapacityApplied",
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
    local inventory = player:getInventory()
    local snapshot = {
        player = player,
        modData = modData,
        inventory = inventory,
        maxWeightBase = player:getMaxWeightBase(),
        inventoryCapacity = inventory and inventory:getCapacity() or nil,
        present = {},
        values = {},
    }
    for _, key in ipairs(SNAPSHOT_KEYS) do
        snapshot.present[key] = modData[key] ~= nil
        snapshot.values[key] = copyTable(modData[key])
    end
    return snapshot
end

local function restoreCarrySnapshot(snapshot)
    local errors = {}
    for _, key in ipairs(SNAPSHOT_KEYS) do
        local restored, err = pcall(function()
            if snapshot.present[key] then
                snapshot.modData[key] = copyTable(snapshot.values[key])
            else
                snapshot.modData[key] = nil
            end
        end)
        if not restored then
            errors[#errors + 1] = key .. ": " .. tostring(err)
        end
    end

    local maxWeightRestored, maxWeightError =
        pcall(snapshot.player.setMaxWeightBase, snapshot.player, snapshot.maxWeightBase)
    if not maxWeightRestored then
        errors[#errors + 1] = "maxWeightBase: " .. tostring(maxWeightError)
    end

    if snapshot.inventory then
        local capacityRestored, capacityError =
            pcall(snapshot.inventory.setCapacity, snapshot.inventory, snapshot.inventoryCapacity)
        if not capacityRestored then
            errors[#errors + 1] = "inventoryCapacity: " .. tostring(capacityError)
        end
    end

    return #errors == 0, errors
end

local function retainRollback(snapshot, errors)
    state.pendingRollback = {
        player = snapshot.player,
        snapshot = snapshot,
        errors = errors,
    }
end

local function retryPendingRollback()
    local pending = state.pendingRollback
    if not pending then return true end

    local restored, errors = restoreCarrySnapshot(pending.snapshot)
    if restored then
        state.pendingRollback = nil
        return true
    end

    pending.errors = errors
    return false
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

    local restored, errors = restoreCarrySnapshot(snapshot)
    if not restored then
        retainRollback(snapshot, errors)
    end
    return false
end

local function clearTrackedPlayer()
    local player = state.player
    if not player then return true end
    if syncOwnedCarry(player, nil) then
        state.player = nil
        return true
    end
    return false
end

local function onCreatePlayer(_playerIndex, player)
    if state.onCreatePlayer ~= onCreatePlayer then return end
    if not retryPendingRollback() then return end

    if state.player and state.player ~= player then
        if not clearTrackedPlayer() then return end
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

local function runEventOperation(operation, handler)
    if not operation then
        return false, "missing operation"
    end
    local ok, result = pcall(operation, handler)
    if not ok then
        return false, tostring(result)
    end
    if result == false then
        return false, "explicit false"
    end
    return true, nil
end

local function canonicalizeEventHandler(event, preferredHandler, otherHandler, reason)
    local recovery = {
        preferredHandler = preferredHandler,
        otherHandler = otherHandler,
        reason = reason,
        attempts = {},
    }

    for round = 1, 2 do
        local attempt = {}
        recovery.attempts[round] = attempt
        attempt.removePreferred, attempt.removePreferredError =
            runEventOperation(event and event.Remove, preferredHandler)
        attempt.removeOther, attempt.removeOtherError =
            runEventOperation(event and event.Remove, otherHandler)
        attempt.addPreferred, attempt.addPreferredError =
            runEventOperation(event and event.Add, preferredHandler)

        if attempt.removePreferred and attempt.removeOther and attempt.addPreferred then
            state.onCreatePlayer = preferredHandler
            state.eventRecovery = nil
            return true
        end
    end

    state.onCreatePlayer = preferredHandler
    state.eventRecovery = recovery
    return false
end

local event = Events.OnCreatePlayer
local pendingRecovery = state.eventRecovery
if pendingRecovery then
    if not canonicalizeEventHandler(
        event,
        pendingRecovery.preferredHandler,
        pendingRecovery.otherHandler,
        "retry: " .. tostring(pendingRecovery.reason)
    ) then
        return
    end
end

local retainedHandler = state.onCreatePlayer
if retainedHandler then
    if not retryPendingRollback() or not clearTrackedPlayer() then
        return
    end

    local added, addError = runEventOperation(event and event.Add, onCreatePlayer)
    if not added then
        local removedNew, removeNewError =
            runEventOperation(event and event.Remove, onCreatePlayer)
        state.onCreatePlayer = retainedHandler
        if removedNew then
            state.eventRecovery = nil
        else
            state.eventRecovery = {
                preferredHandler = retainedHandler,
                otherHandler = onCreatePlayer,
                reason = "Add replacement failed: " .. tostring(addError)
                    .. "; replacement cleanup failed: " .. tostring(removeNewError),
                attempts = {},
            }
        end
        return
    end

    local removedOld, removeOldError =
        runEventOperation(event and event.Remove, retainedHandler)
    if removedOld then
        state.onCreatePlayer = onCreatePlayer
        state.eventRecovery = nil
        return
    end

    canonicalizeEventHandler(
        event,
        onCreatePlayer,
        retainedHandler,
        "Remove retained handler failed: " .. tostring(removeOldError)
    )
    return
end

if runEventOperation(event and event.Add, onCreatePlayer) then
    state.onCreatePlayer = onCreatePlayer
end
