-- UT_wildsman.lua
-- Wildsman: +30% foraging yield multiplier (via modData flag) and fish that
-- weigh 50% more and provide 50% more nutrition.

local TRAIT_ID = "UniversalTraits:UT_wildsman"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_wildsmanForageBoost"] = 1.3
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

        local multiplier = 1.5
        item:setCalories(item:getCalories() * multiplier)
        item:setLipids(item:getLipids() * multiplier)
        item:setCarbohydrates(item:getCarbohydrates() * multiplier)
        item:setProteins(item:getProteins() * multiplier)

        local baseHunger = item:getBaseHunger() * multiplier
        item:setBaseHunger(baseHunger)
        item:setHungChange(baseHunger)
        item:setActualWeight(item:getActualWeight() * multiplier)
        item:setWorldScale(item:getWorldScale() * multiplier)

        modData.fishing_FishSize = modData.fishing_FishSize * multiplier
        self.fishSize = self.fishSize * multiplier
        self.fishSizeLen = self.fishSizeLen * multiplier
        modData.UT_wildsmanFishScaled = true
        return item
    end
end

Events.OnNewGame.Add(onNewGame)
installFishingHook()
Events.OnGameStart.Add(installFishingHook)
