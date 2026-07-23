-- UT_humanhamster.lua
-- Human hamster: compulsion to hoard. Must keep inventory burdened.
--
-- NEGATIVE TRAIT (-1 pt). Tradeoff design:
--   Benefit : +2 carry weight (more room to stuff things).
--   Penalty : escalating stress when inventory is below 80% of capacity
--             OR when no backpack/bag is worn.
--             Mirrors the Smoker addiction escalation pattern.
--
-- Escalation timer (UT_hamsterCraving, in minutes of deprivation):
--   0-9 min   : no stress
--   10-29 min : +0.02 stress/min (mild unease)
--   30-59 min : +0.04 stress/min (noticeable urge)
--   60+ min   : +0.08 stress/min (overwhelming compulsion)
-- Craving resets to 0 as soon as BOTH conditions are satisfied:
--   weight >= 80% of max carry AND at least one wearable bag/container is worn.

local TRAIT_ID = "UniversalTraits:UT_humanhamster"
local CRAVING_KEY = "UT_hamsterCraving"

UTHumanHamsterRuntime = UTHumanHamsterRuntime or {
    generation = 0,
    activePlayer = nil,
    carryBaselines = {},
}
local runtime = UTHumanHamsterRuntime
runtime.generation = runtime.generation + 1
local generation = runtime.generation

-- Returns true if the player is wearing any wearable container (backpack, bag, etc.)
local function hasBackpack(player)
    local okWorn, wornItems = pcall(function()
        return player:getWornItems()
    end)
    if not okWorn or not wornItems then return false end

    local okSize, size = pcall(function()
        return wornItems:size()
    end)
    if not okSize or type(size) ~= "number" or size < 0 or size ~= math.floor(size) then
        return false
    end

    for i = 0, size - 1 do
        local okItem, item = pcall(function()
            return wornItems:getItemByIndex(i)
        end)
        if okItem and item then
            local okContainer, isContainer = pcall(function()
                return item:IsInventoryContainer()
            end)
            if okContainer and isContainer then return true end
        end
    end
    return false
end

local function getOwnedCarryValue(player)
    local buckets = player:getModData()["UT_modifierBuckets"]
    local carryBucket = type(buckets) == "table" and buckets["carryFlatAdd"] or nil
    if type(carryBucket) ~= "table" then return nil end
    return carryBucket[TRAIT_ID]
end

local function applyOwnedCarry(player)
    if runtime.carryBaselines[player] == nil then
        local md = player:getModData()
        local baseline = player:getMaxWeightBase()
        if getOwnedCarryValue(player) == 2 and md["UT_carryTargetBase"] == baseline then
            baseline = math.max(1, baseline - 2)
        end
        runtime.carryBaselines[player] = baseline
    end

    UTCore.applyCarryWeight(player, 2, TRAIT_ID)
    if UTCore.reconcileAggregatedModifiers then
        UTCore.reconcileAggregatedModifiers(player)
    end
end

local function clearOwnedState(player)
    if not player then return end

    local md = player:getModData()
    local ownedCarry = getOwnedCarryValue(player)
    local previousTarget = md["UT_carryTargetBase"]
    local baseline = runtime.carryBaselines[player]

    UTCore.applyCarryWeight(player, nil, TRAIT_ID)
    if UTCore.reconcileAggregatedModifiers then
        UTCore.reconcileAggregatedModifiers(player)
    end

    if ownedCarry ~= nil
        and md["UT_carryTargetBase"] == nil
        and previousTarget ~= nil
        and player:getMaxWeightBase() == previousTarget then
        player:setMaxWeightBase(baseline or math.max(1, previousTarget - ownedCarry))
    end

    md[CRAVING_KEY] = nil
    runtime.carryBaselines[player] = nil
end

local function playerIsDead(player)
    if not player.isDead then return false end
    local ok, dead = pcall(function() return player:isDead() end)
    return ok and dead == true
end

local function syncPlayer(player)
    if runtime.activePlayer and runtime.activePlayer ~= player then
        clearOwnedState(runtime.activePlayer)
        runtime.activePlayer = nil
    end

    if not player or playerIsDead(player) or not UTCore.hasTrait(player, TRAIT_ID) then
        clearOwnedState(player)
        if runtime.activePlayer == player then runtime.activePlayer = nil end
        return false
    end

    runtime.activePlayer = player
    applyOwnedCarry(player)
    return true
end

local function onCreatePlayer(_playerIndex, player)
    if generation ~= runtime.generation then return end
    syncPlayer(player)
end

local function onEveryMinute()
    if generation ~= runtime.generation then return end

    local player = getPlayer()
    if not syncPlayer(player) then return end

    local inv         = player:getInventory()
    local weight      = inv:getCapacityWeight()
    local maxWeight   = player:getMaxWeightBase()
    local fullness    = (maxWeight > 0) and (weight / maxWeight) or 0
    local wearingBag  = hasBackpack(player)

    local md = player:getModData()
    md[CRAVING_KEY] = md[CRAVING_KEY] or 0

    -- Satisfied: full enough AND has a bag; reset craving.
    if fullness >= 0.80 and wearingBag then
        md[CRAVING_KEY] = 0
        return
    end

    -- Deprived: increment craving counter
    md[CRAVING_KEY] = md[CRAVING_KEY] + 1
    local craving = md[CRAVING_KEY]

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

local currentPlayer = getPlayer and getPlayer() or nil
if currentPlayer or runtime.activePlayer then
    syncPlayer(currentPlayer)
end
