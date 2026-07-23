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
local BLEED_DECAY_ALL_BUCKET = "bleedDecayAllMult"
local BLEED_DECAY_BANDAGED_BUCKET = "bleedDecayBandagedMult"

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
local INVENTORY_LIMIT_PATCH_MOD_ID = "RemoveInventoryLimitsZB"
local SAFE_INVENTORY_CAPACITY_MAX = 100
local DEFAULT_CARRY_BASE = 8
-- A persisted value fence: UTCore owns a capacity only while the receiver
-- still reports the exact value from UTCore's last successful write.
local INVENTORY_CAPACITY_APPLIED_KEY = "UT_inventoryCapacityApplied"
local CARRY_RECEIVER_ACTIVE_KEY = "UT_carryReceiverActive"
local CARRY_RECEIVER_BASELINE_KEY = "UT_carryReceiverBaseline"
local CARRY_RECEIVER_LAST_APPLIED_KEY = "UT_carryReceiverLastApplied"

local function isInventoryLimitPatchActive()
    if getActivatedMods == nil then return false end

    local mods = getActivatedMods()
    return mods ~= nil and mods.contains ~= nil and mods:contains(INVENTORY_LIMIT_PATCH_MOD_ID)
end

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
    if not player or type(player.getModData) ~= "function" then return nil, nil end
    local ok, md = pcall(player.getModData, player)
    if not ok or type(md) ~= "table" then return nil, nil end
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
    if type(buckets[BLEED_DECAY_ALL_BUCKET]) ~= "table" then buckets[BLEED_DECAY_ALL_BUCKET] = {} end
    if type(buckets[BLEED_DECAY_BANDAGED_BUCKET]) ~= "table" then buckets[BLEED_DECAY_BANDAGED_BUCKET] = {} end

    return md, buckets
end

local function migrateLegacyBuckets(player)
    local md, buckets = ensureModifierBuckets(player)
    if not md then return nil, nil end
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
    if not md then return end
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

local function callMethod(receiver, methodName, ...)
    if receiver == nil then return false, nil end
    local method = receiver[methodName]
    if type(method) ~= "function" then return false, nil end
    return pcall(method, receiver, ...)
end

function UTCore.refreshAggregatedModifierCache(player)
    if not player then return nil end

    local md, buckets = migrateLegacyBuckets(player)
    if not md then return nil end

    local speedMod = clamp(sumBucket(buckets[SPEED_BUCKET]), SPEED_MIN_DELTA, SPEED_MAX_DELTA)
    local workMod = clamp(sumBucket(buckets[WORK_BUCKET]), WORK_MIN_DELTA, WORK_MAX_DELTA)
    local transferMult = clamp(productBucket(buckets[TRANSFER_BUCKET]), TRANSFER_MIN_MULT, TRANSFER_MAX_MULT)
    local carryFlat = sumBucket(buckets[CARRY_FLAT_BUCKET])
    local carryStrengthBonus = sumBucket(buckets[CARRY_STRENGTH_BUCKET])
    local carryActive = hasEntries(buckets[CARRY_FLAT_BUCKET])
        or hasEntries(buckets[CARRY_STRENGTH_BUCKET])

    md["UT_speedMod"] = speedMod
    md["UT_workSpeedMod"] = workMod
    md["UT_transferSpeedMult"] = transferMult
    md["UT_carryFlatMod"] = carryFlat
    md["UT_carryStrengthBonus"] = carryStrengthBonus

    local carryTarget = nil
    if carryActive then
        local strength = 0
        if player.getPerkLevel then
            local strengthOk, currentStrength = callMethod(player, "getPerkLevel", Perks.Strength)
            if strengthOk and type(currentStrength) == "number" then
                strength = currentStrength
            end
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
        carryActive = carryActive,
    }
end

local function clearCarryReceiverOwnership(md)
    md[CARRY_RECEIVER_BASELINE_KEY] = nil
    md[CARRY_RECEIVER_LAST_APPLIED_KEY] = nil
end

