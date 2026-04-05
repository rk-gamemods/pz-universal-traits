-- UT_albino.lua
-- Albino: UV sensitivity causes stress and fatigue when outdoors during daytime

local TRAIT_ID = "UniversalTraits:UT_albino"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isOutside() then
        local timeOfDay = getGameTime():getTimeOfDay()
        if timeOfDay >= 0.25 and timeOfDay <= 0.75 then
            local stats = player:getStats()
            stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.03))
            stats:set(CharacterStat.FATIGUE, math.min(1, stats:get(CharacterStat.FATIGUE) + 0.02))
            player:getModData()["UT_albinoDamage"] = true
        else
            player:getModData()["UT_albinoDamage"] = false
        end
    else
        player:getModData()["UT_albinoDamage"] = false
    end
end

Events.EveryOneMinute.Add(handler)
