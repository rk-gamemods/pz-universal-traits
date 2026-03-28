-- UT_nervouswreck.lua
-- Nervous wreck: strong panic amplifier, stress-triggered panic spikes

local TRAIT_ID = "UniversalTraits:UT_nervouswreck"

local function onPanic(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setPanic(math.min(1, stats:getPanic() + 0.3))
end

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    if stats:getStress() > 0.7 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.05))
    end
end

Events.OnPanic.Add(onPanic)
Events.EveryTenMinutes.Add(onEveryTenMinutes)
