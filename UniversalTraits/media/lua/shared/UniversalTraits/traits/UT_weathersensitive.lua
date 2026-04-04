-- UT_weathersensitive.lua
-- Weather Sensitive: stress rises in rain, small relief on clear sunny days

local TRAIT_ID = "UniversalTraits:UT_weathersensitive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local cm = getClimateManager()
    if not cm then return end
    local stats = player:getStats()
    local precip = cm:getPrecipitationIntensity()
    if precip > 0.3 then
        -- Raining: stress goes up
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    elseif cm:getCloudIntensity() < 0.2 then
        -- Clear and sunny: small stress relief
        stats:setStress(math.max(0, stats:getStress() - 0.02))
    end
    -- Overcast but dry: no effect
end

Events.EveryTenMinutes.Add(handler)
