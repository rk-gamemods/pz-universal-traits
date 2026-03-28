-- UT_fearful.lua
-- Fearful: panic amplifier — checked periodically; boosts panic while it is active

local TRAIT_ID = "UniversalTraits:UT_fearful"

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local panic = stats:getPanic()
    if panic > 0 then
        stats:setPanic(math.min(1, panic + 0.2))
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
