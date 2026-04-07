-- UT_natural.lua
-- Natural: movement speed +10%, reduced by 2% per clothing item worn.
-- Formula: bonus = max(0, 0.10 - clothingCount * 0.02)
-- At 5+ clothing items the bonus reaches zero. Recalculated every 30 ticks.
--
-- ==================== HOW THIS WORKS ====================
-- This trait just calls UTCore.applySpeedModifier() with its calculated bonus.
-- That feeds into the unified modifier bucket system (UTCore_StatModifiers.lua),
-- which aggregates all speed modifiers from all traits into one UT_speedMod value.
-- The actual movement scaling is handled by UTCore_SpeedHook.lua using safe
-- nextX/nextY delta scaling — this trait never touches position or moveSpeed.
--
-- ==================== WHY NOT setMoveSpeed()? ====================
-- The old implementation cached getMoveSpeed() (a derived value that includes
-- injury penalties) and replayed it into setMoveSpeed() (the raw base field).
-- Two bugs:
--   1. Caching a derived value bakes injury states permanently into base speed
--   2. setMoveSpeed() fights BodyDamage.java:2544 which resets it to 0.06F
-- Using the UTCore modifier system avoids both problems entirely.
-- =================================================================

local TRAIT_ID = "UniversalTraits:UT_natural"
local SOURCE_ID = "UT_natural"

local tickCounter = 0

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local clothingCount = (player:getWornItems() and player:getWornItems():size()) or 0
    local bonus = math.max(0.0, 0.10 - (clothingCount * 0.02))

    local md = player:getModData()

    -- Only update if the bonus changed (avoids unnecessary bucket recalculation)
    if md["UT_naturalLastBonus"] ~= bonus then
        md["UT_naturalLastBonus"] = bonus
        UTCore.applySpeedModifier(player, bonus, SOURCE_ID)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
