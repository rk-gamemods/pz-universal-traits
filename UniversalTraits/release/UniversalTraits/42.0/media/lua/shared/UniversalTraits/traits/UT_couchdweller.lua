-- UT_couchdweller.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWCouchDweller().
-- EveryOneMinute: while indoors, reduce boredom and unhappiness passively.

local TRAIT_ID = "UniversalTraits:UT_couchdweller"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isOutside() then return end
    local stats = player:getStats()
    stats:remove(CharacterStat.BOREDOM, 1.0)
    stats:remove(CharacterStat.UNHAPPINESS, 1.0)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
