-- UT_gourmand.lua
-- Gourmand: boosts hunger value and improves boredom/unhappiness on food items in inventory.
-- Applies stat bonuses directly to food item objects (match MoreTraits FoodUpdate pattern).

local TRAIT_ID = "UniversalTraits:UT_gourmand"

local tickCounter = 0

local function applyGourmandToFood(food)
    local itemdata = food:getModData()

    -- Store original stats once
    if itemdata.UT_gourmand_state == nil then
        itemdata.UT_origHungChange     = food:getHungChange()
        itemdata.UT_origUnhappyChange  = food:getUnhappyChange()
        itemdata.UT_origBoredomChange  = food:getBoredomChange()
        itemdata.UT_gourmand_state     = "Normal"
    end

    if itemdata.UT_gourmand_state ~= "Gourmand" then
        -- 1.5x hunger relief
        food:setHungChange(itemdata.UT_origHungChange * 1.5)
        -- Improve happiness/boredom if they were already beneficial
        local newUnhappy = itemdata.UT_origUnhappyChange
        if newUnhappy < 0 then newUnhappy = newUnhappy * 1.5 end
        food:setUnhappyChange(newUnhappy)
        local newBored = itemdata.UT_origBoredomChange
        if newBored < 0 then newBored = newBored * 1.5 end
        food:setBoredomChange(newBored)
        itemdata.UT_gourmand_state = "Gourmand"
    end
end

local function revertGourmandFood(food)
    local itemdata = food:getModData()
    if itemdata.UT_gourmand_state == "Gourmand" then
        food:setHungChange(itemdata.UT_origHungChange)
        food:setUnhappyChange(itemdata.UT_origUnhappyChange)
        food:setBoredomChange(itemdata.UT_origBoredomChange)
        itemdata.UT_gourmand_state = "Normal"
    end
end

local function onPlayerUpdate(player)
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local hasGourmand = UTCore.hasTrait(player, TRAIT_ID)
    local inv = player:getInventory()
    local items = inv:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getCategory() == "Food" then
            if hasGourmand then
                pcall(applyGourmandToFood, item)
            else
                pcall(revertGourmandFood, item)
            end
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
