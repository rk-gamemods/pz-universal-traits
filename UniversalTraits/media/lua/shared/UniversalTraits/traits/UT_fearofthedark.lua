-- UT_fearofthedark.lua
-- Fear of the Dark: panic rises at night, slowly subsides during the day
-- Night detection: getTimeOfDay() < 0.25 or > 0.75 (6pm-6am), matching owlperson/larkperson pattern.
-- getNight() returns a float and is always truthy in Lua even at 0.0 (daytime) — do not use.

local TRAIT_ID = "UniversalTraits:UT_fearofthedark"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local timeOfDay = getGameTime():getTimeOfDay()
    -- Night is roughly 6pm-6am (timeOfDay < 0.25 or timeOfDay > 0.75)
    if timeOfDay < 0.25 or timeOfDay > 0.75 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.04))
    else
        stats:setPanic(math.max(0, stats:getPanic() - 0.01))
    end
end

Events.EveryOneMinute.Add(handler)
