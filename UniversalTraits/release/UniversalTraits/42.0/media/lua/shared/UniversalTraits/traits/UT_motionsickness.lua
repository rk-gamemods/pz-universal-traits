-- UT_motionsickness.lua
-- Motion sickness: stress buildup while in vehicle

local TRAIT_ID = "UniversalTraits:UT_motionsickness"

local function onTick(_player, tick)
    if tick.vehicle ~= nil then
        local stats = tick.stats
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.01))
    end
end

if not UTCore._motionSicknessTickRegistered then
    UTCore.registerTickHandler(TRAIT_ID, onTick, { vehicleAware = true, throttle = 60 })
    UTCore._motionSicknessTickRegistered = true
end
