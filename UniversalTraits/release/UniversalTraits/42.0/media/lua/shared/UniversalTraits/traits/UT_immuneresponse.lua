-- UT_immuneresponse.lua
-- Immune Response: accelerated infection clearance and mild fatigue reduction

local TRAIT_ID = "UniversalTraits:UT_immuneresponse"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local infectionLevel = stats:get(CharacterStat.ZOMBIE_INFECTION)
    if infectionLevel and infectionLevel > 0 then
        stats:set(CharacterStat.ZOMBIE_INFECTION, math.max(0, infectionLevel - 3))
    end
    stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - 0.02))
end

Events.EveryTenMinutes.Add(handler)
