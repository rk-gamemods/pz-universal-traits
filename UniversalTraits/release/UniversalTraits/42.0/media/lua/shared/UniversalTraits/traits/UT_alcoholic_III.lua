-- UT_alcoholic_III.lua
-- Alcoholic III: severe constant alcohol craving with stress and panic when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_III"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local drunkenness = stats:get(CharacterStat.INTOXICATION)
    if drunkenness < 10 then
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.05))
    end
    if drunkenness < 5 then
        stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 3))
    end
end

Events.EveryOneMinute.Add(handler)
