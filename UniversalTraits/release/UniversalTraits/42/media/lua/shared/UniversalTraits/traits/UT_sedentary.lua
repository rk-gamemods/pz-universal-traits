-- UT_sedentary.lua
-- Sedentary: endurance slowly degrades from inactive lifestyle

local TRAIT_ID = "UniversalTraits:UT_sedentary"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setEndurance(math.max(0, stats:getEndurance() - 0.01))
    player:getModData()["UT_sedentaryPenalty"] = true
end

Events.EveryHours.Add(handler)
