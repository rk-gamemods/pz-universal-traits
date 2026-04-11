-- UT_panicattacks.lua
-- Panic Attacks: 5% chance per minute of a sudden severe panic spike

local TRAIT_ID = "UniversalTraits:UT_panicattacks"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if ZombRand(20) == 0 then
        local stats = player:getStats()
        stats:set(CharacterStat.PANIC, math.min(100, stats:get(CharacterStat.PANIC) + 40))
    end
end

Events.EveryOneMinute.Add(handler)
