-- UT_immuneresponse.lua
-- Immune Response: accelerated infection clearance and mild fatigue reduction

local TRAIT_ID = "UniversalTraits:UT_immuneresponse"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        local infectionLevel = bodyDamage:getInfectionLevel()
        if infectionLevel and infectionLevel > 0 then
            bodyDamage:setInfectionLevel(math.max(0, infectionLevel - 0.03))
        end
    end
    local stats = player:getStats()
    stats:setFatigue(math.max(0, stats:getFatigue() - 0.02))
end

Events.EveryTenMinutes.Add(handler)