local function clearCarryReceiverState(md)
    clearCarryReceiverOwnership(md)
    md[CARRY_RECEIVER_ACTIVE_KEY] = nil
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function reconcileCarryReceiver(player, md, summary)
    local carryActive = summary.carryActive == true
    local activeMarker = md[CARRY_RECEIVER_ACTIVE_KEY]
    local baseline = md[CARRY_RECEIVER_BASELINE_KEY]
    local lastApplied = md[CARRY_RECEIVER_LAST_APPLIED_KEY]
    local stateAbsent = activeMarker == nil and baseline == nil and lastApplied == nil
    local stateOwned = activeMarker == true
        and isFiniteNumber(baseline)
        and isFiniteNumber(lastApplied)

    if carryActive and stateAbsent then
        local currentOk, current = callMethod(player, "getMaxWeightBase")
        if not currentOk or not isFiniteNumber(current) then return end

        -- Persist the transition and ownership fence before the first write.
        -- If the setter fails, the unchanged receiver still matches the fence
        -- and a later reconciliation can retry without losing the baseline.
        md[CARRY_RECEIVER_ACTIVE_KEY] = true
        md[CARRY_RECEIVER_BASELINE_KEY] = current
        md[CARRY_RECEIVER_LAST_APPLIED_KEY] = current
        if current ~= summary.carryTargetBase then
            local setOk = callMethod(player, "setMaxWeightBase", summary.carryTargetBase)
            if setOk then
                md[CARRY_RECEIVER_LAST_APPLIED_KEY] = summary.carryTargetBase
            end
        end
        return
    end

    if carryActive then
        -- Any existing malformed, partial, or inconsistent tuple cannot prove
        -- ownership. Preserve it and the receiver until all sources leave.
        if not stateOwned then return end
        local currentOk, current = callMethod(player, "getMaxWeightBase")
        if not currentOk or not isFiniteNumber(current) then return end
        if current ~= lastApplied then
            -- A foreign writer changed the receiver. Clear only UTCore's
            -- ownership fence, retain the active marker, and do not reacquire
            -- until every carry source has left.
            clearCarryReceiverOwnership(md)
            return
        end
        if current ~= summary.carryTargetBase then
            local setOk = callMethod(player, "setMaxWeightBase", summary.carryTargetBase)
            if setOk then
                md[CARRY_RECEIVER_LAST_APPLIED_KEY] = summary.carryTargetBase
            end
        end
        return
    end

    if stateAbsent then return end
    if not stateOwned then
        -- With no live carry sources, malformed ownership metadata is stale.
        -- Clear it without touching the foreign receiver so a later clean
        -- active period can acquire a new baseline.
        clearCarryReceiverState(md)
        return
    end

    local currentOk, current = callMethod(player, "getMaxWeightBase")
    if not currentOk or not isFiniteNumber(current) then return end
    if current ~= lastApplied then
        clearCarryReceiverState(md)
        return
    end

    local setOk = true
    if current ~= baseline then
        setOk = callMethod(player, "setMaxWeightBase", baseline)
    end
    if setOk then
        clearCarryReceiverState(md)
    end
end

function UTCore.reconcileAggregatedModifiers(player)
    if not player or not player.getModData then return nil end

    local summary = UTCore.refreshAggregatedModifierCache(player)
    if not summary then return nil end
    local mdOk, md = callMethod(player, "getModData")
    if not mdOk or type(md) ~= "table" then return nil end
    reconcileCarryReceiver(player, md, summary)

    -- Sync inventory container capacity with actual carry ability.
    -- Vanilla B42.17 is safe only up to 100. Higher values require the
    -- ZombieBuddy-based RemoveInventoryLimitsZB patch to lift Java caps.
    local invOk, inv = false, nil
    if player.getInventory then
        invOk, inv = pcall(player.getInventory, player)
    end
    if invOk and inv and inv.setCapacity and inv.getCapacity then
        local maxWOk, maxW = callMethod(player, "getMaxWeight")
        local baseOk, base = callMethod(player, "getMaxWeightBase")
        local wModOk, wMod = callMethod(player, "getWeightMod")
        local deltaOk, delta = callMethod(player, "getMaxWeightDelta")
        maxW = maxWOk and type(maxW) == "number" and maxW or 0
        base = baseOk and type(base) == "number" and base or nil
        wMod = wModOk and type(wMod) == "number" and wMod or 1.0
        delta = deltaOk and type(delta) == "number" and delta or 1.0
        if base == nil then return summary end
        local estimated = math.floor(base * wMod * delta)
        local needed = math.max(50, maxW, estimated)
        local targetCap = needed
        if not isInventoryLimitPatchActive() then
            targetCap = math.min(SAFE_INVENTORY_CAPACITY_MAX, needed)
        end
        local ownedCapacity = md[INVENTORY_CAPACITY_APPLIED_KEY]
        local currentOk, currentCap = pcall(inv.getCapacity, inv)
        if currentOk and type(currentCap) == "number" then
            if ownedCapacity ~= nil and currentCap ~= ownedCapacity then
                md[INVENTORY_CAPACITY_APPLIED_KEY] = nil
                ownedCapacity = nil
            end

            local mayRaise = currentCap < targetCap
            local mayLowerOwned = currentCap > targetCap and ownedCapacity == currentCap
            if mayRaise or mayLowerOwned then
                local setOk = pcall(inv.setCapacity, inv, targetCap)
                if setOk then
                    md[INVENTORY_CAPACITY_APPLIED_KEY] = targetCap
                end
            end
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

