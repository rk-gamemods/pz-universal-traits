-- UT_ItemConsumptionHooks.lua
-- Shared overrides for ISEatFoodAction.perform and ISDrinkFluidAction.perform.
-- Handles eight traits that need to know what the player just consumed:
--   UT_allergic:            food sickness spike on eating any food (not medication)
--   UT_addictedtocaffeine:  sets UT_hadCaffeine flag when caffeinated item consumed
--   UT_anorexy:             adds 0.10 stress after food is actually consumed
--   UT_competitiveeater:    removes 10 boredom and 0.05 hunger after food is consumed
--   UT_badteeth:            adds head pain proportional to the food-healing timer increase
--   UT_gourmand:            adds 50% of the hunger/boredom/unhappiness benefit actually consumed
--   UT_antivaxxer:          stress spike when non-beta-blocker medication consumed
--   UT_pillsallergy:        food sickness +15 when any medication is consumed
--   UT_wildplantsallergy:   food sickness +20 when any foraged item is consumed
--
-- Both overrides follow the same safe decorator pattern used by SomewhatTraits and MoreTraits:
--   store original → replace with wrapper → call original first → apply UT effects.

-- Item type strings that count as caffeine sources (case-insensitive substring match)
local CAFFEINE_KEYWORDS = { "Coffee", "EnergyDrink", "Espresso", "Cola", "ChocolateCoffeeBeans" }
local ANOREXY_ID = "UniversalTraits:UT_anorexy"
local COMPETITIVE_EATER_ID = "UniversalTraits:UT_competitiveeater"
local BAD_TEETH_ID = "UniversalTraits:UT_badteeth"
local GOURMAND_ID = "UniversalTraits:UT_gourmand"
local GORDANITE_ID = "UniversalTraits:UT_gordanite"

-- Exact InventoryItem:getType() identities for current vanilla medications.
local MEDICATION_TYPES = {
    Pills = true,
    PillsAntiDep = true,
    PillsBeta = true,
    PillsSleepingTablets = true,
    PillsVitamins = true,
}

local function containsAny(str, keywords)
    if not str then return false end
    for _, kw in ipairs(keywords) do
        if string.find(str, kw, 1, true) then return true end
    end
    return false
end

local function isCaffeineItem(item)
    if not item then return false end
    local t = tostring(item:getType())
    return containsAny(t, CAFFEINE_KEYWORDS)
end

local function isMedicationItem(item)
    if not item then return false end
    local t = tostring(item:getType())
    return MEDICATION_TYPES[t] == true
end

local function isAntivaxxerMedicationItem(item)
    if not isMedicationItem(item) then return false end
    return tostring(item:getType()) ~= "PillsBeta"
end

-- Checks whether an item is actual food (not a medication that happens to be eaten)
local function isFoodItem(item)
    if not item then return false end
    return not isMedicationItem(item)
end

-- Checks whether an item is a foraged wild plant (has forage categories in B42)
local function isWildPlantItem(item)
    if not item then return false end
    local ok, cats = pcall(function() return item:getScriptItem():getForageFocusCategories() end)
    return ok and cats ~= nil and not cats:isEmpty()
end

local function getFoodBonusMultipliers(item)
    if not item or type(item.getModData) ~= "function" then return 1.0, 1.0 end

    local md = item:getModData()
    local multiplier = 1.0
    if type(md["UT_wildsmanFishHungerMult"]) == "number" and md["UT_wildsmanFishHungerMult"] > multiplier then
        multiplier = md["UT_wildsmanFishHungerMult"]
    end

    return multiplier, multiplier
end

