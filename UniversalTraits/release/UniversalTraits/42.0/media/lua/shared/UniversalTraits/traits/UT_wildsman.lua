-- UT_wildsman.lua
-- Wildsman: +30% foraging yield multiplier (via modData flag) and fish that
-- weigh 50% more and provide 50% more nutrition.

local TRAIT_ID = "UniversalTraits:UT_wildsman"
local FORAGE_MULTIPLIER = 1.3
local FISH_MULTIPLIER = 1.5

local function installForagingHook()
    if not ISBaseIcon or type(ISBaseIcon.initItemCount) ~= "function" then return end
    if ISBaseIcon._UT_wildsmanInitItemCountOriginal then return end

    local originalInitItemCount = ISBaseIcon.initItemCount
    ISBaseIcon._UT_wildsmanInitItemCountOriginal = originalInitItemCount

    function ISBaseIcon:initItemCount()
        local result = originalInitItemCount(self)
        if not self.character or not UTCore.hasTrait(self.character, TRAIT_ID) then return result end
        if type(self.itemCount) ~= "number" or self.itemCount <= 0 then return result end

        local scaled = self.itemCount * FORAGE_MULTIPLIER
        local whole = math.floor(scaled)
        local bonusChance = math.floor(((scaled - whole) * 100) + 0.5)
        if bonusChance > 0 and ZombRand(100) < bonusChance then
            whole = whole + 1
        end
        self.itemCount = whole
        return result
    end
end

local function installFishingHook()
    local Fish = Fishing and Fishing.Fish
    if not Fish or type(Fish.createFish) ~= "function" then return end
    if Fish._UT_wildsmanCreateFishOriginal then return end

    local originalCreateFish = Fish.createFish
    Fish._UT_wildsmanCreateFishOriginal = originalCreateFish

    function Fish:createFish(fishConfig)
        local item = originalCreateFish(self, fishConfig)
        if not item or not self or not self.character then return item end
        if not UTCore.hasTrait(self.character, TRAIT_ID) then return item end

        local modData = item:getModData()
        if type(modData.fishing_FishSize) ~= "number" then return item end
        if modData.fishing_FishHandItem == nil then return item end
        if modData.UT_wildsmanFishScaled then return item end

        local multiplier = FISH_MULTIPLIER
        item:setCalories(item:getCalories() * multiplier)
        item:setLipids(item:getLipids() * multiplier)
        item:setCarbohydrates(item:getCarbohydrates() * multiplier)
        item:setProteins(item:getProteins() * multiplier)

        local baseHunger = item:getBaseHunger() * multiplier
        item:setBaseHunger(baseHunger)
        item:setHungChange(baseHunger)
        item:setActualWeight(item:getActualWeight() * multiplier)

        local scaledFishSize = modData.fishing_FishSize * multiplier
        item:setWorldScale(scaledFishSize / 100.0)
        modData.fishing_FishSize = scaledFishSize
        self.fishSize = self.fishSize * multiplier
        self.fishSizeLen = self.fishSizeLen * multiplier
        modData.UT_wildsmanFishScaled = true
        return item
    end
end

local function installHooks()
    installForagingHook()
    installFishingHook()
end

installHooks()
UTWildsmanRuntime = UTWildsmanRuntime or {}
if not UTWildsmanRuntime.registered then
    Events.OnGameStart.Add(installHooks)
    UTWildsmanRuntime.registered = true
end
