-- UTCore_StatModifiers.lua
-- Stat modifier application helpers.
-- Phase 2 implementation.

UTCore = UTCore or {}

local MODIFIER_BUCKETS_KEY = "UT_modifierBuckets"
local MODIFIER_BUCKET_VERSION_KEY = "UT_modifierBucketsVersion"
local MODIFIER_BUCKETS_VERSION = 2

local SPEED_BUCKET = "speedAdd"
local WORK_BUCKET = "workAdd"
local TRANSFER_BUCKET = "transferMult"
local CARRY_FLAT_BUCKET = "carryFlatAdd"
local CARRY_STRENGTH_BUCKET = "carryStrengthAdd"

local LEGACY_SPEED_SOURCE = "__legacy_speed"
local LEGACY_WORK_SOURCE = "__legacy_work"
local LEGACY_TRANSFER_SOURCE = "__legacy_transfer"

-- Speed modifier clamp range. UT_speedMod is added to 1.0 to get the factor:
--   SPEED_MIN_DELTA = -0.75 → factor = 0.25 → 75% slower than normal
--   SPEED_MAX_DELTA =  1.0  → factor = 2.0  → 100% faster (2x speed)
-- At 2x sprint (~30 km/h), still well below PZ car speeds (80-100+ km/h).
local SPEED_MIN_DELTA = -0.75
local SPEED_MAX_DELTA = 1.0
local WORK_MIN_DELTA = -0.75
local WORK_MAX_DELTA = 2.0
local TRANSFER_MIN_MULT = 0.25
local TRANSFER_MAX_MULT = 2.0
local DEFAULT_CARRY_BASE = 8

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function hasEntries(tbl)
    if type(tbl) ~= "table" then return false end
    for _ in pairs(tbl) do
        return true
    end
    return false
end

local function ensureModifierBuckets(player)
    local md = player:getModData()
    local buckets = md[MODIFIER_BUCKETS_KEY]
    if type(buckets) ~= "table" then
        buckets = {}
        md[MODIFIER_BUCKETS_KEY] = buckets
    end

    if type(buckets[SPEED_BUCKET]) ~= "table" then buckets[SPEED_BUCKET] = {} end
    if type(buckets[WORK_BUCKET]) ~= "table" then buckets[WORK_BUCKET] = {} end
    if type(buckets[TRANSFER_BUCKET]) ~= "table" then buckets[TRANSFER_BUCKET] = {} end
    if type(buckets[CARRY_FLAT_BUCKET]) ~= "table" then buckets[CARRY_FLAT_BUCKET] = {} end
    if type(buckets[CARRY_STRENGTH_BUCKET]) ~= "table" then buckets[CARRY_STRENGTH_BUCKET] = {} end

    return md, buckets
end

local function migrateLegacyBuckets(player)
    local md, buckets = ensureModifierBuckets(player)
    if md[MODIFIER_BUCKET_VERSION_KEY] == MODIFIER_BUCKETS_VERSION then
        return md, buckets
    end

    if not hasEntries(buckets[SPEED_BUCKET]) and md["UT_speedMod"] ~= nil and md["UT_speedMod"] ~= 0 then
        buckets[SPEED_BUCKET][LEGACY_SPEED_SOURCE] = md["UT_speedMod"]
    end

    if not hasEntries(buckets[WORK_BUCKET]) and md["UT_workSpeedMod"] ~= nil and md["UT_workSpeedMod"] ~= 0 then
        buckets[WORK_BUCKET][LEGACY_WORK_SOURCE] = md["UT_workSpeedMod"]
    end

    if not hasEntries(buckets[TRANSFER_BUCKET]) and md["UT_transferSpeedMult"] ~= nil and md["UT_transferSpeedMult"] ~= 1.0 then
        buckets[TRANSFER_BUCKET][LEGACY_TRANSFER_SOURCE] = md["UT_transferSpeedMult"]
    end

    md[MODIFIER_BUCKET_VERSION_KEY] = MODIFIER_BUCKETS_VERSION
    return md, buckets
end

