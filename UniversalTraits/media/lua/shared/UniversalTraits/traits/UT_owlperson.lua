-- UT_owlperson.lua
-- Reduces stress at night, increases stress during day

local TRAIT_ID = "UniversalTraits:UT_owlperson"

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local timeOfDay = getGameTime():getTimeOfDay()
    local stats = player:getStats()
    local stress = stats:get(CharacterStat.STRESS)

    -- GameTime.getTimeOfDay() is a 0..24 hour clock; night is 18:00..<06:00.
    if timeOfDay < 6 or timeOfDay >= 18 then
        -- Night: reduce stress
        stats:set(CharacterStat.STRESS, math.max(0, stress - 0.02))
    else
        -- Day: increase stress (balanced to match night relief — net zero over a full day)
        stats:set(CharacterStat.STRESS, math.min(1, stress + 0.02))
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
