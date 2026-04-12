-- UT_prospear.lua
-- Runtime bonus: +10% crit chance with Spear weapons.
--
-- Crit chance is applied directly to weapon item stats:
--   weapon:setCriticalChance(math.min(100, base + 10))
-- Base value is cached in weapon modData (UT_prospearBaseCrit) on first
-- encounter so the bonus is not compounded across load/saves or weapon swaps.

local TRAIT_ID = "UniversalTraits:UT_prospear"
local CRIT_BONUS = 10

local tickCounter = 0

local function applyCritBonus(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    pcall(function()
        local isSpear = UTCore.weaponHasCategory(weapon, WeaponCategory.SPEAR)
        if not isSpear then return end

        local wmd = weapon:getModData()

        if wmd["UT_prospearBaseCrit"] == nil then
            wmd["UT_prospearBaseCrit"] = weapon:getCriticalChance()
        end

        local target = math.min(100, wmd["UT_prospearBaseCrit"] + CRIT_BONUS)

        if weapon:getCriticalChance() ~= target then
            weapon:setCriticalChance(target)
        end
    end)
end

local function onTick(player, tick)
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    applyCritBonus(tick.primaryWeapon)
    applyCritBonus(tick.secondaryWeapon)
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
