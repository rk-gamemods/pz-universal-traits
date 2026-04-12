-- UTCore_BleedDecayHook.lua
-- Reads UT_bleedDecayMult and UT_bleedDecayBandagedOnly from player moddata.
-- Every OnPlayerUpdate tick, adjusts bleedingTime on each body part to
-- multiply the native decay rate by the stored multiplier.
--
-- Native decay rates (BodyPart.DamageUpdate, per tick):
--   bandaged:   0.0002 * GameTime.multiplier
--   unbandaged: 0.00002 * GameTime.multiplier
--
-- Mechanism: the game has already applied its native decay this tick.
-- We apply the delta to achieve the target multiplied rate:
--   extraDecay = nativeDecay * (mult - 1.0)
--   part:setBleedingTime(current - extraDecay)
--   → mult=3.0: removes 2x extra → 3x total decay (3x faster healing)
--   → mult=0.33: adds back 0.67x → 0.33x total decay (3x slower healing)
--   → mult=1.5: removes 0.5x extra → 1.5x total decay
--
-- bandagedOnly=true: only applies when part:bandaged() == true (staunch)
-- bandagedOnly=false: applies regardless of bandage state (anemic, thickblood)

UTCore = UTCore or {}

local NATIVE_BANDAGED   = 0.0002
local NATIVE_UNBANDAGED = 0.00002

local _bleedDecayTick = 0

local function onPlayerUpdate(player, tick)
    -- Throttle: body part iteration is expensive. Check every 10 ticks (~3x/sec).
    _bleedDecayTick = _bleedDecayTick + 1
    if _bleedDecayTick < 10 then return end
    _bleedDecayTick = 0

    local md = tick and tick.modData or player:getModData()
    local mult        = md["UT_bleedDecayMult"]
    local bandagedOnly = md["UT_bleedDecayBandagedOnly"]

    if not mult or mult == 1.0 then return end

    local gameMultiplier = GameTime.getInstance():getMultiplier()
    local bd = tick and tick.bodyDamage or player:getBodyDamage()
    if not bd then return end

    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local bleedingTime = part:getBleedingTime()
        if bleedingTime > 0 then
            local isBandaged = part:bandaged()
            if not bandagedOnly or isBandaged then
                local nativeDecay = isBandaged and NATIVE_BANDAGED or NATIVE_UNBANDAGED
                -- Multiply by 10 to compensate for 10-tick throttle: total decay
                -- rate is identical to running every tick at 1x.
                local extraDecay  = nativeDecay * gameMultiplier * (mult - 1.0) * 10
                local newTime     = bleedingTime - extraDecay
                part:setBleedingTime(math.max(newTime, 0))
            end
        end
    end
end

if UTCore.registerCoreHandler then
    UTCore.registerCoreHandler("BleedDecayHook", onPlayerUpdate, { priority = 0 })
else
    if Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
end