local function setBucketValue(player, bucketName, sourceId, value, legacySource)
    if not player then return end

    local md, buckets = migrateLegacyBuckets(player)
    local bucket = buckets[bucketName]
    local key = sourceId or "__anonymous"

    if legacySource then
        bucket[legacySource] = nil
    end

    if value == nil then
        bucket[key] = nil
    else
        bucket[key] = value
    end

    md[MODIFIER_BUCKET_VERSION_KEY] = MODIFIER_BUCKETS_VERSION
end

local function sumBucket(bucket)
    local total = 0
    for _, value in pairs(bucket) do
        if type(value) == "number" then
            total = total + value
        end
    end
    return total
end

local function productBucket(bucket)
    local total = 1.0
    for _, value in pairs(bucket) do
        if type(value) == "number" then
            total = total * value
        end
    end
    return total
end

function UTCore.refreshAggregatedModifierCache(player)
    if not player then return nil end

    local md, buckets = migrateLegacyBuckets(player)

    local speedMod = clamp(sumBucket(buckets[SPEED_BUCKET]), SPEED_MIN_DELTA, SPEED_MAX_DELTA)
    local workMod = clamp(sumBucket(buckets[WORK_BUCKET]), WORK_MIN_DELTA, WORK_MAX_DELTA)
    local transferMult = clamp(productBucket(buckets[TRANSFER_BUCKET]), TRANSFER_MIN_MULT, TRANSFER_MAX_MULT)
    local carryFlat = sumBucket(buckets[CARRY_FLAT_BUCKET])
    local carryStrengthBonus = sumBucket(buckets[CARRY_STRENGTH_BUCKET])

    md["UT_speedMod"] = speedMod
    md["UT_workSpeedMod"] = workMod
    md["UT_transferSpeedMult"] = transferMult
    md["UT_carryFlatMod"] = carryFlat
    md["UT_carryStrengthBonus"] = carryStrengthBonus

    local carryTarget = nil
    if hasEntries(buckets[CARRY_STRENGTH_BUCKET]) or carryFlat ~= 0 then
        local strength = 0
        if player.getPerkLevel then
            strength = player:getPerkLevel(Perks.Strength)
        end

        local carryBase = hasEntries(buckets[CARRY_STRENGTH_BUCKET]) and (5 + strength) or DEFAULT_CARRY_BASE
        carryTarget = math.max(1, math.floor(carryBase + carryStrengthBonus + carryFlat + 0.5))
    end

    md["UT_carryTargetBase"] = carryTarget

    return {
        speedMod = speedMod,
        workMod = workMod,
        transferSpeedMult = transferMult,
        carryTargetBase = carryTarget,
    }
end

function UTCore.reconcileAggregatedModifiers(player)
    if not player then return nil end

    local summary = UTCore.refreshAggregatedModifierCache(player)
    local carryTarget = summary and summary.carryTargetBase or nil
    if carryTarget ~= nil and player.getMaxWeightBase and player.setMaxWeightBase then
        local current = player:getMaxWeightBase()
        if current ~= carryTarget then
            player:setMaxWeightBase(carryTarget)
        end
    end

    return summary
end

-- Stores speed delta in ModData for OnPlayerUpdate handler.
-- amount is a float delta, e.g. 0.3 for +30% speed.
function UTCore.applySpeedModifier(player, amount, sourceId)
    setBucketValue(player, SPEED_BUCKET, sourceId, amount, LEGACY_SPEED_SOURCE)
    UTCore.refreshAggregatedModifierCache(player)
end

-- Stores a flat carry-weight delta for UTCore reconciliation.
function UTCore.applyCarryWeight(player, delta, sourceId)
    setBucketValue(player, CARRY_FLAT_BUCKET, sourceId, delta)
    UTCore.refreshAggregatedModifierCache(player)
end

-- Stores "UT_bleedMult" in moddata. UTCore_BleedHook reads it every ~1 real second
-- and applies AddHealth (mult<1) or ReduceHealth (mult>1) to each bleeding body part.
--
-- IMPORTANT: This affects body part LOCAL health, NOT the general health pool.
-- The native bleed drain targets general health directly and is unaffected by this value.
-- Effect on survival is small (~4% counter at mult=0.0 on a neck wound).
-- Best used for flavour on minor wounds or stacked with other healing.
-- See UTCore_BleedHook.lua for full mechanics breakdown and impact numbers.
--
-- mult=1.0 → no effect (hook exits early)
-- mult=0.0 → maximum heal via AddHealth(0.002) per tick, neck gets AddHealth(0.004)
-- mult=3.0 → anemic drain: ReduceHealth(0.002) per tick, neck gets ReduceHealth(0.004)
function UTCore.applyBleedRate(player, multiplier)
    player:getModData()["UT_bleedMult"] = multiplier
