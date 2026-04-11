-- UT_nervouswreck.lua
-- Nervous wreck: slows panic recovery by 70% by scaling down the engine's
-- panicReductionValue. Reads the current value once on trait acquisition,
-- stores it, then writes 30% of that value. Restores on trait removal.
--
-- This avoids stomping other mods: if another trait has already modified
-- panicReductionValue, we reduce *that* value by 70% rather than overwriting
-- with a hardcoded absolute. Two conflicting traits that both scale this value
-- will compose multiplicatively, which is reasonable behaviour.
--
-- Engine decay reference (verified from BodyDamage.java ReducePanic()):
--   default panicReductionValue = 0.06
--   per-call delta = value * getThirtyFPSMultiplier() + value * monthsSurvived
--   BodyDamage.Update() runs ~60x per real minute at 1x speed
--
-- With 70% reduction from default:
--   new player:       ~0.54 panic/min (was ~1.8)
--   5-month veteran:  ~5.94 panic/min (was ~19.8, full drain ~17 min)
-- Sleeping still doubles the reduced rate (engine behaviour unchanged).

local TRAIT_ID  = "UniversalTraits:UT_nervouswreck"
local REDUCTION = 0.30  -- keep 30% of current value (70% slower recovery)

local function onPlayerUpdate(player)
    local bd = player:getModData()
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local hasTrait = UTCore.hasTrait(player, TRAIT_ID)
    local isApplied = bd["UT_nervouswreck_applied"] == true

    if hasTrait and not isApplied then
        -- Snapshot current value and apply reduction
        local current = bodyDamage:getPanicReductionValue()
        bd["UT_nervouswreck_base"] = current
        bodyDamage:setPanicReductionValue(current * REDUCTION)
        bd["UT_nervouswreck_applied"] = true

    elseif not hasTrait and isApplied then
        -- Restore to snapshotted value
        local base = bd["UT_nervouswreck_base"]
        if base then
            bodyDamage:setPanicReductionValue(base)
        end
        bd["UT_nervouswreck_applied"] = false
        bd["UT_nervouswreck_base"] = nil
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
