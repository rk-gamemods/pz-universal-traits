-- UT_scrounger.lua
-- Scrounger: when opening a container for the first time, 30% chance to
-- find one additional random item duplicated from the container's existing loot.
-- One roll per container, tracked permanently via modData.

local TRAIT_ID = "UniversalTraits:UT_scrounger"

local function onContainerUpdate(inventoryPage, state, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    for j = 0, inventoryPage.backpacks:size() - 1 do
        local bp = inventoryPage.backpacks:get(j)
        if bp and bp.inventory then
            local inv = bp.inventory
            local containerObj = inv.getParent and inv:getParent()
            if containerObj and instanceof(containerObj, "IsoObject")
               and not instanceof(containerObj, "IsoDeadBody") then
                local md = containerObj:getModData()
                if not md.UT_scroungerRolled then
                    md.UT_scroungerRolled = true
                    containerObj:transmitModData()

                    local items = inv:getItems()
                    if items and items:size() > 0 then
                        if ZombRand(100) < 30 then
                            local idx = ZombRand(items:size())
                            local sourceItem = items:get(idx)
                            if sourceItem then
                                local newItem = inv:AddItem(sourceItem:getFullType())
                                if newItem then
                                    inv:addItemOnServer(newItem)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(onContainerUpdate)
