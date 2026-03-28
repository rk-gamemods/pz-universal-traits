-- UT_fearofthedark.lua
-- Fear of the Dark: panic rises at night, slowly subsides during the day

local TRAIT_ID = "UniversalTraits:UT_fearofthedark"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if getGameTime():getNight() then
        stats:setPanic(math.min(1, stats:getPanic() + 0.04))
    else
        stats:setPanic(math.max(0, stats:getPanic() - 0.01))
    end
end

Events.EveryOneMinute.Add(handler)
