-- UT_trackman.lua
-- Traps never break — trap items in the player's inventory are kept at max condition.
--
-- Every 60 ticks the player's inventory is scanned for items whose type name
-- contains "trap" (case-insensitive).  Any such item below max condition is
-- restored to full condition inside a pcall so unexpected item types are skipped
-- silently.

local TRAIT_ID = "UniversalTraits:UT_trackman"
local tickCounter = 0

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 60 ~= 0 then return end

    local inv = player:getInventory()
    if not inv then return end
    local items = inv:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        pcall(function()
            if item and item:getType() and item:getType():lower():find("trap") then
                local maxCond = item:getConditionMax()
                if maxCond and maxCond > 0 and item:getCondition() < maxCond then
                    item:setCondition(maxCond)
                end
            end
        end)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
