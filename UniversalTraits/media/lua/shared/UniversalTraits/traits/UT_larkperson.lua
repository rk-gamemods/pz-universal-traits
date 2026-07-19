-- UT_larkperson.lua
-- Reduces stress during day, increases stress at night

local TRAIT_ID = "UniversalTraits:UT_larkperson"

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local timeOfDay = getGameTime():getTimeOfDay()
    local stats = player:getStats()
    local stress = stats:get(CharacterStat.STRESS)

    -- GameTime.getTimeOfDay() is a 0..24 hour clock; day is 06:00..<18:00.
    if timeOfDay >= 6 and timeOfDay < 18 then
        -- Day: reduce stress
        stats:set(CharacterStat.STRESS, math.max(0, stress - 0.02))
    else
        -- Night: increase stress (balanced to match day relief — net zero over a full day)
        stats:set(CharacterStat.STRESS, math.min(1, stress + 0.02))
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
