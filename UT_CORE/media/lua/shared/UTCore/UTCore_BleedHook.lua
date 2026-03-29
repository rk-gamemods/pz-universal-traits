-- UTCore_BleedHook.lua
-- Reads UT_bleedMult from player moddata and applies it to all actively bleeding
-- body parts every 30 OnPlayerUpdate ticks (~1 real second at default day length).
--
-- ============================================================
-- PZ BLEED MECHANICS (B42) — verified against Java source
-- ============================================================
--
-- GENERAL HEALTH POOL (what kills you)
--   Player has 0-100 general health. Reaching 0 = death.
--   Native bleed drain formula (BodyPart.DamageUpdate, every tick):
--     drain = 0.2857 * damageScaler * GameTime.multiplier * (bleedingTime / 10)
--     → applied to ReduceGeneralHealth(), NOT to body part local health
--
--   damageScaler by location:
--     Standard body parts: ~0.00571
--     Neck:                ~0.02857  (5x multiplier — neck bleeds 5x faster)
--
--   bleedingTime: wound severity counter, set at wound creation, decays over time.
--     Typical ranges: scratch ~1-3, cut ~3-8, deep wound ~8-15, bite ~7-15
--     Decay rate (unbandaged): 0.00002 * multiplier per tick = ~0.0006/sec
--     Decay rate (bandaged):   0.0002  * multiplier per tick = ~0.006/sec  (10x faster)
--     → As bleedingTime decays, drain rate decreases. Bleeding gets SLOWER on its own.
--     → Bandaging stops the drain quickly; unbandaged wound self-resolves in hours.
--
--   Approximate time-to-death from untreated neck wound (bleedingTime ~15):
--     ~20-25 in-game minutes = ~20-25 real seconds at default day length
--     (1 in-game minute = 1 real second at default settings)
--     This matches the in-game experience: serious neck wound = bandage immediately or die.
--
-- BODY PART LOCAL HEALTH (what this hook touches)
--   Each body part has its own 0-100 health value.
--   Body part health feeds into general health via:
--     overallHealth = 100 - sum(100 - partHealth) * partDamageModifier)
--   Neck damageModifier = 0.7
--   → AddHealth(0.002) to neck body part = ~+0.0014 general health recovered/sec
--   → Native neck bleed drains ~0.037 general health/sec at bleedingTime=15
--   → THIS HOOK COUNTERS ROUGHLY 4% OF NECK BLEED DRAIN — not survival-critical
--
-- IMPACTFUL VS TRIVIAL VALUES
--   To meaningfully extend survival on a serious wound, you need to either:
--     (a) add directly to general health (not body part health), or
--     (b) use a very large mult delta (e.g. mult=0.5 only counters ~2% more than mult=0.0)
--   Body part health restoration via this hook is cosmetic for serious bleeds.
--   It is most noticeable on minor wounds (scratch/cut) where drain is slow anyway.
--
-- UT_bleedMult reference values:
--   1.0  = default (no effect, hook exits early)
--   0.0  = max heal via AddHealth(0.002 * neckMult) per 30 ticks — ~4% counter on neck
--   3.0  = anemic: ReduceHealth(0.002 * neckMult) per 30 ticks — adds ~4% more drain
--   Higher mult = more drain added. Lower mult = more heal added. Effect is small either way.
-- ============================================================
--
-- mult < 1.0: counteracts bleeding via AddHealth on the body part
-- mult > 1.0: accelerates bleeding via ReduceHealth on the body part
-- Neck body part receives 2x adjustment (on top of its native 5x scaler).

UTCore = UTCore or {}

local THROTTLE = 30
UTCore._bleedTickCounter = 0

local function onPlayerUpdate(player)
    if not player then return end

    UTCore._bleedTickCounter = UTCore._bleedTickCounter + 1
    if UTCore._bleedTickCounter < THROTTLE then return end
    UTCore._bleedTickCounter = 0

    local md = player:getModData()
    local mult = md["UT_bleedMult"]
    if not mult or mult == 1.0 then return end

    local bd = player:getBodyDamage()
    if not bd then return end
    if bd:getNumPartsBleeding() == 0 then return end

    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part:bleeding() and not part:IsBleedingStemmed() then
            local neckMult = (part:getType() == BodyPartType.Neck) and 2.0 or 1.0
            if mult < 1.0 then
                part:AddHealth(0.002 * (1.0 - mult) * neckMult)
            else
                part:ReduceHealth(0.001 * (mult - 1.0) * neckMult)
            end
        end
    end
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
