-- UT_paranoia.lua
-- Paranoia: gradually increases panic over time

local TRAIT_ID = "UniversalTraits:UT_paranoia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 6))
end

Events.EveryTenMinutes.Add(handler)
