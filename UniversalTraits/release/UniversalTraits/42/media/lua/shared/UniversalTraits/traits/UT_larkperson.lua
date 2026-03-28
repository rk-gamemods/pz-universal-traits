-- UT_larkperson.lua
-- Reduces stress during day, increases stress at night

local TRAIT_ID = "UniversalTraits:UT_larkperson"

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local timeOfDay = getGameTime():getTimeOfDay()
    local stats = player:getStats()
    local stress = stats:getStress()

    -- Day is roughly 6am-6pm (timeOfDay >= 0.25 and timeOfDay <= 0.75)
    if timeOfDay >= 0.25 and timeOfDay <= 0.75 then
        -- Day: reduce stress
        stats:setStress(math.max(0, stress - 0.02))
    else
        -- Night: increase stress
        stats:setStress(math.min(1, stress + 0.01))
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
