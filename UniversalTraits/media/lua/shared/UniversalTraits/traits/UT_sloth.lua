-- UT_sloth.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWSloth().
-- EveryOneMinute: while walking or idle, reduce fatigue accumulation.

local TRAIT_ID = "UniversalTraits:UT_sloth"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isRunning() or player:isSprinting() then return end
    local stats = player:getStats()
    stats:remove(CharacterStat.FATIGUE, GameTime.getInstance():getMultiplier() * 0.0005)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
