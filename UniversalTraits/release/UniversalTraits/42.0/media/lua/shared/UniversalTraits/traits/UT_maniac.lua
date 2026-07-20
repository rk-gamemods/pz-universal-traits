-- UT_maniac.lua
-- Maniac: combat mood boost on kill

local TRAIT_ID = "UniversalTraits:UT_maniac"

local function onKill(zombie)
    if not instanceof(zombie, "IsoZombie") then return end

    local player = zombie:getAttackedBy()
    if not instanceof(player, "IsoPlayer") then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.15))
    stats:set(CharacterStat.BOREDOM, math.max(0, stats:get(CharacterStat.BOREDOM) - 0.20))
end

if UTManiac_onZombieDead then
    Events.OnZombieDead.Remove(UTManiac_onZombieDead)
end
UTManiac_onZombieDead = onKill
Events.OnZombieDead.Add(UTManiac_onZombieDead)
