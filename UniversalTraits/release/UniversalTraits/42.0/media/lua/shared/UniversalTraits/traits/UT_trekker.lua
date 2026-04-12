-- UT_trekker.lua
-- Walking refunds endurance loss and normalizes calorie burn back to the idle rate.

local TRAIT_ID = "UniversalTraits:UT_trekker"
local WALK_CALORIE_RATE = 0.13 * 0.6
local IDLE_CALORIE_RATE = 0.016
local WALK_CALORIE_REFUND_RATIO = (WALK_CALORIE_RATE - IDLE_CALORIE_RATE) / WALK_CALORIE_RATE

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local stats = player:getStats()
    if not stats then return end
    local nutrition = player:getNutrition()

    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    local currentCalories = nutrition and nutrition:getCalories() or nil
    local okMoving, moving = pcall(function() return player:isMoving() end)
    local isWalking = okMoving and moving and not player:isSprinting() and not player:isRunning()

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

Events.OnPlayerUpdate.Add(onPlayerUpdate)
