-- UT_bigorexia.lua
-- Bigorexia: body image anxiety causes constant stress, worse when physically weak

local TRAIT_ID = "UniversalTraits:UT_bigorexia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.04))
    if player:getPerkLevel(Perks.Strength) < 5 then
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.02))
    end
end

Events.EveryTenMinutes.Add(handler)
