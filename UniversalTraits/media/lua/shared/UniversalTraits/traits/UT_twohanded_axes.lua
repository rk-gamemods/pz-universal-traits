-- UT_twohanded_axes.lua
-- Runtime bonus: +10 displayed critical-chance points with two-handed Axe weapons.
-- Recalculated every 30 player-update dispatches and restored whenever inactive.

local TRAIT_ID = "UniversalTraits:UT_twohanded_axes"
local CRIT_BONUS = 10
local LEGACY_BASE_KEY = "UT_th_axesBaseCrit"
local NUMERIC_EPSILON = 1e-9

UTCore._twoHandedAxesState = UTCore._twoHandedAxesState or { trackedWeapons = {} }
local state = UTCore._twoHandedAxesState

local function retireLegacyState(weapon)
    if not weapon or not weapon.getModData then return end
    pcall(function()
        local wmd = weapon:getModData()
        if wmd then wmd[LEGACY_BASE_KEY] = nil end
    end)
end

local function isEligible(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    retireLegacyState(weapon)
    local ok, eligible = pcall(function()
        return UTCore.weaponHasCategory(weapon, WeaponCategory.AXE)
            and weapon:isTwoHandWeapon()
    end)
    return ok and eligible == true
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function getRawCriticalChance(weapon)
    local ok, raw, sharpness = pcall(function()
        local displayed = weapon:getCriticalChance()
        if not isFiniteNumber(displayed) then return nil, nil end

        local hasSharpness = weapon:hasSharpness()
        if hasSharpness == false then return displayed, 1 end
        if hasSharpness ~= true then return nil, nil end

        local currentSharpness = weapon:getSharpness()
        if not isFiniteNumber(currentSharpness) or currentSharpness <= 0 then
            return nil, nil
        end
        return displayed / currentSharpness, currentSharpness
    end)
    if not ok or not isFiniteNumber(raw) or not isFiniteNumber(sharpness) then
        return nil, nil
    end
    return raw, sharpness
end

local function setRawCriticalChance(weapon, value)
    if not isFiniteNumber(value) then return false end
    return pcall(function()
        weapon:setCriticalChance(value)
    end)
end

local function nearlyEqual(left, right)
    if left == right then return true end
    local scale = math.max(1, math.abs(left), math.abs(right))
    return math.abs(left - right) <= NUMERIC_EPSILON * scale
end

local function restoreWeapon(weapon)
    local tracked = state.trackedWeapons[weapon]
    if not tracked then return end

    local raw = getRawCriticalChance(weapon)
    if raw then
        setRawCriticalChance(weapon, raw - tracked.appliedRawBonus)
    end
    state.trackedWeapons[weapon] = nil
end

local function restoreAllWeapons()
    local restore = {}
    for weapon in pairs(state.trackedWeapons) do restore[#restore + 1] = weapon end
    for i = 1, #restore do restoreWeapon(restore[i]) end
end

local function boostWeapon(weapon)
    local raw, sharpness = getRawCriticalChance(weapon)
    if not raw then return end

    local tracked = state.trackedWeapons[weapon]
    local baseRaw = raw - (tracked and tracked.appliedRawBonus or 0)
    local targetDisplayed = math.min(100, baseRaw * sharpness + CRIT_BONUS)
    local targetRaw = targetDisplayed / sharpness
    local appliedRawBonus = targetRaw - baseRaw

    if nearlyEqual(raw, targetRaw) or setRawCriticalChance(weapon, targetRaw) then
        state.trackedWeapons[weapon] = { appliedRawBonus = appliedRawBonus }
    elseif not tracked then
        state.trackedWeapons[weapon] = nil
    end
end

local function onTick(_player, tick)
    local primary = tick.primaryWeapon
    local secondary = tick.secondaryWeapon
    local current = {}

    if isEligible(primary) then current[primary] = true end
    if secondary ~= primary and isEligible(secondary) then current[secondary] = true end

    local restore = {}
    for weapon in pairs(state.trackedWeapons) do
        if not current[weapon] then restore[#restore + 1] = weapon end
    end
    for i = 1, #restore do restoreWeapon(restore[i]) end

    if current[primary] then boostWeapon(primary) end
    if secondary ~= primary and current[secondary] then boostWeapon(secondary) end
end

if UTCore.unregisterTickHandler then
    UTCore.unregisterTickHandler(TRAIT_ID, "reload")
end
UTCore.registerTickHandler(TRAIT_ID, onTick, {
    throttle = 30,
    vehicleAware = true,
    teardown = restoreAllWeapons,
})
