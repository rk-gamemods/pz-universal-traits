-- UT_fearofthedark.lua
-- Fear of the Dark: panic rises in actual darkness, subsides in bright light.
-- Uses square light level (0.0 = pitch black, 1.0 = fully lit).
-- Below 0.3 = dark  → panic +0.04/min
-- Above 0.7 = bright → panic -0.01/min
-- 0.3–0.7 = dim       → no change
-- Indoor lighting counts; time of day alone does not.

local TRAIT_ID = "UniversalTraits:UT_fearofthedark"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local sq = player:getCurrentSquare()
    if not sq then return end
    local lightLevel = sq:getLightLevel(player:getPlayerNum())
    local stats = player:getStats()
    if lightLevel < 0.3 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.04))
    elseif lightLevel > 0.7 then
        stats:setPanic(math.max(0, stats:getPanic() - 0.01))
    end
end

Events.EveryOneMinute.Add(handler)
