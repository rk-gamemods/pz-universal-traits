-- UT_actionhero.lua
-- Action Hero: +15% crit chance on equipped weapons when 3+ enemies are nearby.
-- Recalculated every 30 ticks. Bonus removed when enemy count drops below 3.
-- Skipped if player has UT_mundane (mundane disables crits).

local TRAIT_ID = "UniversalTraits:UT_actionhero"
local CRIT_BONUS = 15
local ENEMY_THRESHOLD = 3
local ENEMY_RANGE = 10

local tickCounter = 0

local function applyCritBonus(weapon, active)
    if not weapon or not instanceof(weapon, "HandWeapon") then return end

    local wmd = weapon:getModData()

    if wmd["UT_ahBaseCrit"] == nil then
        wmd["UT_ahBaseCrit"] = weapon:getCriticalChance()
    end

    local base = wmd["UT_ahBaseCrit"]
    local target = active and math.min(100, base + CRIT_BONUS) or base

    if weapon:getCriticalChance() ~= target then
        weapon:setCriticalChance(target)
    end
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    -- Mundane disables crits
    if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return end

    -- Count nearby enemies
    local spottedList = player:getSpottedList()
    local nearbyCount = 0
    for i = 0, spottedList:size() - 1 do
        local enemy = spottedList:get(i)
        if player:DistTo(enemy) <= ENEMY_RANGE then
            nearbyCount = nearbyCount + 1
        end
    end

    local active = nearbyCount >= ENEMY_THRESHOLD

    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    applyCritBonus(primary, active)
    applyCritBonus(secondary, active)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
