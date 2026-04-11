-- UT_ascetic.lua
-- Ascetic: penalizes mood when eating within 1 in-game hour of the last meal.
-- Also provides a passive benefit: hunger accumulates 15% more slowly (you need
-- less food overall), making the trait worthwhile even without the mood trigger.
-- Detected via rising edge on healthFromFoodTimer (same pattern as sensitivestomach).

local TRAIT_ID = "UniversalTraits:UT_ascetic"

-- HUNGER RATE REDUCTION: Applied every in-game minute while trait is active.
-- Reduces hunger by HUNGER_REDUCTION_PER_MIN each minute, countering normal accumulation.
-- 0.0015 × 480 in-game minutes (8 hours) = 0.72 hunger offset across a full day.
-- PZ hunger scale is 0.0–1.0 (0 = full); this represents ~15% reduction in net hunger gain.
local HUNGER_REDUCTION_PER_MIN = 0.0015

-- Meal window: eating within one in-game hour of the previous meal triggers a penalty.
-- Replaced narrow "5 minutes" window (which almost never triggered) with a meaningful
-- hourly gap — ensures the trait performs its role as an infrequent-meal lifestyle.
local MEAL_GAP_HOURS = 1.0

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local healTimer = player:getBodyDamage():getHealthFromFoodTimer()
    local prev = md["UT_ascetic_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        local lastAteHours = md["UT_ascetic_lastAte"]
        local currentHours = getGameTime():getWorldAgeHours()

        if lastAteHours and (currentHours - lastAteHours) < MEAL_GAP_HOURS then
            -- Ate within 1 in-game hour of last meal — penalize unhappiness and stress
            pcall(function()
                local stats = player:getStats()
                stats:add(CharacterStat.UNHAPPINESS, 10)
                stats:add(CharacterStat.STRESS, 5)
            end)
        end

        md["UT_ascetic_lastAte"] = currentHours
    end

    md["UT_ascetic_prevTimer"] = healTimer
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

-- Passive benefit: reduce hunger accumulation rate
local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    if not stats then return end

    local hunger = stats:get(CharacterStat.HUNGER)
    if hunger > 0 then
        stats:set(CharacterStat.HUNGER, math.max(0, hunger - HUNGER_REDUCTION_PER_MIN))
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
