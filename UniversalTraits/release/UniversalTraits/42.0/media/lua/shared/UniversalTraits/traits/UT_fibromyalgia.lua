-- UT_fibromyalgia.lua
-- Fibromyalgia: chronic pain causes persistent stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_fibromyalgia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.07))
    stats:set(CharacterStat.FATIGUE, math.min(1, stats:get(CharacterStat.FATIGUE) + 0.05))
end

Events.EveryTenMinutes.Add(handler)
