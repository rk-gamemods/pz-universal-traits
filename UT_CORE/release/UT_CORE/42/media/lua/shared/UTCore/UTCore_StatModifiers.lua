-- UTCore_StatModifiers.lua
-- Stat modifier application helpers.
-- Phase 2 implementation.

UTCore = UTCore or {}

-- Stores speed delta in ModData for OnPlayerUpdate handler.
-- amount is a float delta, e.g. 0.3 for +30% speed.
function UTCore.applySpeedModifier(player, amount)
    player:getModData()["UT_speedMod"] = amount
end

-- Calls player:setMaxWeightBase(base + delta).
function UTCore.applyCarryWeight(player, delta)
    local base = player:getMaxWeightBase()
    player:setMaxWeightBase(base + delta)
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
function UTCore.applyWorkSpeed(player, delta)
    player:getModData()["UT_workSpeedMod"] = delta
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

-- Calls player:getStats():setStress(current + amount) directly if amount > 0.
-- Stores "UT_moodMod" = amount in moddata for periodic checks.
function UTCore.applyMoodModifier(player, amount)
    if amount > 0 then
        local stats = player:getStats()
        stats:setStress(stats:getStress() + amount)
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

--- applyStrengthCarryWeight(player, bonus)
-- Sets carry weight dynamically based on Strength: base = 5 + Strength + bonus.
-- Call every OnPlayerUpdate tick for strength-scaled carry weight traits.
function UTCore.applyStrengthCarryWeight(player, bonus)
    local strength = player:getPerkLevel(Perks.Strength)
    player:setMaxWeightBase(5 + strength + bonus)
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

--- applyVehicleMod(player, stateKey, mods)
-- Applies vehicle stat multipliers idempotently using a per-vehicle state key.
-- Records baseline values on first call, applies mods once, then no-ops.
-- mods table keys (all optional, default 1.0): maxSpeed, brakingForce,
--   engineQuality, engineLoudness, enginePower, mass
-- stateKey: unique string per driver tier, stored in vehicle moddata.
function UTCore.applyVehicleMod(player, stateKey, mods)
    if not player:isDriving() then return end
    local vehicle = player:getVehicle()
    if not vehicle then return end
    local vmd = vehicle:getModData()
    if vmd.UT_baseMaxSpeed == nil then
        vmd.UT_baseMaxSpeed     = vehicle:getMaxSpeed()
        vmd.UT_baseBrakingForce = vehicle:getBrakingForce()
        vmd.UT_baseEnginePower  = vehicle:getEnginePower()
        vmd.UT_baseMass         = vehicle:getMass()
        vmd.UT_baseInitialMass  = vehicle:getInitialMass()
        vmd[stateKey]           = "Normal"
    end
    if vmd[stateKey] == stateKey then return end
    vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed * (mods.maxSpeed or 1.0))
    vehicle:setBrakingForce(vmd.UT_baseBrakingForce * (mods.brakingForce or 1.0))
    vehicle:setEngineFeature(
        vehicle:getEngineQuality() * (mods.engineQuality or 1.0),
        vehicle:getEngineLoudness() * (mods.engineLoudness or 1.0),
        vmd.UT_baseEnginePower * (mods.enginePower or 1.0)
    )
    vehicle:setMass(vmd.UT_baseMass * (mods.mass or 1.0))
    vehicle:setInitialMass(vmd.UT_baseInitialMass * (mods.mass or 1.0))
    vehicle:updateTotalMass()
    vmd[stateKey] = stateKey
end
