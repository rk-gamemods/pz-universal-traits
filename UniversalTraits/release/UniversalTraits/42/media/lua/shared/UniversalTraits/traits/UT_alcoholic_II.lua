-- UT_alcoholic_II.lua
-- Alcoholic II: moderate alcohol craving triggers significant stress when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_II"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if stats:get(CharacterStat.INTOXICATION) < 5 then
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.10))
    end
end

Events.EveryTenMinutes.Add(handler)