local function applyFoodBonusEffects(character, item, percentage)
    local multiplier, calorieMultiplier = getFoodBonusMultipliers(item)
    if multiplier <= 1.0 then return end

    local consumedFraction = percentage or 1.0
    if consumedFraction <= 0 then return end

    pcall(function()
        local stats = character:getStats()
        local hungerChange = item:getHungerChange()
        if hungerChange and hungerChange < 0 then
            local bonus = hungerChange * consumedFraction * (multiplier - 1.0)
            stats:set(CharacterStat.HUNGER, math.max(0, stats:get(CharacterStat.HUNGER) + bonus))
        end

        local calories = item.getCalories and item:getCalories() or nil
        if calories and calories > 0 and calorieMultiplier > 1.0 then
            local nutrition = character.getNutrition and character:getNutrition() or nil
            if nutrition and nutrition.setCalories and nutrition.getCalories then
                nutrition:setCalories(nutrition:getCalories() + (calories * consumedFraction * (calorieMultiplier - 1.0)))
            end
        end
    end)
end

-- ─── ISEatFoodAction override ──────────────────────────────────────────────────
-- Fires when the player finishes eating any consumable item.

local function applyEatEffects(character, item, percentage)
    if not character or not item then return end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("inventory.item-runtime", tostring(item.getType and item:getType() or "<unknown>"))
        UTSmoke.record("timed-action.runtime", "ISEatFoodAction")
    end

    applyFoodBonusEffects(character, item, percentage)

    -- UT_addictedtocaffeine: mark caffeine consumed
    if isCaffeineItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_addictedtocaffeine") then
        character:getModData()["UT_hadCaffeine"] = true
    end

    -- UT_antivaxxer: stress spike when taking medication
    if isAntivaxxerMedicationItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_antivaxxer") then
        pcall(function()
            local stats = character:getStats()
            stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.20))
        end)
    end

    -- UT_allergic: food sickness spike when eating real food
    if isFoodItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_allergic") then
        if ZombRand(100) < 30 then
            pcall(function()
                local stats = character:getStats()
                local current = stats:get(CharacterStat.FOOD_SICKNESS)
                -- Spike adds 20 sickness units (scale is 0–100).
                -- A 20-point spike causes nausea/vomiting if it exceeds the player's
                -- current tolerance. Treatable by resting and staying hydrated;
                -- the sickness drains naturally over ~30 min of game time.
                stats:set(CharacterStat.FOOD_SICKNESS, math.min(100, current + 20))
            end)
        end
    end

    -- UT_pillsallergy: food sickness +15 when any medication is consumed
    if isMedicationItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_pillsallergy") then
        pcall(function()
            local stats = character:getStats()
            stats:set(CharacterStat.FOOD_SICKNESS, math.min(100, stats:get(CharacterStat.FOOD_SICKNESS) + 15))
        end)
    end

    -- UT_wildplantsallergy: food sickness +20 when any foraged item is consumed
    if isWildPlantItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_wildplantsallergy") then
        pcall(function()
            local stats = character:getStats()
            stats:set(CharacterStat.FOOD_SICKNESS, math.min(100, stats:get(CharacterStat.FOOD_SICKNESS) + 20))
        end)
    end
end

-- Override ISEatFoodAction.perform (shared Lua, safe for both SP and MP)
local function hookISEatFoodAction()
    if not _G["ISEatFoodAction"] then return end
    if ISEatFoodAction.__UTItemConsumptionPerformWrapper then return end
    local original = ISEatFoodAction.perform
    local function wrapper(self)
        local percentage = self.percentage or 1.0
        original(self)
        pcall(applyEatEffects, self.character, self.item, percentage)
    end
    ISEatFoodAction.perform = wrapper
    ISEatFoodAction.__UTItemConsumptionPerformWrapper = wrapper
end

-- Post-consumption effects must run after character:Eat so the food's own stat
-- changes are applied first. A completed action uses complete(); an interrupted
-- partial action uses eat(). SVN 964 keeps those paths separate, so wrapping both
-- does not double-apply these traits.
local function readFoodHealingState(character)
    if not character then return nil, nil end

    local bodyDamage = character:getBodyDamage()
    if not bodyDamage then return nil, nil end

    local timer = bodyDamage:getHealthFromFoodTimer()
    if type(timer) ~= "number" then return bodyDamage, nil end
    return bodyDamage, timer
end

