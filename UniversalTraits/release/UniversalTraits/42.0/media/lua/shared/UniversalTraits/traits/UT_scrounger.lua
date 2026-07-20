-- UT_scrounger.lua
-- Scrounger: when opening a container for the first time, 30% chance to
-- find one additional random item duplicated from the container's existing loot.
-- One roll per container, tracked permanently via modData.

local TRAIT_ID = "UniversalTraits:UT_scrounger"

local function onContainerUpdate(inventoryPage, state)
    if state ~= "end" then return end

    local player = inventoryPage and getSpecificPlayer(inventoryPage.player)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    for _, bp in ipairs(inventoryPage.backpacks or {}) do
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
                                    sendAddItemToContainer(inv, newItem)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

UTScroungerRuntime = UTScroungerRuntime or {}
if not UTScroungerRuntime.registered then
    Events.OnRefreshInventoryWindowContainers.Add(onContainerUpdate)
    UTScroungerRuntime.registered = true
end
