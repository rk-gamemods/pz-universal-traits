-- UT_fitted.lua
-- Fitted trait: per-worn-item 50% weight reduction and removal of run/combat speed penalties.
-- Fires every 30 OnPlayerUpdate ticks.
-- Restores original values when an item is unequipped.
-- ModData keys use UT_fitted_ prefix to avoid collisions with other mods.

local TRAIT_ID   = "UniversalTraits:UT_fitted"
local THROTTLE   = 30
local tickCounter = 0

local function clothingUpdate(player)
    if not player then return end
    if UTCore.shouldSkipTick(player) then return end

    tickCounter = tickCounter + 1
    if tickCounter % THROTTLE ~= 0 then return end

    local state      = UTCore.hasTrait(player, TRAIT_ID) and "Fitted" or "Normal"
    local wornItems  = player:getWornItems()
    local inventory  = player:getInventory()

    if wornItems == nil or wornItems:size() <= 1 then return end

    -- Pass 1: restore unequipped clothing that was previously modified.
    for i = 0, inventory:getItems():size() - 1 do
        local item = inventory:getItems():get(i)
        if item:IsClothing() then
            local md = item:getModData()
            if md.UT_fitted_state ~= nil
                and md.UT_fitted_state ~= "Normal"
                and wornItems:contains(item) == false
            then
                item:setRunSpeedModifier(md.UT_fitted_origRunMod)
                item:setCombatSpeedModifier(md.UT_fitted_origCombatMod)
                item:setActualWeight(md.UT_fitted_origWeight)
                md.UT_fitted_state = "Normal"
            end
        end
    end

    -- Pass 2: apply or revert Fitted effects on worn clothing.
    for i = wornItems:size() - 1, 0, -1 do
        local item = wornItems:getItemByIndex(i)
        if item:IsClothing() then
            local md = item:getModData()

            -- First time we see this item: record original values.
            if md.UT_fitted_state == nil then
                md.UT_fitted_state        = "Normal"
                md.UT_fitted_origRunMod   = item:getRunSpeedModifier()
                md.UT_fitted_origCombatMod = item:getCombatSpeedModifier()
                md.UT_fitted_origWeight   = item:getActualWeight()
            end

            -- Only act when state needs to change.
            if state ~= md.UT_fitted_state then
                if md.UT_fitted_origRunMod ~= nil and md.UT_fitted_origRunMod < 1 then
                    if state == "Fitted" then
                        item:setRunSpeedModifier(1.0)
                    else
                        item:setRunSpeedModifier(md.UT_fitted_origRunMod)
                    end
                end

                if md.UT_fitted_origCombatMod ~= nil and md.UT_fitted_origCombatMod < 1 then
                    if state == "Fitted" then
                        item:setCombatSpeedModifier(1.0)
                    else
                        item:setCombatSpeedModifier(md.UT_fitted_origCombatMod)
                    end
                end

                if md.UT_fitted_origWeight ~= nil then
                    if state == "Fitted" then
                        item:setActualWeight(md.UT_fitted_origWeight * 0.5)
                    else
                        item:setActualWeight(md.UT_fitted_origWeight)
                    end
                end

                md.UT_fitted_state = state
                player:setWornItems(wornItems)
            end
        end
    end
end

Events.OnPlayerUpdate.Add(clothingUpdate)
