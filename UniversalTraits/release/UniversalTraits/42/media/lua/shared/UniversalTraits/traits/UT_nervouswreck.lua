-- UT_nervouswreck.lua
-- Nervous wreck: slows panic recovery by adding back a portion of what the engine removes.
--
-- Engine decay reference (verified from BodyDamage.java ReducePanic()):
--   per-call delta = 0.06 * getThirtyFPSMultiplier() + 0.06 * monthsSurvived
--   getThirtyFPSMultiplier() = 0.5 at normal 1x game speed
--   BodyDamage.Update() runs ~60x per real minute at 1x speed
--
-- Baseline recovery rates (awake, no zombies):
--   new player (0 months):  ~1.8 panic/min
--   5-month veteran:        ~19.8 panic/min (full drain in ~5 min)
--
-- This trait fires every 1 in-game minute (~1 real second) and adds back
-- a flat 0.15 + an optional 0.5 when highly stressed.
-- Effect: costs 5-month vet 9/min of their 19.8/min decay (~55% normal recovery).
-- New players are essentially stuck above ~5 panic until stress comes down.

local TRAIT_ID = "UniversalTraits:UT_nervouswreck"

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local panic = stats:get(CharacterStat.PANIC)
    if panic <= 0 then return end

    -- Slow natural recovery with a fixed counter-drain
    stats:add(CharacterStat.PANIC, 0.15)

    -- Extra spike when highly stressed
    local stress = stats:get(CharacterStat.STRESS)
    if stress > 70 then
        stats:add(CharacterStat.PANIC, 0.5)
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)
