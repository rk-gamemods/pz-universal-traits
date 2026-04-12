-- UT_long_blades.lua
-- Runtime bonus: +10% crit chance with Long Blade weapons (all long blades).
--
-- Crit chance is applied directly to weapon item stats:
--   weapon:setCriticalChance(math.min(100, base + 10))
-- Base value is cached in weapon modData (UT_lb_bladesBaseCrit) on first
-- encounter so the bonus is not compounded across load/saves or weapon swaps.

local TRAIT_ID = "UniversalTraits:UT_long_blades"
local CRIT_BONUS = 10

local tickCounter = 0

local function applyCritBonus(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    pcall(function()
        local isLongBlade = weapon:getSubCategory() == "Long Blade"
        if not isLongBlade then return end

        local wmd = weapon:getModData()

        if wmd["UT_lb_bladesBaseCrit"] == nil then
            wmd["UT_lb_bladesBaseCrit"] = weapon:getCriticalChance()
        end

        local target = math.min(100, wmd["UT_lb_bladesBaseCrit"] + CRIT_BONUS)

        if weapon:getCriticalChance() ~= target then
            weapon:setCriticalChance(target)
        end
    end)
end

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    applyCritBonus(primary)
    applyCritBonus(secondary)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
