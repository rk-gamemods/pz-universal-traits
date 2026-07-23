-- UTCore_BleedDrainHook.lua
-- Scales vanilla general-health loss from bleeding by adjusting the exact
-- damage reported after each native bleeding hit.

UTCore = UTCore or {}

local EVENT_ID = "BLEEDING"

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function restoreExactGeneralHealth(bodyDamage, amount)
    if not bodyDamage.getBodyParts or not BodyPartType or not BodyPartType.getDamageModifyer then
        return
    end

    local okParts, parts = pcall(bodyDamage.getBodyParts, bodyDamage)
    if not okParts or not parts or not parts.size or not parts.get then return end

    local okSize, partCount = pcall(parts.size, parts)
    if not okSize or not isFiniteNumber(partCount) or partCount <= 0 or partCount % 1 ~= 0 then
        return
    end

    -- ReduceGeneralHealth divides its input evenly across every body part, then
    -- divides each share by that part's damage modifier. Validate the complete
    -- inverse plan before changing any part so missing bridge methods cannot
    -- leave an intentionally partial correction.
    local plan = {}
    for index = 0, partCount - 1 do
        local okPart, part = pcall(parts.get, parts, index)
        local okModifier, modifier = pcall(BodyPartType.getDamageModifyer, index)
        if not okPart or not part or not part.getHealth or not part.AddHealth
            or not okModifier or not isFiniteNumber(modifier) or modifier <= 0 then
            return
        end

        local okHealth, health = pcall(part.getHealth, part)
        if not okHealth or not isFiniteNumber(health) then return end
        local partAmount = amount / partCount / modifier
        if not isFiniteNumber(partAmount) or partAmount < 0 then return end
        -- A zero-health part may have been clamped or may predate this bleed
        -- event. Skipping it avoids converting an unknown boundary case into
        -- unrelated wound healing.
        if health > 0 then
            plan[#plan + 1] = { part = part, amount = partAmount }
        end
    end

    for _, entry in ipairs(plan) do
        pcall(entry.part.AddHealth, entry.part, entry.amount)
    end
end

local function onPlayerGetDamage(player, damageType, damage)
    if damageType ~= EVENT_ID or not player or not isFiniteNumber(damage) or damage <= 0 then
        return
    end
    if not player.getModData or not player.getBodyDamage then return end

    local okModData, modData = pcall(player.getModData, player)
    if not okModData or type(modData) ~= "table" then return end

    local multiplier = modData["UT_bleedDrainMult"]
    if not isFiniteNumber(multiplier) or multiplier < 0 or multiplier == 1 then return end

    local okBodyDamage, bodyDamage = pcall(player.getBodyDamage, player)
    if not okBodyDamage or not bodyDamage then return end

    local adjustment = damage * math.abs(1 - multiplier)
    if not isFiniteNumber(adjustment) or adjustment <= 0 then return end

    if multiplier < 1 then
        restoreExactGeneralHealth(bodyDamage, adjustment)
    elseif bodyDamage.ReduceGeneralHealth then
        pcall(bodyDamage.ReduceGeneralHealth, bodyDamage, adjustment)
    end
end

-- Reload-safe registration: remove the previous closure before replacing it.
if Events and Events.OnPlayerGetDamage then
    if UTCore._bleedDrainDamageHandler and Events.OnPlayerGetDamage.Remove then
        Events.OnPlayerGetDamage.Remove(UTCore._bleedDrainDamageHandler)
    end
    UTCore._bleedDrainDamageHandler = onPlayerGetDamage
    Events.OnPlayerGetDamage.Add(onPlayerGetDamage)
end
