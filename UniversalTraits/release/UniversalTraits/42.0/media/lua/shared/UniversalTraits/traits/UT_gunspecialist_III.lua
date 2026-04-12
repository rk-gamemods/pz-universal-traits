-- UT_gunspecialist_III.lua
-- Runtime bonuses: −10% reload time, −10% aiming time, jam immunity on equipped weapons.
--
-- Speed bonuses are applied directly to weapon item stats:
--   weapon:setReloadTime(floor(base * 0.9))   — 10% fewer ticks to reload
--   weapon:setAimingTime(floor(base * 0.9))   — 10% fewer ticks to aim
-- Base values are cached in weapon modData (UT_gs3BaseReload / UT_gs3BaseAim) on first
-- encounter so the multiplier is not compounded across load/saves or weapon swaps.
--
-- Jam immunity: unjams any equipped firearm every 30 ticks (same as before).

local TRAIT_ID = "UniversalTraits:UT_gunspecialist_III"
local SPEED_MULT = 0.9  -- 10% faster = 90% of base time

local tickCounter = 0

local function isFirearm(item)
    return item and instanceof(item, "HandWeapon") and item:isRanged()
end

local function applySpeedBonus(weapon)
    if not isFirearm(weapon) then return end

    local wmd = weapon:getModData()

    -- Cache base reload time on first application
    if wmd["UT_gs3BaseReload"] == nil then
        wmd["UT_gs3BaseReload"] = weapon:getReloadTime()
    end
    -- Cache base aiming time on first application
    if wmd["UT_gs3BaseAim"] == nil then
        wmd["UT_gs3BaseAim"] = weapon:getAimingTime()
    end

    local targetReload = math.floor(wmd["UT_gs3BaseReload"] * SPEED_MULT)
    local targetAim    = math.floor(wmd["UT_gs3BaseAim"]    * SPEED_MULT)

    -- Only write if the value drifted (avoids unnecessary Java calls every tick)
    if weapon:getReloadTime() ~= targetReload then
        weapon:setReloadTime(targetReload)
    end
    if weapon:getAimingTime() ~= targetAim then
        weapon:setAimingTime(targetAim)
    end
end

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    -- Mark for save-load recovery; speed bonus applied live in onPlayerUpdate
    player:getModData()["UT_gunspec3"] = true
end

local function onTick(player, tick)
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    -- Ensure moddata key present (e.g. loaded save)
    if not tick.modData["UT_gunspec3"] then
        tick.modData["UT_gunspec3"] = true
    end

    -- Apply reload/aim speed bonuses
    applySpeedBonus(tick.primaryWeapon)
    applySpeedBonus(tick.secondaryWeapon)

    -- Jam immunity: unjam any currently equipped firearm
    if isFirearm(tick.primaryWeapon)   and tick.primaryWeapon:isJammed()   then tick.primaryWeapon:setJammed(false)   end
    if isFirearm(tick.secondaryWeapon) and tick.secondaryWeapon:isJammed() then tick.secondaryWeapon:setJammed(false) end
end

Events.OnNewGame.Add(onNewGame)
UTCore.registerTickHandler(TRAIT_ID, onTick)