local function tryReadFoodHealingState(character)
    local ok, bodyDamage, timer = pcall(readFoodHealingState, character)
    if not ok then return nil, nil end
    return bodyDamage, timer
end

local function readMealBenefitState(character)
    if not character then return nil end
    local stats = character:getStats()
    local nutrition = character.getNutrition and character:getNutrition() or nil
    return {
        hunger = stats:get(CharacterStat.HUNGER),
        boredom = stats:get(CharacterStat.BOREDOM),
        unhappiness = stats:get(CharacterStat.UNHAPPINESS),
        calories = nutrition and nutrition.getCalories and nutrition:getCalories() or nil,
    }
end

local function tryReadMealBenefitState(character)
    local ok, state = pcall(readMealBenefitState, character)
    if not ok then return nil end
    return state
end

local function applyGourmandBonus(character, item, previousState, nativeAfter)
    if not previousState or not nativeAfter or not isFoodItem(item) then return end
    if not item.getCategory or item:getCategory() ~= "Food" then return end
    if not UTCore.hasTrait(character, GOURMAND_ID) then return end

    local stats = character:getStats()
    local function addHalfOfBenefit(stat, before, after)
        if type(before) == "number" and type(after) == "number" and after < before then
            stats:set(stat, math.max(0.0, stats:get(stat) - ((before - after) * 0.5)))
        end
    end

    addHalfOfBenefit(CharacterStat.HUNGER, previousState.hunger, nativeAfter.hunger)
    addHalfOfBenefit(CharacterStat.BOREDOM, previousState.boredom, nativeAfter.boredom)
    addHalfOfBenefit(CharacterStat.UNHAPPINESS, previousState.unhappiness, nativeAfter.unhappiness)
end

local function applyGordaniteBonus(character, item, before, nativeAfter)
    if not before or not nativeAfter or not character or not item then return end
    if not UTCore.hasTrait(character, GORDANITE_ID) or type(item.getChef) ~= "function" then return end
    local chef = item:getChef()
    if type(chef) ~= "string" or chef == "" then return end
    local function tryReadIdentity(getter)
        local ok, value = pcall(getter)
        if not ok or type(value) ~= "string" or value == "" then return nil end
        return value
    end
    local username = character.getUsername
        and tryReadIdentity(function() return character:getUsername() end) or nil
    local fullName = character.getFullName
        and tryReadIdentity(function() return character:getFullName() end) or nil
    if chef ~= username and chef ~= fullName then return end
    local stats = character:getStats()
    if type(before.hunger) == "number" and type(nativeAfter.hunger) == "number"
        and before.hunger > nativeAfter.hunger then
        stats:set(CharacterStat.HUNGER,
            stats:get(CharacterStat.HUNGER) - ((before.hunger - nativeAfter.hunger) * 0.5))
    end
    if type(before.calories) == "number" and type(nativeAfter.calories) == "number"
        and nativeAfter.calories > before.calories then
        local nutrition = character:getNutrition()
        nutrition:setCalories(nutrition:getCalories() + ((nativeAfter.calories - before.calories) * 0.5))
    end
end

local function applyPostConsumptionEffects(character, item, consumedFraction, previousFoodTimer, previousMealState,
    nativeAfterMealState)
    if not character or not consumedFraction or consumedFraction <= 0 then return end

    applyGourmandBonus(character, item, previousMealState, nativeAfterMealState)
    pcall(applyGordaniteBonus, character, item, previousMealState, nativeAfterMealState)

    local stats = character:getStats()
    if UTCore.hasTrait(character, ANOREXY_ID) then
        local stress = stats:get(CharacterStat.STRESS)
        stats:set(CharacterStat.STRESS, math.min(1.0, stress + 0.10))
    end

    if UTCore.hasTrait(character, COMPETITIVE_EATER_ID) then
        local boredom = stats:get(CharacterStat.BOREDOM)
        local hunger = stats:get(CharacterStat.HUNGER)
        stats:set(CharacterStat.BOREDOM, math.max(0.0, boredom - 10.0))
        stats:set(CharacterStat.HUNGER, math.max(0.0, hunger - 0.05))
    end

    if UTCore.hasTrait(character, BAD_TEETH_ID) and type(previousFoodTimer) == "number" then
        local bodyDamage, currentFoodTimer = readFoodHealingState(character)
        if currentFoodTimer and currentFoodTimer > 1000 and currentFoodTimer > previousFoodTimer then
            local head = bodyDamage:getBodyPart(BodyPartType.Head)
            if head then
                local pain = head:getAdditionalPain()
                local increase = (currentFoodTimer - previousFoodTimer) * 0.01
                head:setAdditionalPain(math.min(100.0, pain + increase))
            end
        end
    end
