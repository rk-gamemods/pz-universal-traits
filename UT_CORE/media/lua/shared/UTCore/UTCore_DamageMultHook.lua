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

local function applyExactOverallLoss(bodyDamage, requestedLoss)
    if not isFinite(requestedLoss) or requestedLoss <= 0 then return 0 end
    if not bodyDamage.getBodyParts or not BodyPartType
            or not BodyPartType.getDamageModifyer then
        return 0
    end

    local okParts, bodyParts = pcall(bodyDamage.getBodyParts, bodyDamage)
    if not okParts or not bodyParts or not bodyParts.size or not bodyParts.get then
        return 0
    end

    local okSize, count = pcall(bodyParts.size, bodyParts)
    if not okSize or not isFinite(count) or count < 1
            or count > MAX_BODY_PARTS or count ~= math.floor(count) then
        return 0
    end

    local remaining = requestedLoss
    local plan = {}
    for index = 0, count - 1 do
        if remaining <= EPSILON then break end

        local okPart, part = pcall(bodyParts.get, bodyParts, index)
        local okModifier, modifier = pcall(BodyPartType.getDamageModifyer, index)
        if not okPart or not part or not part.getHealth or not part.SetHealth
                or not okModifier or not isFinite(modifier) or modifier <= 0 then
            return 0
        end

        local okHealth, health = pcall(part.getHealth, part)
        if not okHealth or not isFinite(health) or health < 0 or health > 100 then
            return 0
        end

        local contribution = math.min(remaining, health * modifier)
        if contribution > 0 then
            plan[#plan + 1] = {
                part = part,
                before = health,
                after = math.max(0, health - contribution / modifier),
                contribution = contribution,
            }
            remaining = remaining - contribution
        end
    end

    local appliedTarget = requestedLoss - math.max(0, remaining)
    if appliedTarget <= EPSILON then return 0 end

    local applied = 0
    for planIndex, change in ipairs(plan) do
        local okSet = pcall(change.part.SetHealth, change.part, change.after)
        if not okSet then
            for rollbackIndex = planIndex - 1, 1, -1 do
                local rollback = plan[rollbackIndex]
                pcall(rollback.part.SetHealth, rollback.part, rollback.before)
            end
            return 0
        end
        applied = applied + change.contribution
    end

    return applied
end

local function onPlayerUpdate(player, tick)
    if not player then
        resetTracking()
        return
    end

    local modData = tick and tick.modData or player:getModData()
    local mult = modData and modData["UT_damageMult"]
    if not isFinite(mult) or mult <= 1.0 then
        resetTracking()
        return
    end

    local bodyDamage = tick and tick.bodyDamage or player:getBodyDamage()
    if not bodyDamage then
        resetTracking()
        return
    end

    local health = bodyDamage:getOverallBodyHealth()
    if not isFinite(health) then
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

    -- Body-part setters take effect immediately, but overallBodyHealth is
    -- recalculated later. Store the expected aggregate so this adjustment is
    -- not observed as a new incoming loss on the following update.
    UTCore._damageMultLastHealth = math.max(0, health - appliedExtra)
end

-- Remove the obsolete pre-resolution listener when this file is reloaded over
-- a previous version in the same process.
if Events and Events.OnWeaponHitCharacter then
    if UTCore._damageMultWeaponHitHandler then
        Events.OnWeaponHitCharacter.Remove(UTCore._damageMultWeaponHitHandler)
    end
    UTCore._damageMultWeaponHitHandler = nil
end

resetTracking()
UTCore._damageMultUpdateHandler = onPlayerUpdate

if Events and Events.OnPlayerUpdate and UTCore._damageMultDirectHandler then
    Events.OnPlayerUpdate.Remove(UTCore._damageMultDirectHandler)
    UTCore._damageMultDirectHandler = nil
end

if UTCore.registerCoreHandler then
    if not UTCore._damageMultTickDispatcher then
        UTCore._damageMultTickDispatcher = function(player, tick)
            local handler = UTCore._damageMultUpdateHandler
            if handler then handler(player, tick) end
        end
        UTCore.registerCoreHandler("DamageMultHook", UTCore._damageMultTickDispatcher, { priority = 0 })
    end
elseif Events and Events.OnPlayerUpdate then
    UTCore._damageMultDirectHandler = onPlayerUpdate
    Events.OnPlayerUpdate.Add(UTCore._damageMultDirectHandler)
end
