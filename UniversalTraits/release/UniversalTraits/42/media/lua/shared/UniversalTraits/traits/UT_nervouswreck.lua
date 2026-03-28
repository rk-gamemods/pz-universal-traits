-- UT_nervouswreck.lua
-- Nervous wreck: strong panic amplifier, stress-triggered panic spikes.
-- Panic amplification is checked every ten minutes (no OnPanic event in B42).

local TRAIT_ID = "UniversalTraits:UT_nervouswreck"

local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local panic = stats:getPanic()
    -- Amplify any existing panic
    if panic > 0 then
        stats:setPanic(math.min(1, panic + 0.3))
    end
    -- Extra spike when highly stressed
    if stats:getStress() > 0.7 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.05))
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
