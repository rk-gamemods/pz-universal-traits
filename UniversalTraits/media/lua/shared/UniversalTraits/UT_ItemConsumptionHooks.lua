-- UT_ItemConsumptionHooks.lua
-- Shared overrides for ISEatFoodAction.perform and ISDrinkFluidAction.perform.
-- Handles five traits that need to know what the player just consumed:
--   UT_allergic:            food sickness spike on eating any food (not medication)
--   UT_addictedtocaffeine:  sets UT_hadCaffeine flag when caffeinated item consumed
--   UT_antivaxxer:          stress spike when non-beta-blocker medication consumed
--   UT_pillsallergy:        food sickness +15 when any medication is consumed
--   UT_wildplantsallergy:   food sickness +20 when any foraged item is consumed
--
-- Both overrides follow the same safe decorator pattern used by SomewhatTraits and MoreTraits:
--   store original → replace with wrapper → call original first → apply UT effects.

-- Item type strings that count as caffeine sources (case-insensitive substring match)
local CAFFEINE_KEYWORDS = { "Coffee", "EnergyDrink", "Espresso", "Cola", "ChocolateCoffeeBeans" }

-- Item type strings that count as medications (treated as pills/injectables)
-- Beta blockers are explicitly excluded per design intent.
local MEDICATION_KEYWORDS = {
    "Antibiotics", "Painkiller", "SleepingTablet", "Antidepressant",
    "NauseaReducer", "Multivitamin", "Vitamin", "Codeine", "Aspirin",
    "Antibiotic",
}
local EXCLUDED_MEDICATION_KEYWORDS = { "BetaBlocker" }

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
    if containsAny(t, EXCLUDED_MEDICATION_KEYWORDS) then return false end
    return containsAny(t, MEDICATION_KEYWORDS)
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

local function getFoodBonusMultiplier(item)
    if not item or type(item.getModData) ~= "function" then return 1.0 end

    local md = item:getModData()
    local multiplier = 1.0

    if type(md["UT_gordHungerMult"]) == "number" and md["UT_gordHungerMult"] > multiplier then
        multiplier = md["UT_gordHungerMult"]
    end

    if type(md["UT_wildsmanFishHungerMult"]) == "number" and md["UT_wildsmanFishHungerMult"] > multiplier then
        multiplier = md["UT_wildsmanFishHungerMult"]
    end

    return multiplier
end

local function applyFoodBonusEffects(character, item, percentage)
    local multiplier = getFoodBonusMultiplier(item)
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
        if calories and calories > 0 then
            local nutrition = character.getNutrition and character:getNutrition() or nil
            if nutrition and nutrition.setCalories and nutrition.getCalories then
                nutrition:setCalories(nutrition:getCalories() + (calories * consumedFraction * (multiplier - 1.0)))
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
    if isMedicationItem(item) and UTCore.hasTrait(character, "UniversalTraits:UT_antivaxxer") then
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
    local original = ISEatFoodAction.perform
    function ISEatFoodAction:perform()
        local percentage = self.percentage or 1.0
        original(self)
        pcall(applyEatEffects, self.character, self.item, percentage)
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
    local original = ISDrinkFluidAction.perform
    function ISDrinkFluidAction:perform()
        original(self)
        -- ISDrinkFluidAction stores the fluid container as self.item
        pcall(applyDrinkEffects, self.character, self.item)
    end
end

-- Apply both hooks at startup.
-- Use a deferred event so ISEatFoodAction / ISDrinkFluidAction are guaranteed loaded.
local function installHooks()
    hookISEatFoodAction()
    hookISDrinkFluidAction()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installHooks)
else
    -- Fallback: install immediately if event table not set up yet
    installHooks()
end
