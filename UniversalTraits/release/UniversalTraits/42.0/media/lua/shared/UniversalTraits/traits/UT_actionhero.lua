-- UT_actionhero.lua
-- Action Hero: +15% crit chance on equipped weapons when 3+ enemies are nearby.
-- Recalculated every 30 player-update dispatches. Bonus is always removed when inactive.
-- Skipped if player has UT_mundane (mundane disables crits).

local TRAIT_ID = "UniversalTraits:UT_actionhero"
local CRIT_BONUS = 15
local ENEMY_THRESHOLD = 3
local ENEMY_RANGE = 10

UTCore._actionHeroState = UTCore._actionHeroState or { trackedWeapons = {} }
local state = UTCore._actionHeroState

local function getRawCriticalChance(weapon)
    local displayed = weapon:getCriticalChance()
    if not weapon:hasSharpness() then return displayed, 1 end

    local sharpness = weapon:getSharpness()
    if not sharpness or sharpness <= 0 then return nil, nil end
    return displayed / sharpness, sharpness
end

local function restoreWeapon(weapon)
    local tracked = state.trackedWeapons[weapon]
    if not tracked then return end

    local raw = getRawCriticalChance(weapon)
    if raw then
        weapon:setCriticalChance(raw - tracked.appliedRawBonus)
    end
    state.trackedWeapons[weapon] = nil
end

local function restoreAllWeapons()
    local restore = {}
    for weapon in pairs(state.trackedWeapons) do restore[#restore + 1] = weapon end
    for i = 1, #restore do restoreWeapon(restore[i]) end
end

local function boostWeapon(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end

    local raw, sharpness = getRawCriticalChance(weapon)
    if not raw then return end

    local tracked = state.trackedWeapons[weapon]
    local baseRaw = raw - (tracked and tracked.appliedRawBonus or 0)
    local targetDisplayed = math.min(100, baseRaw * sharpness + CRIT_BONUS)
    local targetRaw = targetDisplayed / sharpness
    local appliedRawBonus = targetRaw - baseRaw

    weapon:setCriticalChance(targetRaw)
    state.trackedWeapons[weapon] = { appliedRawBonus = appliedRawBonus }
end

local function countNearbyEnemies(player)
    local ok, count = pcall(function()
        local list = player:getSpottedList()
        local nearby = 0
        for i = 0, list:size() - 1 do
            local enemy = list:get(i)
            if not enemy:isDead() and player:DistTo(enemy) <= ENEMY_RANGE then
                nearby = nearby + 1
            end
        end
        return nearby
    end)
    if not ok then return nil end
    return count
end

local function onTick(player, tick)
    local nearbyCount = countNearbyEnemies(player)
    local active = nearbyCount ~= nil
        and nearbyCount >= ENEMY_THRESHOLD
        and not UTCore.hasTrait(player, "UniversalTraits:UT_mundane")

    local primary = tick.primaryWeapon
    local secondary = tick.secondaryWeapon
    local restore = {}
    for weapon in pairs(state.trackedWeapons) do
        if not active or (weapon ~= primary and weapon ~= secondary) then
            restore[#restore + 1] = weapon
        end
    end
    for i = 1, #restore do restoreWeapon(restore[i]) end

    if not active then return end
    boostWeapon(primary)
    if secondary ~= primary then boostWeapon(secondary) end
end

if UTCore.unregisterTickHandler then
    UTCore.unregisterTickHandler(TRAIT_ID, "reload")
end
UTCore.registerTickHandler(TRAIT_ID, onTick, {
    throttle = 30,
    teardown = restoreAllWeapons,
})
