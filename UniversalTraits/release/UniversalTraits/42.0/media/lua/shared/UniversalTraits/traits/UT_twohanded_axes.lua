-- UT_twohanded_axes.lua
-- Runtime bonus: +10% crit chance with two-handed Axe weapons.
--
-- Crit chance is applied directly to weapon item stats:
--   weapon:setCriticalChance(math.min(100, base + 10))
-- Base value is cached in weapon modData (UT_th_axesBaseCrit) on first
-- encounter so the bonus is not compounded across load/saves or weapon swaps.

local TRAIT_ID = "UniversalTraits:UT_twohanded_axes"
local CRIT_BONUS = 10

local function applyCritBonus(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    pcall(function()
        local isAxe      = UTCore.weaponHasCategory(weapon, WeaponCategory.AXE)
        local isTwoHand  = weapon:isTwoHandWeapon()
        if not (isAxe and isTwoHand) then return end

        local wmd = weapon:getModData()

        if wmd["UT_th_axesBaseCrit"] == nil then
            wmd["UT_th_axesBaseCrit"] = weapon:getCriticalChance()
        end

        local target = math.min(100, wmd["UT_th_axesBaseCrit"] + CRIT_BONUS)

        if weapon:getCriticalChance() ~= target then
            weapon:setCriticalChance(target)
        end
    end)
end

local function onTick(player, tick)
    applyCritBonus(tick.primaryWeapon)
    applyCritBonus(tick.secondaryWeapon)
end

UTCore.registerTickHandler(TRAIT_ID, onTick, { throttle = 30 })
