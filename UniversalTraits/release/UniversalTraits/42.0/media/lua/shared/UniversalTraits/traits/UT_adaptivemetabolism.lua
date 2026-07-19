-- UT_adaptivemetabolism.lua
-- Body draws on stored calories before signaling hunger. While calories > 0,
-- passive drain cannot push hunger past 0.01 (UI shows ~99% full). PZ's internal
-- HUNGER is inverted from the UI: 0.0 = full, 1.0 = starving. So the floor on
-- the UI corresponds to a ceiling on the stat. Eating still freely drives hunger
-- to 0. Once calories hit zero, vanilla starvation applies unmodified.

local TRAIT_ID = "UniversalTraits:UT_adaptivemetabolism"
local HUNGER_CEILING = 0.01

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:getNutrition():getCalories() <= 0 then return end
    local stats = player:getStats()
    local hunger = stats:get(CharacterStat.HUNGER)
    if hunger > HUNGER_CEILING then
        stats:set(CharacterStat.HUNGER, HUNGER_CEILING)
    end
end

Events.EveryTenMinutes.Add(handler)
