-- UT_acrophobic.lua
-- Acrophobic: height fear

local TRAIT_ID = "UniversalTraits:UT_acrophobic"

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    if player:getZ() > 0 then
        local stats = player:getStats()
        stats:setPanic(math.min(1, stats:getPanic() + 0.05))
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)
