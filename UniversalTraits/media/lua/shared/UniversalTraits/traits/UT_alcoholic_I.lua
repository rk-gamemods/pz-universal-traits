-- UT_alcoholic_I.lua
-- Alcoholic I: mild alcohol craving triggers stress every ~30 in-game minutes when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_I"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local md = player:getModData()
    md.UT_alcoholicI_ticks = (md.UT_alcoholicI_ticks or 0) + 1
    if md.UT_alcoholicI_ticks % 3 ~= 0 then return end
    local stats = player:getStats()
    if stats:getDrunkenness() < 0.05 then
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
