-- UTCore_BleedDrainHook.lua
-- Reads UT_bleedDrainMult from player moddata.
-- Every OnPlayerUpdate tick while any body part is actively bleeding,
-- offsets player general health to scale the effective bleed death rate.
--
-- Native bleed drain formula (BodyPart.DamageUpdate, per tick, per part):
--   drain = 0.2857 * damageScaler * GameTime.multiplier * (bleedingTime / 10)
--   → applied to ReduceGeneralHealth (the kill pool, 0-100)
--
-- damageScaler by body part:
--   Neck:           ~0.02857  (5x the standard 0.00571)
--   All others:     ~0.00571
--
-- This hook estimates the native drain each tick by summing across all
-- actively bleeding parts, then applies (1 - mult) * estimatedDrain as
-- a health offset via player:setHealth():
--   mult=2.0 → offset is negative → doubles death rate (heavilybleedingwounds)
--   mult=0.6 → offset is positive → removes 40% of drain (weaklybleedingwounds)
--   mult=0.5 → offset is positive → removes 50% of drain (thickblood)
--
-- Only fires when at least one part has bleeding() == true.
-- Throttled: every 30 ticks (~1 real second at default day length) to match
-- the resolution at which bleedingTime changes are perceptible.

UTCore = UTCore or {}

local THROTTLE = 30
UTCore._bleedDrainTickCounter = UTCore._bleedDrainTickCounter or 0

local DAMAGE_SCALER_STANDARD = 0.0057142857
local DAMAGE_SCALER_NECK     = 0.0057142857 * 5.0
local BLEED_COEFF            = 0.2857143

local function onPlayerUpdate(player)
    if not player then return end

    local md = player:getModData()
    local mult = md["UT_bleedDrainMult"]
    if not mult or mult == 1.0 then return end

    UTCore._bleedDrainTickCounter = UTCore._bleedDrainTickCounter + 1
    if UTCore._bleedDrainTickCounter < THROTTLE then return end
    UTCore._bleedDrainTickCounter = 0

    local bd = player:getBodyDamage()
    if not bd then return end
    if bd:getNumPartsBleeding() == 0 then return end

    local gameMultiplier = GameTime.getInstance():getMultiplier()
    local estimatedDrain = 0.0

    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part:bleeding() and not part:IsBleedingStemmed() then
            local scaler = (part:getType() == BodyPartType.Neck)
                and DAMAGE_SCALER_NECK or DAMAGE_SCALER_STANDARD
            local bleedingTime = part:getBleedingTime()
            -- Native drain this part contributes per tick, summed over THROTTLE ticks
            estimatedDrain = estimatedDrain
                + BLEED_COEFF * scaler * gameMultiplier * (bleedingTime / 10.0) * THROTTLE
        end
    end

    if estimatedDrain == 0.0 then return end

    -- offset = how much health to add (positive) or remove (negative)
    -- to make total drain equal mult * native drain
    local offset = estimatedDrain * (1.0 - mult)
    local currentHealth = player:getHealth()
    player:setHealth(math.max(currentHealth + offset, 0.0))
end

if Events and Events.OnPlayerUpdate then
    if UTCore.profiledHandler then
        Events.OnPlayerUpdate.Add(UTCore.profiledHandler("BleedDrainHook", onPlayerUpdate))
    else
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
end