-- Stores a bleed-decay multiplier in moddata. Named sources use independent
-- multiplicative buckets so compatible traits cannot overwrite one another.
-- Anonymous callers retain the original scalar contract until their owning
-- trait receives an isolated migration.
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
function UTCore.applyBleedDecayMult(player, mult, bandagedOnly, sourceId)
    if sourceId ~= nil then
        local bucketName = bandagedOnly and BLEED_DECAY_BANDAGED_BUCKET or BLEED_DECAY_ALL_BUCKET
        setBucketValue(player, bucketName, sourceId, mult)
        return
    end

    local md = player:getModData()
    md["UT_bleedDecayMult"]        = mult
    md["UT_bleedDecayBandagedOnly"] = bandagedOnly and true or false
end

-- Stores "UT_bleedDrainMult" in moddata.
-- UTCore_BleedDrainHook reads this after each native BLEEDING damage event and
-- applies the exact inverse or additional BodyDamage distribution needed to
-- scale the effective death rate from active bleeding.
--
-- mult = 1.0 → no effect
-- mult = 2.0 → 2x faster death from bleeding (heavilybleedingwounds)
-- mult = 0.6 → 0.6x death rate, 40% offset added back (weaklybleedingwounds)
-- mult = 0.5 → 0.5x death rate, 50% offset added back (thickblood)
--
-- The event supplies the exact native damage after ReduceGeneralHealth applies.
function UTCore.applyBleedDrainMult(player, mult)
    player:getModData()["UT_bleedDrainMult"] = mult
end

UTCore._vehicleTraitDefs = UTCore._vehicleTraitDefs or {}
UTCore._vehicleTraitActiveVehicles = UTCore._vehicleTraitActiveVehicles or {}
UTCore._vehicleTraitTrackedPlayer = UTCore._vehicleTraitTrackedPlayer or nil

local VEHICLE_OWNERSHIP_KEY = "UT_vehicleTraitOwnership"
local MAX_RESTORE_ATTEMPTS = 2
local ENGINE_FIELDS = {
    engineQuality = true,
    engineLoudness = true,
    enginePower = true,
}
local FIELD_ACCESS = {
    maxSpeed = { get = "getMaxSpeed", set = "setMaxSpeed" },
    brakingForce = { get = "getBrakingForce", set = "setBrakingForce" },
    engineQuality = { get = "getEngineQuality" },
    engineLoudness = { get = "getEngineLoudness" },
    enginePower = { get = "getEnginePower" },
    initialMass = { get = "getInitialMass", set = "setInitialMass" },
}

local function vehicleCall(receiver, methodName, ...)
    local method = receiver and receiver[methodName]
    if type(method) ~= "function" then return false, nil end
    return pcall(method, receiver, ...)
end

local function readVehicleField(vehicle, field)
    local access = FIELD_ACCESS[field]
    if not access then return false, nil end
    return vehicleCall(vehicle, access.get)
end