end

local function hookISEatFoodActionPostConsumption()
    if not _G["ISEatFoodAction"] then return end

    if not ISEatFoodAction.__UTAnorexyCompleteWrapper then
        local originalComplete = ISEatFoodAction.complete
        if type(originalComplete) == "function" then
            local function completeWrapper(self)
                local _, previousFoodTimer = tryReadFoodHealingState(self.character)
                local previousMealState = tryReadMealBenefitState(self.character)
                local result = originalComplete(self)
                local nativeAfterMealState = tryReadMealBenefitState(self.character)
                pcall(applyPostConsumptionEffects, self.character, self.item, self.percentage or 1.0,
                    previousFoodTimer, previousMealState, nativeAfterMealState)
                return result
            end
            ISEatFoodAction.complete = completeWrapper
            ISEatFoodAction.__UTAnorexyCompleteWrapper = completeWrapper
        end
    end

    if not ISEatFoodAction.__UTAnorexyPartialWrapper then
        local originalEat = ISEatFoodAction.eat
        if type(originalEat) == "function" then
            local function partialWrapper(self, food, percentage)
                local _, previousFoodTimer = tryReadFoodHealingState(self.character)
                local previousMealState = tryReadMealBenefitState(self.character)
                local result = originalEat(self, food, percentage)
                local nativeAfterMealState = tryReadMealBenefitState(self.character)
                local consumedFraction = (self.percentage or 1.0) * (percentage or 0)
                pcall(applyPostConsumptionEffects, self.character, self.item, consumedFraction,
                    previousFoodTimer, previousMealState, nativeAfterMealState)
                return result
            end
            ISEatFoodAction.eat = partialWrapper
            ISEatFoodAction.__UTAnorexyPartialWrapper = partialWrapper
        end
    end
end

-- ─── ISDrinkFluidAction override ──────────────────────────────────────────────
-- Fires when the player finishes drinking a fluid (coffee, etc. is a fluid in PZ).

local function applyDrinkEffects(character, item)
    if not character or not item then return end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("inventory.item-runtime", tostring(item.getType and item:getType() or "<unknown>"))
        UTSmoke.record("timed-action.runtime", "ISDrinkFluidAction")
    end

    -- UT_addictedtocaffeine: mark caffeine consumed from drinks (coffee is a liquid in B42)
    if isCaffeineItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_addictedtocaffeine") then
        character:getModData()["UT_hadCaffeine"] = true
    end
end

local function hookISDrinkFluidAction()
    if not _G["ISDrinkFluidAction"] then return end
    if ISDrinkFluidAction.__UTItemConsumptionPerformWrapper then return end
    local original = ISDrinkFluidAction.perform
    local function wrapper(self)
        original(self)
        -- ISDrinkFluidAction stores the fluid container as self.item
        pcall(applyDrinkEffects, self.character, self.item)
    end
    ISDrinkFluidAction.perform = wrapper
    ISDrinkFluidAction.__UTItemConsumptionPerformWrapper = wrapper
end

-- Apply both hooks at startup.
-- Use a deferred event so ISEatFoodAction / ISDrinkFluidAction are guaranteed loaded.
local function installHooks()
    hookISEatFoodAction()
    hookISEatFoodActionPostConsumption()
    hookISDrinkFluidAction()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installHooks)
else
    -- Fallback: install immediately if event table not set up yet
    installHooks()
end
