-- UT_sundayrunner.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWSundayRunner().
-- EveryOneMinute: while sprinting, unhappiness increases.

local TRAIT_ID = "UniversalTraits:UT_sundayrunner"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if not player:isSprinting() then return end
    local stats = player:getStats()
    stats:add(CharacterStat.UNHAPPINESS, 2.0)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
