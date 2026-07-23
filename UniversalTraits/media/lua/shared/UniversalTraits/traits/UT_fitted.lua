-- UT_fitted.lua
-- Fitted trait: each worn clothing item weighs 50% of its captured base weight.
-- Run and combat speed penalties below 1.0 are neutralized while preserving
-- neutral or beneficial modifiers. Fires every 30 OnPlayerUpdate ticks.

local TRAIT_ID = "UniversalTraits:UT_fitted"
local trackedItems = {}
local trackedCount = 0

local fields = {
    {
        base = "UT_fitted_baseWeight",
        last = "UT_fitted_lastWeight",
        owned = "UT_fitted_ownsWeight",
        get = function(item) return item:getActualWeight() end,
        set = function(item, value) item:setActualWeight(value) end,
        fitted = function(base) return base * 0.5 end,
    },
    {
        base = "UT_fitted_baseRunMod",
        last = "UT_fitted_lastRunMod",
        owned = "UT_fitted_ownsRunMod",
        get = function(item) return item:getRunSpeedModifier() end,
        set = function(item, value) item:setRunSpeedModifier(value) end,
        fitted = function(base) if base < 1.0 then return 1.0 end return base end,
    },
    {
        base = "UT_fitted_baseCombatMod",
        last = "UT_fitted_lastCombatMod",
        owned = "UT_fitted_ownsCombatMod",
        get = function(item) return item:getCombatSpeedModifier() end,
        set = function(item, value) item:setCombatSpeedModifier(value) end,
        fitted = function(base) if base < 1.0 then return 1.0 end return base end,
    },
}

local function clearOwnership(md)
    md.UT_fitted_owner = nil
    md.UT_fitted_state = nil
    md.UT_fitted_origWeight = nil
    md.UT_fitted_origRunMod = nil
    md.UT_fitted_origCombatMod = nil
    for i = 1, #fields do
        local field = fields[i]
        md[field.base] = nil
        md[field.last] = nil
        md[field.owned] = nil
    end
end

local function restoreItem(item)
    local md = item:getModData()
    if md.UT_fitted_owner == true then
        for i = 1, #fields do
            local field = fields[i]
            if md[field.owned] == true then
                local current = field.get(item)
                local last = md[field.last]
                local base = md[field.base]
                if current == last and base ~= nil and current ~= base then
                    field.set(item, base)
                end
            end
        end
    end
    clearOwnership(md)
end

local function restoreAll()
    for i = trackedCount, 1, -1 do
        restoreItem(trackedItems[i])
        trackedItems[i] = nil
    end
    trackedCount = 0
end

local function findTracked(item)
    for i = 1, trackedCount do
        if trackedItems[i] == item then return i end
    end
    return nil
end

local function captureFresh(item, md)
    clearOwnership(md)
    md.UT_fitted_owner = true
    for i = 1, #fields do
        local field = fields[i]
        local base = field.get(item)
        local fitted = field.fitted(base)
        md[field.base] = base
        md[field.last] = fitted
        md[field.owned] = true
        if fitted ~= base then field.set(item, fitted) end
    end
end

local function reconcileItem(item)
    local md = item:getModData()
    if md.UT_fitted_owner ~= true then
        captureFresh(item, md)
        return
    end

    local recognized = false
    for i = 1, #fields do
        if md[fields[i].owned] ~= nil then recognized = true break end
    end
    if not recognized then
        captureFresh(item, md)
        return
    end

    for i = 1, #fields do
        local field = fields[i]
        if md[field.owned] == true then
            local current = field.get(item)
            local base = md[field.base]
            local last = md[field.last]
            if current == base and current ~= last then
                field.set(item, last)
            elseif current ~= last then
                -- Another system changed the field after Fitted wrote it.
                -- Its numerical composition is unknown, so preserve it.
                md[field.owned] = false
            end
        end
    end
end

local function onTick(player, _tick)
    local wornItems = player:getWornItems()

    for i = trackedCount, 1, -1 do
        local item = trackedItems[i]
        if wornItems == nil or wornItems:contains(item) == false then
            restoreItem(item)
            table.remove(trackedItems, i)
            trackedCount = trackedCount - 1
        end
    end

    if wornItems == nil then return end
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i)
        if item ~= nil and item:IsClothing() then
            if findTracked(item) == nil then
                trackedCount = trackedCount + 1
                trackedItems[trackedCount] = item
            end
            reconcileItem(item)
        end
    end
end

if UTCore.unregisterTickHandler then
    UTCore.unregisterTickHandler(TRAIT_ID, "reload")
end
UTCore.registerTickHandler(TRAIT_ID, onTick, {
    throttle = 30,
    heavy = true,
    teardown = restoreAll,
})
