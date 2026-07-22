-- UTCore_BleedDecayHook.lua
-- Reads legacy scalar and named bleed-decay multiplier buckets from player moddata.
-- Every OnPlayerUpdate tick, adjusts bleedingTime on each body part to
-- multiply the native decay rate by the stored multiplier.
--
-- Native decay rates (BodyPart.DamageUpdate, per tick):
--   bandaged:   0.0002 * GameTime.multiplier
--   unbandaged: 0.00002 * GameTime.multiplier
--
-- Mechanism: OnPlayerUpdate runs before the engine's native decay for this tick.
-- Every tenth update, apply the accumulated extra delta; native decay then
-- completes the target multiplied rate for the ten-update interval:
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
local EMBEDDED_GLASS_BLEEDING_FLOOR = 3.0
local MAX_BODY_PARTS = 64
local MODIFIER_BUCKETS_KEY = "UT_modifierBuckets"
local BLEED_DECAY_ALL_BUCKET = "bleedDecayAllMult"
local BLEED_DECAY_BANDAGED_BUCKET = "bleedDecayBandagedMult"

local _bleedDecayTick = 0

local function validMultiplier(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

local function productBucket(bucket)
    local product = 1.0
    if type(bucket) ~= "table" then return product end

    for _, value in pairs(bucket) do
        if validMultiplier(value) then
            product = product * value
            if not validMultiplier(product) then return 1.0 end
        end
    end
    return product
end

local function onPlayerUpdate(player, tick)
    -- Throttle: body part iteration is expensive. Check every 10 ticks (~3x/sec).
    _bleedDecayTick = _bleedDecayTick + 1
    if _bleedDecayTick < 10 then return end
    _bleedDecayTick = 0

    if not player then return end

    local ok, md = pcall(function()
        return tick and tick.modData or player:getModData()
    end)
    if not ok or type(md) ~= "table" then return end

    local legacyMult = md["UT_bleedDecayMult"]
    if not validMultiplier(legacyMult) then legacyMult = 1.0 end
    local legacyBandagedOnly = md["UT_bleedDecayBandagedOnly"] == true
    local buckets = md[MODIFIER_BUCKETS_KEY]
    local allWoundMult = productBucket(type(buckets) == "table" and buckets[BLEED_DECAY_ALL_BUCKET])
    local bandagedMult = productBucket(type(buckets) == "table" and buckets[BLEED_DECAY_BANDAGED_BUCKET])

    if legacyMult == 1.0 and allWoundMult == 1.0 and bandagedMult == 1.0 then return end

    local boundaryOK, gameMultiplier, parts, partCount = pcall(function()
        if not GameTime or not GameTime.getInstance then return nil end
        local gameTime = GameTime.getInstance()
        if not gameTime or not gameTime.getMultiplier then return nil end

        local bd = tick and tick.bodyDamage or player:getBodyDamage()
        if not bd then return nil end
        local bodyParts = bd:getBodyParts()
        if not bodyParts then return nil end
        return gameTime:getMultiplier(), bodyParts, bodyParts:size()
    end)
    if not boundaryOK
        or type(gameMultiplier) ~= "number"
        or gameMultiplier ~= gameMultiplier
        or gameMultiplier < 0
        or type(partCount) ~= "number"
        or partCount < 0
        or partCount > MAX_BODY_PARTS then
        return
    end

    for i = 0, partCount - 1 do
        pcall(function()
            local part = parts:get(i)
            if not part then return end

            local bleedingTime = part:getBleedingTime()
            if type(bleedingTime) ~= "number" or bleedingTime ~= bleedingTime or bleedingTime <= 0 then return end

            local isBandaged = part:bandaged() == true
            local mult = allWoundMult
            if not legacyBandagedOnly or isBandaged then
                mult = mult * legacyMult
            end
            if isBandaged then
                mult = mult * bandagedMult
            end
            if not validMultiplier(mult) or mult == 1.0 then return end

            local nativeDecay = isBandaged and NATIVE_BANDAGED or NATIVE_UNBANDAGED
            -- Multiply by 10 to compensate for the 10-update throttle.
            local newTime = bleedingTime - nativeDecay * gameMultiplier * (mult - 1.0) * 10
            local floor = part:haveGlass() == true and EMBEDDED_GLASS_BLEEDING_FLOOR or 0
            if newTime < floor then newTime = floor end
            part:setBleedingTime(newTime)
        end)
    end
end

if not UTCore._bleedDecayHookRegistered then
    if UTCore.registerCoreHandler then
        UTCore.registerCoreHandler("BleedDecayHook", onPlayerUpdate, { priority = 0 })
        UTCore._bleedDecayHookRegistered = true
    elseif Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
        UTCore._bleedDecayHookRegistered = true
    end
end
