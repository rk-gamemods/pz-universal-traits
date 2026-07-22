-- UT_sharpshooter.lua
-- +25% hit chance and effective range with equipped firearms.
-- Reconciled every 30 player updates and restored whenever inactive or before save.

local TRAIT_ID = "UniversalTraits:UT_sharpshooter"
local MULTIPLIER = 1.25
local HIT_CHANCE_CAP = 100

UTCore._sharpshooterState = UTCore._sharpshooterState or { trackedWeapons = {} }
local state = UTCore._sharpshooterState

local function isEligible(weapon)
    return weapon ~= nil
        and instanceof(weapon, "HandWeapon")
        and weapon:isRanged()
end

local function restoreWeapon(weapon)
    local tracked = state.trackedWeapons[weapon]
    if not tracked then return end

    weapon:setHitChance(weapon:getHitChance() - tracked.hitChanceDelta)
    weapon:setMaxRange(weapon:getMaxRange() - tracked.maxRangeDelta)
    state.trackedWeapons[weapon] = nil
end

local function restoreAllWeapons()
    local restore = {}
    for weapon in pairs(state.trackedWeapons) do restore[#restore + 1] = weapon end
    for i = 1, #restore do restoreWeapon(restore[i]) end
end

local function boostWeapon(weapon)
    local tracked = state.trackedWeapons[weapon]
    local baseHitChance = weapon:getHitChance()
        - (tracked and tracked.hitChanceDelta or 0)
    local baseMaxRange = weapon:getMaxRange()
        - (tracked and tracked.maxRangeDelta or 0)
    local targetHitChance = math.min(
        HIT_CHANCE_CAP,
        math.floor(baseHitChance * MULTIPLIER)
    )
    local targetMaxRange = baseMaxRange * MULTIPLIER

    weapon:setHitChance(targetHitChance)
    weapon:setMaxRange(targetMaxRange)
    state.trackedWeapons[weapon] = {
        hitChanceDelta = targetHitChance - baseHitChance,
        maxRangeDelta = targetMaxRange - baseMaxRange,
    }
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
if state.onSave and Events and Events.OnSave then
    Events.OnSave.Remove(state.onSave)
end
state.onSave = restoreAllWeapons
if Events and Events.OnSave then
    Events.OnSave.Add(state.onSave)
end
UTCore.registerTickHandler(TRAIT_ID, onTick, {
    throttle = 30,
    vehicleAware = true,
    teardown = restoreAllWeapons,
})
