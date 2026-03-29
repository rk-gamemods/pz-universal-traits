-- UT_nervouswreck.lua
-- Nervous wreck: slows panic recovery by 70% by reducing the engine's own
-- panicReductionValue from the default 0.06 to 0.018.
--
-- Engine decay reference (verified from BodyDamage.java ReducePanic()):
--   default panicReductionValue = 0.06
--   per-call delta = 0.06 * getThirtyFPSMultiplier() + 0.06 * monthsSurvived
--   BodyDamage.Update() runs ~60x per real minute at 1x speed
--
-- Recovery rates without trait (awake, no zombies):
--   new player (0 months):  ~1.8 panic/min
--   5-month veteran:        ~19.8 panic/min (full drain in ~5 min)
--
-- Recovery rates with trait (70% reduction):
--   new player:             ~0.54 panic/min (~3x slower, still drains)
--   5-month veteran:        ~5.94 panic/min (~17 min to full drain)
--
-- The value is applied once and reverted when the trait is absent.
-- Sleeping still doubles the reduced rate (engine behaviour unchanged).

local TRAIT_ID    = "UniversalTraits:UT_nervouswreck"
local BASE_VALUE  = 0.06
local TRAIT_VALUE = 0.018  -- 70% reduction

local function onPlayerUpdate(player)
    local bd = player:getBodyDamage()
    if not bd then return end

    local current = bd:getPanicReductionValue()
    local hasTrait = UTCore.hasTrait(player, TRAIT_ID)

    if hasTrait then
        if math.abs(current - TRAIT_VALUE) > 0.001 then
            bd:setPanicReductionValue(TRAIT_VALUE)
        end
    else
        if math.abs(current - BASE_VALUE) > 0.001 then
            bd:setPanicReductionValue(BASE_VALUE)
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