end

-- Stores "UT_workSpeedMod" in moddata; used by work speed event handlers.
function UTCore.applyWorkSpeed(player, delta, sourceId)
    setBucketValue(player, WORK_BUCKET, sourceId, delta, LEGACY_WORK_SOURCE)
    UTCore.refreshAggregatedModifierCache(player)
end

-- Stores a transfer/reload speed multiplier for UTCore reconciliation.
function UTCore.applyTransferSpeedMultiplier(player, multiplier, sourceId)
    setBucketValue(player, TRANSFER_BUCKET, sourceId, multiplier, LEGACY_TRANSFER_SOURCE)
    UTCore.refreshAggregatedModifierCache(player)
end

-- Stores "UT_xpMult_<perkName>" = multiplier in moddata.
function UTCore.applyXPMultiplier(player, perkName, multiplier)
    player:getModData()["UT_xpMult_" .. perkName] = multiplier
end

-- Stores "UT_xpDisable_<perkName>" = true in moddata.
function UTCore.disableXP(player, perkName)
    player:getModData()["UT_xpDisable_" .. perkName] = true
end

-- Stores "UT_panicResist" in moddata (0.0-1.0 scale, 0=normal, 1=immune).
function UTCore.applyPanicResistance(player, amount)
    player:getModData()["UT_panicResist"] = amount
end

-- Calls player:getStats():set(CharacterStat.STRESS, current + amount) directly if amount > 0.
-- Stores "UT_moodMod" = amount in moddata for periodic checks.
function UTCore.applyMoodModifier(player, amount)
    if amount > 0 then
        local stats = player:getStats()
        stats:set(CharacterStat.STRESS, stats:get(CharacterStat.STRESS) + amount)
    end
    player:getModData()["UT_moodMod"] = amount
end

-- Stores "UT_sleepQualMod" = delta in moddata.
function UTCore.applySleepQuality(player, delta)
    player:getModData()["UT_sleepQualMod"] = delta
end

-- Stores "UT_noiseMult" = multiplier in moddata.
function UTCore.applyNoiseMod(player, multiplier)
    player:getModData()["UT_noiseMult"] = multiplier
end

-- Stores indoor/outdoor/rain wetness reduction values in moddata.
-- UTCore_ThermalRegulationHook reads these every in-game minute.
function UTCore.applyWetnessReductionProfile(player, indoorReduction, outdoorReduction, rainReduction)
    local md = player:getModData()
    md["UT_wetnessReductionIndoor"] = indoorReduction
    md["UT_wetnessReductionOutdoor"] = outdoorReduction
    md["UT_wetnessReductionRain"] = rainReduction
end

-- Stores thermal regulation thresholds and cooling magnitudes in moddata.
-- UTCore_ThermalRegulationHook reads these every in-game minute.
function UTCore.applyThermalRegulationProfile(player, comfortFloor, warmThreshold, hotThreshold, warmCooling, hotCooling)
    local md = player:getModData()
    md["UT_thermalComfortFloor"] = comfortFloor
    md["UT_thermalWarmThreshold"] = warmThreshold
    md["UT_thermalHotThreshold"] = hotThreshold
    md["UT_thermalWarmCooling"] = warmCooling
    md["UT_thermalHotCooling"] = hotCooling
end

--- applyStrengthCarryWeight(player, bonus)
-- Sets carry weight dynamically based on Strength: base = 5 + Strength + bonus.
-- Call every OnPlayerUpdate tick for strength-scaled carry weight traits.
function UTCore.applyStrengthCarryWeight(player, bonus, sourceId)
    setBucketValue(player, CARRY_STRENGTH_BUCKET, sourceId, bonus)
    UTCore.refreshAggregatedModifierCache(player)
end

