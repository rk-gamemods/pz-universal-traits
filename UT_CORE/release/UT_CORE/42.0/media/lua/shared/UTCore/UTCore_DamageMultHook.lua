-- UTCore_DamageMultHook.lua
-- Reads UT_damageMult from player moddata.
--
-- Track resolved overall body-health changes in the existing central update
-- dispatch. This covers every damage source without trusting events that fire
-- before damage resolution, including OnWeaponHitCharacter/WEAPONHIT.

UTCore = UTCore or {}

local MAX_BODY_PARTS = 64
local EPSILON = 0.0001

local function isFinite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function resetTracking()
    UTCore._damageMultTrackedPlayer = nil
    UTCore._damageMultLastHealth = nil
end

local function callMethod(receiver, methodName, ...)
    if receiver == nil then return false, nil end
    local okMethod, method = pcall(function() return receiver[methodName] end)
    if not okMethod or type(method) ~= "function" then return false, nil end
    return pcall(method, receiver, ...)
end

local function readMarker(modData)
    if modData == nil then return false, nil end
    return pcall(function() return modData["UT_damageMult"] end)
end

local function callFunction(container, functionName, ...)
    if container == nil then return false, nil end
    local okFunction, fn = pcall(function() return container[functionName] end)
    if not okFunction or type(fn) ~= "function" then return false, nil end
    return pcall(fn, ...)
end

local function readFunction(container, functionName)
    if container == nil then return false, nil end
    local okFunction, fn = pcall(function() return container[functionName] end)
    if not okFunction or type(fn) ~= "function" then return false, nil end
    return true, fn
end

local function rollbackAndMeasure(plan, affectedCount)
    for index = affectedCount, 1, -1 do
        local change = plan[index]
        callMethod(change.part, "SetHealth", change.before)
    end

    local actualLoss = 0
    local rollbackComplete = true
    for index = 1, affectedCount do
        local change = plan[index]
        local okHealth, health = callMethod(change.part, "getHealth")
        if not okHealth or not isFinite(health) or health < 0 or health > 100 then
            return nil, false
        end
        if math.abs(health - change.before) > EPSILON then
            rollbackComplete = false
        end
        actualLoss = actualLoss + (change.before - health) * change.modifier
    end
    return actualLoss, rollbackComplete
end

