-- UT_humanhamster.lua
-- Human hamster: compulsion to hoard. Must keep inventory burdened.
--
-- NEGATIVE TRAIT (-3 pts). Tradeoff design:
--   Benefit : +2 carry weight (more room to stuff things).
--   Penalty : escalating stress when inventory is below 80% of capacity
--             OR when no backpack/bag is worn.
--             Mirrors the Smoker addiction escalation pattern.
--
-- Escalation timer (UT_hamsterCraving, in minutes of deprivation):
--   0–9 min   : no stress
--   10–29 min : +0.02 stress/min (mild unease)
--   30–59 min : +0.04 stress/min (noticeable urge)
--   60+ min   : +0.08 stress/min (overwhelming compulsion)
-- Craving resets to 0 as soon as BOTH conditions are satisfied:
--   weight >= 80% of max carry AND at least one wearable bag/container is worn.

local TRAIT_ID = "UniversalTraits:UT_humanhamster"

-- Returns true if the player is wearing any wearable container (backpack, bag, etc.)
local function hasBackpack(player)
    local wornItems = player:getWornItems()
    if not wornItems then return false end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItem(i)
        if wornItem then
            local item = wornItem:getItem()
            if item and item:IsInventoryContainer() then
                return true
            end
        end
    end
    return false
end

local function onCreatePlayer(_playerIndex, player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyCarryWeight(player, 2)
end

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local inv         = player:getInventory()
    local weight      = inv:getCapacityWeight()
    local maxWeight   = player:getMaxWeightBase()
    local fullness    = (maxWeight > 0) and (weight / maxWeight) or 0
    local wearingBag  = hasBackpack(player)

    local md = player:getModData()
    md["UT_hamsterCraving"] = md["UT_hamsterCraving"] or 0

    -- Satisfied: full enough AND has a bag — reset craving
    if fullness >= 0.80 and wearingBag then
        md["UT_hamsterCraving"] = 0
        return
    end

    -- Deprived: increment craving counter
    md["UT_hamsterCraving"] = md["UT_hamsterCraving"] + 1
    local craving = md["UT_hamsterCraving"]

    local stress = 0
    if craving >= 60 then
        stress = 0.08
    elseif craving >= 30 then
        stress = 0.04
    elseif craving >= 10 then
        stress = 0.02
    end

    if stress > 0 then
        local stats = player:getStats()
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + stress))
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.EveryOneMinute.Add(onEveryMinute)
