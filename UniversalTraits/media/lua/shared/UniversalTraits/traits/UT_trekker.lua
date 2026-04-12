-- UT_trekker.lua
-- Walking refunds endurance loss and normalizes calorie burn back to the idle rate.

local TRAIT_ID = "UniversalTraits:UT_trekker"
local WALK_CALORIE_RATE = 0.13 * 0.6
local IDLE_CALORIE_RATE = 0.016
local WALK_CALORIE_REFUND_RATIO = (WALK_CALORIE_RATE - IDLE_CALORIE_RATE) / WALK_CALORIE_RATE

local function onTick(player, tick)
    local md = tick.modData
    local stats = tick.stats
    if not stats then return end
    local nutrition = player:getNutrition()

    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    local currentCalories = nutrition and nutrition:getCalories() or nil
    local isWalking = tick.isMoving and not tick.isSprinting and not tick.isRunning

    if isWalking then
        local lastEndurance = md["UT_trekker_lastEndurance"]
        if type(lastEndurance) == "number" and currentEndurance < lastEndurance then
            stats:set(CharacterStat.ENDURANCE, lastEndurance)
            currentEndurance = stats:get(CharacterStat.ENDURANCE)
        end

        local previousCalories = md["UT_trekker_prevCalories"]
        if nutrition and type(previousCalories) == "number" then
            local calorieBurn = previousCalories - currentCalories
            if calorieBurn > 0 then
                nutrition:setCalories(currentCalories + calorieBurn * WALK_CALORIE_REFUND_RATIO)
                currentCalories = nutrition:getCalories()
            end
        end
    end

    md["UT_trekker_lastEndurance"] = currentEndurance
    if nutrition then
        md["UT_trekker_prevCalories"] = currentCalories
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