--- applyStatFloor(player, stat, floor)
-- Enforces a minimum value for a CharacterStat enum value.
-- stat: a CharacterStat enum (e.g. CharacterStat.PAIN)
-- floor: minimum value (number)
function UTCore.applyStatFloor(player, stat, floor)
    local stats = player:getStats()
    if stats:get(stat) < floor then
        stats:set(stat, floor)
    end
end

-- Stores "UT_bleedDecayMult" and "UT_bleedDecayBandagedOnly" in moddata.
-- UTCore_BleedDecayHook reads these every OnPlayerUpdate tick and adjusts
-- bleedingTime on each body part to multiply the native decay rate.
--
-- mult < 1.0 → slower healing (e.g. 0.33 = 3x slower — anemic)
-- mult > 1.0 → faster healing (e.g. 3.0 = 3x faster — staunch)
-- mult = 1.5 → 1.5x faster regardless of bandage state (thickblood bonus)
--
-- bandagedOnly = true  → only applies extra decay when the part is bandaged
-- bandagedOnly = false → applies to all parts with bleedingTime > 0
--
-- Native decay rates (from BodyPart.DamageUpdate):
--   bandaged:   0.0002 * GameTime.multiplier per tick
--   unbandaged: 0.00002 * GameTime.multiplier per tick
function UTCore.applyBleedDecayMult(player, mult, bandagedOnly)
    local md = player:getModData()
    md["UT_bleedDecayMult"]        = mult
    md["UT_bleedDecayBandagedOnly"] = bandagedOnly and true or false
end

-- Stores "UT_bleedDrainMult" in moddata.
-- UTCore_BleedDrainHook reads this every OnPlayerUpdate tick and offsets
-- player general health to scale the effective death rate from active bleeding.
--
-- mult = 1.0 → no effect
-- mult = 2.0 → 2x faster death from bleeding (heavilybleedingwounds)
-- mult = 0.6 → 0.6x death rate, 40% offset added back (weaklybleedingwounds)
-- mult = 0.5 → 0.5x death rate, 50% offset added back (thickblood)
--
-- Hook estimates native drain from bleedingTime and part damageScaler each tick.
-- Effect is only active while at least one body part has bleeding() == true.
function UTCore.applyBleedDrainMult(player, mult)
    player:getModData()["UT_bleedDrainMult"] = mult
end

UTCore._vehicleTraitDefs = UTCore._vehicleTraitDefs or {}

local function cacheVehicleBaseline(vehicle)
    local vmd = vehicle:getModData()
    if vmd.UT_baseMaxSpeed ~= nil then
        return vmd
    end

    vmd.UT_baseMaxSpeed      = vehicle:getMaxSpeed()
    vmd.UT_baseBrakingForce  = vehicle:getBrakingForce()
    vmd.UT_baseEngineQuality = vehicle:getEngineQuality()
    vmd.UT_baseEngineLoudness = vehicle:getEngineLoudness()
    vmd.UT_baseEnginePower   = vehicle:getEnginePower()
    vmd.UT_baseMass          = vehicle:getMass()
    vmd.UT_baseInitialMass   = vehicle:getInitialMass()
    return vmd
end

local function selectVehicleTrait(player)
    local selected = nil

    for _, def in ipairs(UTCore._vehicleTraitDefs) do
        if UTCore.hasTrait(player, def.traitId) then
            if not selected or def.priority > selected.priority then
                selected = def
            end
        end
    end

    return selected
end

--- applyVehicleMod(player, stateKey, mods[, vehicleOverride])
-- Applies vehicle stat multipliers from cached baseline values.
-- Reapplying the same state is a no-op; switching states always recalculates from baseline.
function UTCore.applyVehicleMod(player, stateKey, mods, vehicleOverride)
    if not player then return end

    local vehicle = vehicleOverride or (player.getVehicle and player:getVehicle())
    if not vehicle then return end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("vehicle.runtime", stateKey)
    end

    local vmd = cacheVehicleBaseline(vehicle)
    if vmd.UT_vehicleTraitState == stateKey then return end

    vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed * (mods.maxSpeed or 1.0))
    vehicle:setBrakingForce(vmd.UT_baseBrakingForce * (mods.brakingForce or 1.0))
    vehicle:setEngineFeature(
        vmd.UT_baseEngineQuality * (mods.engineQuality or 1.0),
        vmd.UT_baseEngineLoudness * (mods.engineLoudness or 1.0),
        vmd.UT_baseEnginePower * (mods.enginePower or 1.0)
    )
    vehicle:setMass(vmd.UT_baseMass * (mods.mass or 1.0))
    vehicle:setInitialMass(vmd.UT_baseInitialMass * (mods.mass or 1.0))
    vehicle:updateTotalMass()
    vmd.UT_vehicleTraitState = stateKey
