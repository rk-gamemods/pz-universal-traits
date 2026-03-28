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

-- Stores "UT_bleedMult" in moddata; actual application done by trait handler.
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
