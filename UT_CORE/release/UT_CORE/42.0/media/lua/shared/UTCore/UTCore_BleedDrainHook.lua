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
        if bodyDamage.AddGeneralHealth then
            pcall(bodyDamage.AddGeneralHealth, bodyDamage, adjustment)
        end
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
