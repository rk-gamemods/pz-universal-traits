-- UT_mstoptimist.lua
-- Silver Lining: stress reduction amplifies when stress is high

local TRAIT_ID = "UniversalTraits:UT_mstoptimist"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if stats:get(CharacterStat.STRESS) > 0.6 then
        stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.08))
    else
        stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.03))
    end
end

Events.EveryTenMinutes.Add(handler)