local function applyExactOverallLoss(bodyDamage, requestedLoss)
    if not isFinite(requestedLoss) or requestedLoss <= 0 then return 0 end
    local okBodyPartType, bodyPartType = pcall(function() return BodyPartType end)
    if not okBodyPartType or bodyPartType == nil then
        return 0
    end
    local okToIndex, toIndex = readFunction(bodyPartType, "ToIndex")
    local okDamageModifier, getDamageModifier = readFunction(
        bodyPartType,
        "getDamageModifyer"
    )
    if not okToIndex or not okDamageModifier then
        return 0
    end

    local okParts, bodyParts = callMethod(bodyDamage, "getBodyParts")
    if not okParts or not bodyParts then
        return 0
    end

    local okSize, count = callMethod(bodyParts, "size")
    if not okSize or not isFinite(count) or count < 1
            or count > MAX_BODY_PARTS or count ~= math.floor(count) then
        return 0
    end

    local remaining = requestedLoss
    local plan = {}
    for index = 0, count - 1 do
        if remaining <= EPSILON then break end

        local okPart, part = callMethod(bodyParts, "get", index)
        local okType, partType = callMethod(part, "getType")
        local okTypeIndex, typeIndex = pcall(toIndex, partType)
        local okModifier, modifier = pcall(getDamageModifier, typeIndex)
        if not okPart or not part or not okType
                or not okTypeIndex or not isFinite(typeIndex)
                or typeIndex ~= index or typeIndex ~= math.floor(typeIndex)
                or not okModifier or not isFinite(modifier) or modifier <= 0 then
            return 0
        end

        local okHealth, health = callMethod(part, "getHealth")
        if not okHealth or not isFinite(health) or health < 0 or health > 100 then
            return 0
        end
        local okSetter, setter = pcall(function() return part.SetHealth end)
        if not okSetter or type(setter) ~= "function" then return 0 end

        local contribution = math.min(remaining, health * modifier)
        if contribution > 0 then
            plan[#plan + 1] = {
                part = part,
                before = health,
                after = math.max(0, health - contribution / modifier),
                contribution = contribution,
                modifier = modifier,
            }
            remaining = remaining - contribution
        end
    end

    local appliedTarget = requestedLoss - math.max(0, remaining)
    if appliedTarget <= EPSILON then return 0 end

    local applied = 0
    for planIndex, change in ipairs(plan) do
        local okSet = callMethod(change.part, "SetHealth", change.after)
        if not okSet then
            local actualLoss = rollbackAndMeasure(plan, planIndex)
            return actualLoss
        end
        applied = applied + change.contribution
    end

    for planIndex, change in ipairs(plan) do
        local okHealth, health = callMethod(change.part, "getHealth")
        if not okHealth or not isFinite(health)
                or math.abs(health - change.after) > EPSILON then
            local actualLoss = rollbackAndMeasure(plan, #plan)
            return actualLoss
        end
    end

    return applied
end

local function onPlayerUpdate(player, tick)
    if not player then
        resetTracking()
        return
    end

    local modData = tick and tick.modData
    if modData == nil then
        local okModData
        okModData, modData = callMethod(player, "getModData")
        if not okModData then
            resetTracking()
            return
        end
    end
    local okMarker, mult = readMarker(modData)
    if not okMarker or not isFinite(mult) or mult <= 1.0 then
        resetTracking()
        return
    end

    local bodyDamage = tick and tick.bodyDamage
    if bodyDamage == nil then
        local okBodyDamage
        okBodyDamage, bodyDamage = callMethod(player, "getBodyDamage")
        if not okBodyDamage then
            resetTracking()
            return
        end
    end
    if not bodyDamage then
        resetTracking()
        return
    end

    local okHealth, health = callMethod(bodyDamage, "getOverallBodyHealth")
    if not okHealth or not isFinite(health) then
        resetTracking()
        return
    end

    if UTCore._damageMultTrackedPlayer ~= player or UTCore._damageMultLastHealth == nil then
        UTCore._damageMultTrackedPlayer = player
        UTCore._damageMultLastHealth = health
        return
    end

    local lastHealth = UTCore._damageMultLastHealth
    if health >= lastHealth or health <= 0 then
        UTCore._damageMultLastHealth = health
        return
    end

    local requestedExtra = math.min((lastHealth - health) * (mult - 1.0), health)
    local appliedExtra = applyExactOverallLoss(bodyDamage, requestedExtra)
    if not isFinite(appliedExtra) then
        resetTracking()
        return
    end

    -- Body-part setters take effect immediately, but overallBodyHealth is
    -- recalculated later. Store the expected aggregate so this adjustment is
    -- not observed as a new incoming loss on the following update.
    UTCore._damageMultLastHealth = math.max(0, health - appliedExtra)
end

-- Remove the obsolete pre-resolution listener when this file is reloaded over
-- a previous version in the same process.
if Events and Events.OnWeaponHitCharacter then
    if UTCore._damageMultWeaponHitHandler then
        callFunction(
            Events.OnWeaponHitCharacter,
            "Remove",
            UTCore._damageMultWeaponHitHandler
        )
    end
    UTCore._damageMultWeaponHitHandler = nil
end

resetTracking()
UTCore._damageMultUpdateHandler = onPlayerUpdate

if Events and Events.OnPlayerUpdate and UTCore._damageMultDirectHandler then
    callFunction(Events.OnPlayerUpdate, "Remove", UTCore._damageMultDirectHandler)
    UTCore._damageMultDirectHandler = nil
end

local CORE_HANDLER_ID = "DamageMultHook"

if not UTCore._damageMultTickDispatcher then
    UTCore._damageMultTickDispatcher = function(player, tick)
        local handler = UTCore._damageMultUpdateHandler
        if handler then handler(player, tick) end
    end
end

local MAX_CORE_REGISTRY_KEYS = 256

local function captureCoreRegistry()
    local okHandlers, handlers = pcall(function() return UTCore._coreHandlers end)
    local okCount, count = pcall(function() return UTCore._coreHandlerCount end)
    local okDirty, dirty = pcall(function() return UTCore._coreHandlersDirty end)
    if not okHandlers or type(handlers) ~= "table"
            or not okCount or not isFinite(count) or count < 0
            or count > MAX_CORE_REGISTRY_KEYS or count ~= math.floor(count)
            or not okDirty then
        return nil
    end

    local entries = {}
    local okPairs = pcall(function()
        for key, value in pairs(handlers) do
            if #entries >= MAX_CORE_REGISTRY_KEYS then
                error("core registry exceeds bounded snapshot")
            end
            entries[#entries + 1] = { key = key, value = value }
        end
    end)
    if not okPairs then return nil end

    return {
        handlers = handlers,
        entries = entries,
        count = count,
        dirty = dirty,
    }
end

local function isDamageMultRow(row)
    if type(row) ~= "table" then return false end
    local okId, id = pcall(function() return row.id end)
    local okFn, fn = pcall(function() return row.fn end)
    return (okId and id == CORE_HANDLER_ID)
        or (okFn and fn == UTCore._damageMultTickDispatcher)
end

local function restoreRegistry(snapshot, removeDamageMult)
    local handlers = snapshot.handlers
    local currentKeys = {}
    local okPairs = pcall(function()
        for key in pairs(handlers) do
            if #currentKeys >= MAX_CORE_REGISTRY_KEYS then
                error("core registry exceeds bounded restore")
            end
            currentKeys[#currentKeys + 1] = key
        end
    end)
    if not okPairs then return false end

    for _, key in ipairs(currentKeys) do
        handlers[key] = nil
    end
    for _, entry in ipairs(snapshot.entries) do
        if not removeDamageMult or not isDamageMultRow(entry.value) then
            handlers[entry.key] = entry.value
        end
    end
    UTCore._coreHandlers = handlers
    UTCore._coreHandlerCount = snapshot.count
    UTCore._coreHandlersDirty = snapshot.dirty
    return true
end

local function validateSandbox(handlers, count)
    if type(handlers) ~= "table" or not isFinite(count)
            or count < 1 or count > MAX_CORE_REGISTRY_KEYS
            or count ~= math.floor(count) then
        return false
    end
    local entries = 0
    local valid = true
    local okPairs = pcall(function()
        for key, row in pairs(handlers) do
            entries = entries + 1
            if entries > MAX_CORE_REGISTRY_KEYS
                    or type(key) ~= "number" or key < 1 or key > count
                    or key ~= math.floor(key) or type(row) ~= "table"
                    or row.id ~= CORE_HANDLER_ID
                    or row.fn ~= UTCore._damageMultTickDispatcher then
                valid = false
            end
        end
    end)
    if not okPairs or not valid or entries ~= count then return false end
    for index = 1, count do
        if handlers[index] == nil then return false end
    end
    return true
end

local function publishCanonicalDispatcher(snapshot)
    local matchingKeys = {}
    local occupied = {}
    for _, entry in ipairs(snapshot.entries) do
        occupied[entry.key] = true
        if isDamageMultRow(entry.value) then
            matchingKeys[#matchingKeys + 1] = entry.key
        end
    end

    local targetKey = nil
    for _, key in ipairs(matchingKeys) do
        if type(key) == "number" and key >= 1 and key <= snapshot.count
                and key == math.floor(key) then
            if targetKey ~= nil then return false end
            targetKey = key
        end
    end
    if targetKey == nil then
        targetKey = snapshot.count + 1
        if occupied[targetKey] then return false end
    end

    for index = 1, snapshot.count do
        local value = snapshot.handlers[index]
        if index ~= targetKey and (value == nil or isDamageMultRow(value)) then
            return false
        end
    end

    if not restoreRegistry(snapshot, true) then return false end
    snapshot.handlers[targetKey] = {
        id = CORE_HANDLER_ID,
        fn = UTCore._damageMultTickDispatcher,
        throttle = 0,
        priority = 0,
    }
    if targetKey > snapshot.count then
        UTCore._coreHandlerCount = targetKey
    end
    UTCore._coreHandlersDirty = true
    return true
end

local snapshot = captureCoreRegistry()
if snapshot then
    local okRegister, registerCoreHandler = readFunction(UTCore, "registerCoreHandler")
    local registered = false
    if okRegister then
        UTCore._coreHandlers = {}
        UTCore._coreHandlerCount = 0
        UTCore._coreHandlersDirty = snapshot.dirty
        local okCall, result = pcall(
            registerCoreHandler,
            CORE_HANDLER_ID,
            UTCore._damageMultTickDispatcher,
            { priority = 0 }
        )
        if okCall and result ~= false then
            local okHandlers, handlers = pcall(function() return UTCore._coreHandlers end)
            local okCount, count = pcall(function() return UTCore._coreHandlerCount end)
            registered = okHandlers and okCount and validateSandbox(handlers, count)
        end
    end

    restoreRegistry(snapshot, false)
    if not registered or not publishCanonicalDispatcher(snapshot) then
        restoreRegistry(snapshot, true)
    end
end
