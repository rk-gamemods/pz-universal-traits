-- UT_accmetabolism.lua
-- Accelerated Metabolism: burns through food and water faster

local TRAIT_ID = "UniversalTraits:UT_accmetabolism"

UTTraitRuntimeHandlers = UTTraitRuntimeHandlers or {}

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if not stats then return end
    stats:set(CharacterStat.HUNGER, math.min(1, stats:get(CharacterStat.HUNGER) + 0.05))
    stats:set(CharacterStat.THIRST, math.min(1, stats:get(CharacterStat.THIRST) + 0.03))
end

local previousHandler = UTTraitRuntimeHandlers[TRAIT_ID]
if previousHandler then
    Events.EveryTenMinutes.Remove(previousHandler)
end
UTTraitRuntimeHandlers[TRAIT_ID] = handler
Events.EveryTenMinutes.Add(handler)
