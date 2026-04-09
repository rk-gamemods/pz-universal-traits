-- UT_gordanite.lua
-- Food you cook is 50% more nutritious (hunger change and calories boosted x1.5).
--
-- Every 60 ticks the player's main inventory is scanned for cooked food items
-- that have not yet been boosted (modData flag UT_gordBoosted).  The boost is
-- applied once per item so it is never compounded across inventory checks.

local TRAIT_ID = "UniversalTraits:UT_gordanite"
local tickCounter = 0

local function boostCookedFood(inv)
    if not inv then return end
    local items = inv:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:isFood() then
            pcall(function()
                if item:isCooked() and not item:getModData()["UT_gordBoosted"] then
                    item:getModData()["UT_gordBoosted"] = true
                    item:getModData()["UT_gordHungerMult"] = 1.5
                    local cal = item:getCalories()
                    if cal and cal > 0 then
                        item:setCalories(cal * 1.5)
                    end
                end
            end)
        end
    end
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 60 ~= 0 then return end
    boostCookedFood(player:getInventory())
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
