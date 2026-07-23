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

local function captureUnrelatedCoreHandlers()
    local okHandlers, handlers = pcall(function() return UTCore._coreHandlers end)
    local okCount, count = pcall(function() return UTCore._coreHandlerCount end)
    if not okHandlers or type(handlers) ~= "table"
            or not okCount or not isFinite(count)
            or count < 0 or count ~= math.floor(count) then
        return nil
    end

    local unrelated = {}
    for index = 1, count do
        local row = handlers[index]
        if type(row) ~= "table" then return nil end
        local okId, id = pcall(function() return row.id end)
        local okFn, fn = pcall(function() return row.fn end)
        if not okId or not okFn then return nil end
        if id ~= CORE_HANDLER_ID and fn ~= UTCore._damageMultTickDispatcher then
            unrelated[#unrelated + 1] = row
        end
    end
    return unrelated
end

local function publishCoreHandlers(unrelated, includeDispatcher)
    local handlers = {}
    for index, row in ipairs(unrelated) do
        handlers[index] = row
    end
    if includeDispatcher then
        handlers[#handlers + 1] = {
            id = CORE_HANDLER_ID,
            fn = UTCore._damageMultTickDispatcher,
            throttle = 0,
            priority = 0,
        }
    end
    UTCore._coreHandlers = handlers
    UTCore._coreHandlerCount = #handlers
    UTCore._coreHandlersDirty = true
end

local unrelated = captureUnrelatedCoreHandlers()
if unrelated then
    -- Start from zero matching rows. The registrar is allowed to fail or mutate
    -- before failing, so its writes are treated as provisional until verified.
    publishCoreHandlers(unrelated, false)

    local okRegister, registerCoreHandler = readFunction(UTCore, "registerCoreHandler")
    local registered = false
    if okRegister then
        local okCall = pcall(
            registerCoreHandler,
            CORE_HANDLER_ID,
            UTCore._damageMultTickDispatcher,
            { priority = 0 }
        )
        if okCall then
            local okHandlers, handlers = pcall(function() return UTCore._coreHandlers end)
            local okCount, count = pcall(function() return UTCore._coreHandlerCount end)
            if okHandlers and type(handlers) == "table"
                    and okCount and isFinite(count)
                    and count >= 0 and count == math.floor(count) then
                for index = 1, count do
                    local row = handlers[index]
                    if type(row) == "table" then
                        local okId, id = pcall(function() return row.id end)
                        local okFn, fn = pcall(function() return row.fn end)
                        if okId and id == CORE_HANDLER_ID
                                and okFn and fn == UTCore._damageMultTickDispatcher then
                            registered = true
                            break
                        end
                    end
                end
            end
        end
    end

    -- Restore the pre-call unrelated rows and publish either one verified,
    -- canonical dispatcher or no matching handler at all.
    publishCoreHandlers(unrelated, registered)
end
