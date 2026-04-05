-- UT_optimist.lua
-- Optimist: naturally sheds stress and panic over time

local TRAIT_ID = "UniversalTraits:UT_optimist"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.06))
    stats:set(CharacterStat.PANIC, math.max(0, stats:get(CharacterStat.PANIC) - 4))
end

Events.EveryTenMinutes.Add(handler)
