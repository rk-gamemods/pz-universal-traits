-- UT_unwavering.lua
-- Unwavering: passive panic drain every 10 in-game minutes.
-- Reduces panic by 0.1 whenever it is above 0.1, slowly suppressing
-- long-term panic accumulation without preventing immediate spikes.

local TRAIT_ID = "UniversalTraits:UT_unwavering"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local panic = stats:getPanic()
    if panic > 0.1 then
        stats:setPanic(math.max(0, panic - 0.1))
    end
end

Events.EveryTenMinutes.Add(handler)
