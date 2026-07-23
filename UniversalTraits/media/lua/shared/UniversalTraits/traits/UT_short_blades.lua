-- UT_short_blades.lua
-- Runtime bonus: +10 displayed critical-chance points with Small Blade weapons.
-- Recalculated every 30 player-update dispatches and restored whenever inactive.

local TRAIT_ID = "UniversalTraits:UT_short_blades"
local CRIT_BONUS = 10

UTCore._shortBladesState = UTCore._shortBladesState or { trackedWeapons = {} }
local state = UTCore._shortBladesState

local function isEligible(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    if not weapon.isOfWeaponCategory or not WeaponCategory then return false end
    local ok, eligible = pcall(function()
        return weapon:isOfWeaponCategory(WeaponCategory.SMALL_BLADE)
    end)
    return ok and eligible == true
end

local function getRawCriticalChance(weapon)
    local ok, raw, sharpness = pcall(function()
        local displayed = weapon:getCriticalChance()
        if not weapon:hasSharpness() then return displayed, 1 end

        local value = weapon:getSharpness()
        if not value or value <= 0 then return nil, nil end
        return displayed / value, value
    end)
    if not ok then return nil, nil end
    return raw, sharpness
end

local function setRawCriticalChance(weapon, value)
    local ok = pcall(function() weapon:setCriticalChance(value) end)
    return ok
end

local function restoreWeapon(weapon)
    local tracked = state.trackedWeapons[weapon]
    if not tracked then return end

    local raw = getRawCriticalChance(weapon)
    if raw and setRawCriticalChance(weapon, raw - tracked.appliedRawBonus) then
        state.trackedWeapons[weapon] = nil
    end
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

    if setRawCriticalChance(weapon, targetRaw) then
        state.trackedWeapons[weapon] = { appliedRawBonus = appliedRawBonus }
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