local function nearestInteger(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function truncateInteger(value)
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

-- BaseVehicle.setEngineFeature stores (int)(inputLoudness / 2.7).
-- Target the nearest representable stored integer, with exact .5 ties rounded
-- away from zero. The midpoint input avoids binary underflow at n * 2.7.
local function loudnessTargetAndInput(desiredStored)
    local stored = nearestInteger(desiredStored)
    return stored, (stored + (stored >= 0 and 0.5 or -0.5)) * 2.7
end

local function selectedVehicleTrait(player)
    local selected = nil
    for _, def in ipairs(UTCore._vehicleTraitDefs) do
        if UTCore.hasTrait(player, def.traitId) then
            if not selected
                or def.priority > selected.priority
                or (def.priority == selected.priority and def.traitId < selected.traitId) then
                selected = def
            end
        end
    end
    return selected
end

local function getOwnership(vehicle)
    local ok, vmd = vehicleCall(vehicle, "getModData")
    if not ok or type(vmd) ~= "table" then return nil, nil end
    local ownership = vmd[VEHICLE_OWNERSHIP_KEY]
    if type(ownership) ~= "table" then
        ownership = { fields = {}, suppressed = {} }
        vmd[VEHICLE_OWNERSHIP_KEY] = ownership
    end
    if type(ownership.fields) ~= "table" then ownership.fields = {} end
    if type(ownership.suppressed) ~= "table" then ownership.suppressed = {} end
    if type(ownership.restoreAttempts) ~= "table" then ownership.restoreAttempts = {} end
    return vmd, ownership
end

local function clearOwnership(vmd)
    if vmd then vmd[VEHICLE_OWNERSHIP_KEY] = nil end
end

local function restoreSimpleField(vehicle, ownership, field)
    local evidence = ownership.fields[field]
    if type(evidence) ~= "table" then return false end
    local ok, current = readVehicleField(vehicle, field)
    if not ok then return false end
    if current == evidence.baseline then
        ownership.fields[field] = nil
        ownership.restoreAttempts[field] = nil
        return true
    end
    if current ~= evidence.lastApplied then
        ownership.fields[field] = nil
        ownership.restoreAttempts[field] = nil
        return false
    end

    local attempts = ownership.restoreAttempts[field] or 0
    if attempts >= MAX_RESTORE_ATTEMPTS then return false end
    local access = FIELD_ACCESS[field]
    vehicleCall(vehicle, access.set, evidence.baseline)
    ownership.restoreAttempts[field] = attempts + 1

    local readOk, observed = readVehicleField(vehicle, field)
    if readOk and (observed == evidence.baseline or observed ~= evidence.lastApplied) then
        ownership.fields[field] = nil
        ownership.restoreAttempts[field] = nil
        return observed == evidence.baseline
    end
    return false
end

local function restoreEngineFields(vehicle, ownership)
    local values = {}
    local shouldWrite = false
    for field in pairs(ENGINE_FIELDS) do
        local ok, current = readVehicleField(vehicle, field)
        if ok then values[field] = current end
        local evidence = ownership.fields[field]
        if ok and type(evidence) == "table" then
            if current == evidence.baseline then
                ownership.fields[field] = nil
            elseif current == evidence.lastApplied then
                values[field] = evidence.baseline
                shouldWrite = true
            else
                ownership.fields[field] = nil
            end
        end
    end
    if not shouldWrite
        or values.engineQuality == nil
        or values.engineLoudness == nil
        or values.enginePower == nil then
        return
    end
    local attempts = ownership.restoreAttempts.engineFields or 0
    if attempts >= MAX_RESTORE_ATTEMPTS then return end
    local _, loudnessInput = loudnessTargetAndInput(values.engineLoudness)
    vehicleCall(vehicle, "setEngineFeature",
        values.engineQuality, loudnessInput, values.enginePower)
    ownership.restoreAttempts.engineFields = attempts + 1

    -- The grouped setter may mutate one or two fields before throwing. Only
    -- discard evidence after protected readback proves that field restored or
    -- no longer equals UTCore's last applied value.
    for field in pairs(ENGINE_FIELDS) do
        local evidence = ownership.fields[field]
        if type(evidence) == "table" then
            local ok, observed = readVehicleField(vehicle, field)
            if ok and (observed == evidence.baseline or observed ~= evidence.lastApplied) then
                ownership.fields[field] = nil
            end
        end
    end
end

local function hasOwnedFields(ownership)
    for _, evidence in pairs(ownership.fields) do
        if type(evidence) == "table" then return true end
    end
    return false
end

-- Restores only fields whose current observable value still matches UTCore's
-- last successful write. Foreign/native changes are preserved.
function UTCore.restoreVehicleMod(vehicle)
    if not vehicle then return true end
    local vmd, ownership = getOwnership(vehicle)
    if not ownership or ownership.stateKey == nil then return true end

    restoreSimpleField(vehicle, ownership, "maxSpeed")
    restoreSimpleField(vehicle, ownership, "brakingForce")
    restoreEngineFields(vehicle, ownership)
    local restoredInitialMass = restoreSimpleField(vehicle, ownership, "initialMass")
    if restoredInitialMass then vehicleCall(vehicle, "updateTotalMass") end
    if hasOwnedFields(ownership) then return false end
    clearOwnership(vmd)
    return true
end

local function desiredTargets(ownership, mods)
    local targets = {}
    local multipliers = {
        maxSpeed = mods.maxSpeed,
        brakingForce = mods.brakingForce,
        engineQuality = mods.engineQuality,
        engineLoudness = mods.engineLoudness,
        enginePower = mods.enginePower,
        initialMass = mods.mass,
    }
    for field, multiplier in pairs(multipliers) do
        local evidence = ownership.fields[field]
        if multiplier ~= nil and type(evidence) == "table" then
            local desired = evidence.baseline * multiplier
            if field == "engineQuality" then
                desired = clamp(truncateInteger(desired), 0, 100)
            elseif field == "engineLoudness" then
                desired = nearestInteger(desired)
            elseif field == "enginePower" then
                desired = truncateInteger(desired)
            end
            targets[field] = desired
        end
    end
    return targets
end

local function acquireFields(vehicle, ownership, mods)
    local multipliers = {
        maxSpeed = mods.maxSpeed,
        brakingForce = mods.brakingForce,
        engineQuality = mods.engineQuality,
        engineLoudness = mods.engineLoudness,
        enginePower = mods.enginePower,
        initialMass = mods.mass,
    }
    for field, multiplier in pairs(multipliers) do
        if multiplier ~= nil and not ownership.suppressed[field] then
            local ok, current = readVehicleField(vehicle, field)
            if ok and type(current) == "number" then
                ownership.fields[field] = {
                    baseline = current,
                    lastApplied = current,
                }
            end
        end
    end
end

local function fenceForeignChanges(vehicle, ownership)
    for field, evidence in pairs(ownership.fields) do
        local ok, current = readVehicleField(vehicle, field)
        if not ok or current ~= evidence.lastApplied then
            ownership.fields[field] = nil
            ownership.suppressed[field] = true
        end
    end
end

local function applySimpleTargets(vehicle, ownership, targets)
    local initialMassWritten = false
    for _, field in ipairs({ "maxSpeed", "brakingForce", "initialMass" }) do
        local target = targets[field]
        local evidence = ownership.fields[field]
        if target ~= nil and evidence and evidence.lastApplied ~= target then
            local access = FIELD_ACCESS[field]
            local setOk = vehicleCall(vehicle, access.set, target)
            local ok, observed = readVehicleField(vehicle, field)
            if ok then
                if not setOk and observed == evidence.lastApplied then
                    ownership.fields[field] = nil
                    ownership.suppressed[field] = true
                else
                    evidence.lastApplied = observed
                end
                if setOk and field == "initialMass" and observed == target then
                    initialMassWritten = true
                end
            end
        end
    end
    if initialMassWritten then vehicleCall(vehicle, "updateTotalMass") end
end

local function applyEngineTargets(vehicle, ownership, targets)
    local values = {}
    local needsWrite = false
    for field in pairs(ENGINE_FIELDS) do
        local ok, current = readVehicleField(vehicle, field)
        if not ok then return end
        values[field] = targets[field] ~= nil and targets[field] or current
        if targets[field] ~= nil and current ~= targets[field] then
            needsWrite = true
        end
    end
    if not needsWrite then return end

    local _, loudnessInput = loudnessTargetAndInput(values.engineLoudness)
    local setOk = vehicleCall(vehicle, "setEngineFeature",
        values.engineQuality, loudnessInput, values.enginePower)

    -- A Java bridge failure can occur after a partial grouped write. Read back
    -- every owned field so retry/restore evidence describes what was observed.
    for field in pairs(ENGINE_FIELDS) do
        local evidence = ownership.fields[field]
        if evidence then
            local ok, observed = readVehicleField(vehicle, field)
            if ok then
                if not setOk and observed == evidence.lastApplied then
                    ownership.fields[field] = nil
                    ownership.suppressed[field] = true
                else
                    evidence.lastApplied = observed
                end
            end
        end
    end
end

--- applyVehicleMod(player, stateKey, mods[, vehicleOverride])
-- Reconciles one selected state against per-field ownership evidence.
function UTCore.applyVehicleMod(player, stateKey, mods, vehicleOverride)
    if not player or not player.isDriving or not player:isDriving() then return end
    local vehicle = vehicleOverride or (player.getVehicle and player:getVehicle())
    if not vehicle then return end

    local vmd, ownership = getOwnership(vehicle)
    if not ownership then return end
    if ownership.stateKey ~= nil and ownership.stateKey ~= stateKey then
        if not UTCore.restoreVehicleMod(vehicle) then return end
        vmd, ownership = getOwnership(vehicle)
        if not ownership then return end
    end

    if ownership.stateKey == nil then
        ownership.stateKey = stateKey
        ownership.fields = {}
        ownership.suppressed = {}
        acquireFields(vehicle, ownership, mods)
        if UTSmoke and UTSmoke.record then
            UTSmoke.record("vehicle.runtime", stateKey)
        end
    else
        fenceForeignChanges(vehicle, ownership)
    end

    local targets = desiredTargets(ownership, mods)
    applySimpleTargets(vehicle, ownership, targets)
    applyEngineTargets(vehicle, ownership, targets)
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

    if not player.isDriving or not player:isDriving() then
        UTCore.restoreVehicleMod(targetVehicle)
        return
    end

    local selected = selectedVehicleTrait(player)
    if not selected then
        UTCore.restoreVehicleMod(targetVehicle)
        return
    end

    UTCore.applyVehicleMod(player, selected.stateKey, selected.mods, targetVehicle)
end

-- Tracks the engine's real one-argument OnEnterVehicle contract and detects
-- exit/vehicle switches from the player's current vehicle reference. Exit is
-- intentionally edge-detected here because OnExitVehicle is not in the core
-- event registry during shared-mod loading.
function UTCore.updateVehicleTraitState(player)
    if not player then return end

    local previous = UTCore._vehicleTraitActiveVehicles[player]
    local current = player.getVehicle and player:getVehicle() or nil
    local valid = not player.isDead or not player:isDead()
    if previous and (previous ~= current or not valid) then
        if UTCore.restoreVehicleMod(previous) then
            UTCore._vehicleTraitActiveVehicles[player] = nil
        else
            return
        end
    end
    if not valid then return end
    if current then
        UTCore.syncVehicleTrait(player, current)
        UTCore._vehicleTraitActiveVehicles[player] = current
    end
end

if not UTCore._modifierAggregationEventsRegistered then
    local function onCreatePlayer(_playerIndex, player)
        -- Preserve the compatibility invalidation boundary before reconciliation.
        if UTCore.invalidateTraitCache then UTCore.invalidateTraitCache() end
        UTCore.reconcileAggregatedModifiers(player)
    end

    -- Core handler: reconcile carry weight inside central dispatch.
    -- Throttled to every 30 ticks (~1/sec) because carry weight changes
    -- only when modifier buckets change, which already triggers an immediate
    -- refreshAggregatedModifierCache via the apply* API functions.
    -- This handler is defense-in-depth, not the primary setter.
    local function coreReconcile(player, tick)
        UTCore.reconcileAggregatedModifiers(player)
    end

    if UTCore.registerCoreHandler then
        UTCore.registerCoreHandler("StatModifiers.reconcile", coreReconcile, {
            throttle = 30,
            priority = -10,  -- low priority, runs after other core handlers
        })
    end

    if Events and Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end

    UTCore._modifierAggregationEventsRegistered = true
end

if not UTCore._vehicleTraitEventsRegistered then
    local function onEnterVehicle(player)
        UTCore.updateVehicleTraitState(player)
    end

    local function onCreatePlayer(_playerIndex, player)
        local replaced = UTCore._vehicleTraitTrackedPlayer
        if replaced and replaced ~= player then
            local replacedVehicle = UTCore._vehicleTraitActiveVehicles[replaced]
            if replacedVehicle then UTCore.restoreVehicleMod(replacedVehicle) end
            UTCore._vehicleTraitActiveVehicles[replaced] = nil
        end
        UTCore._vehicleTraitTrackedPlayer = player
        UTCore._vehicleTraitActiveVehicles[player] = nil
        UTCore.updateVehicleTraitState(player)
    end

    if UTCore.registerCoreHandler then
        UTCore.registerCoreHandler("StatModifiers.vehicleState", function(player)
            UTCore.updateVehicleTraitState(player)
        end, { priority = -9 })
    elseif Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(UTCore.updateVehicleTraitState)
    end

    if Events and Events.OnEnterVehicle then
        Events.OnEnterVehicle.Add(onEnterVehicle)
    end

    if Events and Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end

    UTCore._vehicleTraitEventsRegistered = true
end
