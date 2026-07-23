-- UT_squirrel.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWSquirrel().
-- EveryOneMinute: while running or sprinting, reduce fatigue accumulation.

local TRAIT_ID = "UniversalTraits:UT_squirrel"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if not (player:isRunning() or player:isSprinting()) then return end
    local stats = player:getStats()
    stats:remove(CharacterStat.FATIGUE, 0.0015)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
