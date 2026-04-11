-- UTCore_ThermalRegulationHook.lua
-- Shared runtime connector for wetness reduction and temperature relief profiles.
-- Traits configure their own numbers in moddata through UTCore APIs.

UTCore = UTCore or {}

local function getWetnessReduction(player, md)
    if player:isOutside() and RainManager.isRaining() then
        return md["UT_wetnessReductionRain"]
    end

    if player:isOutside() then
        return md["UT_wetnessReductionOutdoor"]
    end

    return md["UT_wetnessReductionIndoor"]
end

local function applyWetnessReduction(player, stats, md)
    local wetness = stats:get(CharacterStat.WETNESS)
    if wetness <= 0 then return end

    local reduction = getWetnessReduction(player, md)
    if not reduction or reduction <= 0 then return end

    stats:set(CharacterStat.WETNESS, math.max(0, wetness - reduction))
end

local function applyThermalRelief(stats, md)
    local comfortFloor = md["UT_thermalComfortFloor"]
    local warmThreshold = md["UT_thermalWarmThreshold"]
    local hotThreshold = md["UT_thermalHotThreshold"]
    local warmCooling = md["UT_thermalWarmCooling"]
    local hotCooling = md["UT_thermalHotCooling"]

    if not comfortFloor or not warmThreshold or not hotThreshold or not warmCooling or not hotCooling then
        return
    end

    local temperature = stats:get(CharacterStat.TEMPERATURE)
    if temperature > hotThreshold then
        stats:set(CharacterStat.TEMPERATURE, math.max(comfortFloor, temperature - hotCooling))
    elseif temperature > warmThreshold then
        stats:set(CharacterStat.TEMPERATURE, math.max(comfortFloor, temperature - warmCooling))
    end
end

local function onEveryOneMinute()
    local player = getPlayer and getPlayer() or nil
    if not player then return end
    if player:isAsleep() then return end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("environment.time-and-climate", "thermal-minute")
        UTSmoke.record("player.stats", "thermal-minute")
    end

    local md = player:getModData()
    local stats = player:getStats()

    applyWetnessReduction(player, stats, md)
    applyThermalRelief(stats, md)
end

if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(onEveryOneMinute)
end