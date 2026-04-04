-- UT_idealweight.lua
-- Your body fights to maintain ideal weight.
-- Weight >= 84 (overweight+): 2x calorie burn rate.
-- Weight <= 76 (underweight or worse): 0.5x calorie burn rate.
-- Weight 75-85 (normal): no effect.
--
-- Implementation: each tick we measure the actual calorie delta the game applied
-- (by comparing stored previous calories to current calories), then apply an
-- additional multiplier on top of whatever the real burn rate was — idle, running,
-- sprinting, crafting, anything.
-- Weight is cached from EveryOneMinute to avoid per-tick getNutrition calls.

local TRAIT_ID              = "UniversalTraits:UT_idealweight"
local OVERWEIGHT_THRESHOLD  = 84.0
local UNDERWEIGHT_THRESHOLD = 76.0

-- Cache weight every in-game minute
UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", function(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.setModData(player, "idealweightCache", player:getNutrition():getWeight())
end)

-- Each tick: measure actual game calorie delta, apply multiplier to it
UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", function(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local weight = UTCore.getModData(player, "idealweightCache", 80.0)
    local mult
    if weight >= OVERWEIGHT_THRESHOLD then
        mult = 2.0
    elseif weight <= UNDERWEIGHT_THRESHOLD then
        mult = 0.5
    else
        UTCore.setModData(player, "idealweightPrevCal", nil)
        return
    end

    local nutrition = player:getNutrition()
    local current   = nutrition:getCalories()
    local prev      = UTCore.getModData(player, "idealweightPrevCal", nil)
    UTCore.setModData(player, "idealweightPrevCal", current)

    if prev == nil then return end

    local delta = prev - current  -- positive = calories were burned this tick
    if delta <= 0 then return end  -- gaining calories (eating) — don't amplify

    -- Apply (mult - 1) * actual burn as extra drain (or reduction for mult < 1)
    nutrition:setCalories(current - delta * (mult - 1.0))
end)
