-- UT_fearful.lua
-- Fearful: panic boost on panic trigger

local TRAIT_ID = "UniversalTraits:UT_fearful"

local function onPanic(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setPanic(math.min(1, stats:getPanic() + 0.2))
end

Events.OnPanic.Add(onPanic)
