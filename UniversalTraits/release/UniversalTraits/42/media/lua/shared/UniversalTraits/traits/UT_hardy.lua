-- UT_hardy.lua
-- Endurance tracking with sub-exhaustion states and recovery bonus.

local TRAIT_ID = "UniversalTraits:UT_hardy"

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local moddata = player:getModData()
    local fatigue = stats:getFatigue()
    local now = getGameTime():getWorldAgeHours()

    -- Bonus phase
    if moddata["UT_hardyBonus"] then
        local bonusAge = now - moddata["UT_hardyBonus"]
        if bonusAge < (5 / 60.0) then
            stats:setEndurance(math.min(stats:getMaxEndurance(), stats:getEndurance() + 0.002))
        else
            moddata["UT_hardyBonus"] = nil
        end
    end

    -- Sub-exhaustion tracking
    if not moddata["UT_hardyExhausted"] then
        if fatigue > 0.8 then
            moddata["UT_hardyExhausted"] = true
            moddata["UT_hardyExhaustedAt"] = now
            moddata["UT_hardyRestingMins"] = 0
        end
    else
        stats:setStress(math.min(1, stats:getStress() + 0.02))
        if fatigue < 0.3 then
            moddata["UT_hardyRestingMins"] = (moddata["UT_hardyRestingMins"] or 0) + 1
        else
            moddata["UT_hardyRestingMins"] = 0
        end
        if (moddata["UT_hardyRestingMins"] or 0) >= 10 then
            moddata["UT_hardyExhausted"] = nil
            moddata["UT_hardyExhaustedAt"] = nil
            moddata["UT_hardyRestingMins"] = nil
            moddata["UT_hardyBonus"] = now
        end
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
