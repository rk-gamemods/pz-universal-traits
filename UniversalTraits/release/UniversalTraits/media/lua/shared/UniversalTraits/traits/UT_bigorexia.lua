-- UT_bigorexia.lua
-- Bigorexia: body image anxiety causes constant stress, worse when physically weak

local TRAIT_ID = "UniversalTraits:UT_bigorexia"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setStress(math.min(1, stats:getStress() + 0.04))
    if player:getPerkLevel(Perks.Strength) < 5 then
        stats:setStress(math.min(1, stats:getStress() + 0.02))
    end
end

Events.EveryTenMinutes.Add(handler)
