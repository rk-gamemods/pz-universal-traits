-- UT_highsweaty.lua
-- Source: MoreSimpleTraits MSTMainFile.lua — highsweatytrait() + highsweatyattack().
-- EveryOneMinute: movement-based wetness and thirst increase.
-- OnWeaponSwingHitPoint: combat sweat increases wetness and thirst.

local TRAIT_ID = "UniversalTraits:UT_highsweaty"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local bd = player:getBodyDamage()
    if not bd then return end
    local stats = player:getStats()
    local wetness = bd:getWetness()

    if player:isSprinting() then
        bd:setWetness(math.min(wetness + 0.05, 1.0))
        stats:add(CharacterStat.THIRST, 0.03)
    elseif player:isRunning() then
        bd:setWetness(math.min(wetness + 0.03, 1.0))
        stats:add(CharacterStat.THIRST, 0.02)
    else
        bd:setWetness(math.min(wetness + 0.01, 1.0))
    end
end

local function onWeaponSwing(attacker, weapon, target, hitPoint)
    if not attacker or not UTCore.hasTrait(attacker, TRAIT_ID) then return end
    if weapon == nil then return end
    local bd = attacker:getBodyDamage()
    if not bd then return end
    local stats = attacker:getStats()
    bd:setWetness(math.min(bd:getWetness() + 0.02, 1.0))
    stats:add(CharacterStat.THIRST, 0.01)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
Events.OnWeaponSwingHitPoint.Add(onWeaponSwing)
