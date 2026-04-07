-- UT_onehanded_axes.lua
-- Runtime bonus: +5% crit chance with one-handed Axe weapons.
--
-- Crit chance is applied directly to weapon item stats:
--   weapon:setCriticalChance(math.min(100, base + 5))
-- Base value is cached in weapon modData (UT_oh_axesBaseCrit) on first
-- encounter so the bonus is not compounded across load/saves or weapon swaps.

local TRAIT_ID = "UniversalTraits:UT_onehanded_axes"
local CRIT_BONUS = 5

local tickCounter = 0

local function applyCritBonus(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    pcall(function()
        local isAxe       = weapon:getCategories():contains("Axe")
        local isOneHanded = not weapon:isTwoHandWeapon()
        if not (isAxe and isOneHanded) then return end

        local wmd = weapon:getModData()

        if wmd["UT_oh_axesBaseCrit"] == nil then
            wmd["UT_oh_axesBaseCrit"] = weapon:getCriticalChance()
        end

        local target = math.min(100, wmd["UT_oh_axesBaseCrit"] + CRIT_BONUS)

        if weapon:getCriticalChance() ~= target then
            weapon:setCriticalChance(target)
        end
    end)
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    applyCritBonus(primary)
    applyCritBonus(secondary)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
