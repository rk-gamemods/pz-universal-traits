-- UT_addictedtocaffeine.lua
-- Addicted to Caffeine: stress builds without recent caffeine consumption

local TRAIT_ID = "UniversalTraits:UT_addictedtocaffeine"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local md = player:getModData()
    if not md["UT_hadCaffeine"] then
        local stats = player:getStats()
        stats:setStress(math.min(1, stats:getStress() + 0.06))
    end
    md["UT_hadCaffeine"] = nil
end

Events.EveryTenMinutes.Add(handler)
