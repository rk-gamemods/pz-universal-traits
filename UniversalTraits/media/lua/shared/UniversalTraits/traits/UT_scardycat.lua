-- UT_scardycat.lua
-- Scaredy cat: minor panic amplifier

local TRAIT_ID = "UniversalTraits:UT_scardycat"

local function onPanic(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setPanic(math.min(1, stats:getPanic() + 0.15))
end

Events.OnPanic.Add(onPanic)