end

-- Restores a vehicle to its cached baseline values.
function UTCore.restoreVehicleMod(vehicle)
    if not vehicle then return end

    local vmd = vehicle:getModData()
    if vmd.UT_baseMaxSpeed == nil then return end

    vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed)
    vehicle:setBrakingForce(vmd.UT_baseBrakingForce)
    vehicle:setEngineFeature(vmd.UT_baseEngineQuality, vmd.UT_baseEngineLoudness, vmd.UT_baseEnginePower)
    vehicle:setMass(vmd.UT_baseMass)
    vehicle:setInitialMass(vmd.UT_baseInitialMass)
    vehicle:updateTotalMass()
    vmd.UT_vehicleTraitState = nil
end

-- Registers a vehicle trait so the shared enter/load/exit listeners can apply it.
-- Higher priority wins if multiple vehicle traits are somehow active at once.
function UTCore.registerVehicleTrait(traitId, stateKey, mods, priority)
    for _, def in ipairs(UTCore._vehicleTraitDefs) do
        if def.traitId == traitId then
            def.stateKey = stateKey
            def.mods = mods
            def.priority = priority or 0
            return
        end
    end

    UTCore._vehicleTraitDefs[#UTCore._vehicleTraitDefs + 1] = {
        traitId = traitId,
        stateKey = stateKey,
        mods = mods,
        priority = priority or 0,
    }
end

-- Syncs the active vehicle state for the player's current vehicle.
-- Called on enter and on load so the effect is applied once, not every frame.
function UTCore.syncVehicleTrait(player, vehicle)
    if not player then return end

    local targetVehicle = vehicle or (player.getVehicle and player:getVehicle())
    if not targetVehicle then return end

    -- If called without an explicit vehicle (e.g. OnCreatePlayer), check if still driving.
    if not vehicle and player.isDriving and not player:isDriving() then
        UTCore.restoreVehicleMod(targetVehicle)
        return
    end

    local selected = selectVehicleTrait(player)
    if not selected then
        UTCore.restoreVehicleMod(targetVehicle)
        return
    end

    UTCore.applyVehicleMod(player, selected.stateKey, selected.mods, targetVehicle)
end

if not UTCore._modifierAggregationEventsRegistered then
    local function onCreatePlayer(_playerIndex, player)
        -- Clear session-level hasTrait result cache so it rebuilds for this player.
        if UTCore.invalidateTraitCache then UTCore.invalidateTraitCache() end
        UTCore.reconcileAggregatedModifiers(player)
    end

    local function onPlayerUpdate(player)
        UTCore.reconcileAggregatedModifiers(player)
    end

    if Events and Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end

    if Events and Events.OnPlayerUpdate then
        if UTCore.profiledHandler then
            Events.OnPlayerUpdate.Add(UTCore.profiledHandler("StatModifiers", onPlayerUpdate))
        else
            Events.OnPlayerUpdate.Add(onPlayerUpdate)
        end
    end

    UTCore._modifierAggregationEventsRegistered = true
end

if not UTCore._vehicleTraitEventsRegistered then
    local function onVehicleEnter(player, vehicle)
        UTCore.syncVehicleTrait(player, vehicle)
    end

    local function onVehicleExit(player, vehicle)
        UTCore.restoreVehicleMod(vehicle)
    end

    local function onCreatePlayer(_playerIndex, player)
        UTCore.syncVehicleTrait(player)
    end

    if Events and Events.OnVehicleEnter then
        Events.OnVehicleEnter.Add(onVehicleEnter)
    end

    if Events and Events.OnVehicleExit then
        Events.OnVehicleExit.Add(onVehicleExit)
    end

    if Events and Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end

    UTCore._vehicleTraitEventsRegistered = true
end
