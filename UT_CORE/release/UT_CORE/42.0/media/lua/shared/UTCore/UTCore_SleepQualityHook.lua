-- UTCore_SleepQualityHook.lua
-- Reads UT_sleepQualMod from player moddata.
-- Fires on EveryOneMinute while the player is sleeping.
-- Applies additional fatigue reduction per in-game minute of sleep.
--
-- Fatigue is a 0–1 float (0 = fully rested, 1 = exhausted).
-- Vanilla sleep decreases fatigue at approximately 0.003–0.006 per in-game minute
-- depending on bed quality and pain level.
--
-- UT_sleepQualMod reference values:
--   0.3 (quickrest)      → 0.001×0.3 = +0.0003 extra/min · 480min sleep ≈ 0.14 bonus
--   0.5 (restfulsleeper) → 0.001×0.5 = +0.0005 extra/min · 480min sleep ≈ 0.24 bonus
--
-- Effect: restfulsleeper wakes from an 8-hour sleep ~24% further into recovery
-- compared to baseline, which is noticeable across multiple nights. This is modest
-- rather than overwhelming, matching the 6-point Cost.
--
-- Requires player:isAsleep() and player:getStats():set(CharacterStat.FATIGUE, ).
-- Capped at 0 — player cannot go below fully rested.

UTCore = UTCore or {}

local PER_MINUTE_SCALE = 0.001

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    local delta = md["UT_sleepQualMod"]
    if not delta or delta <= 0 then return end

    local ok, sleeping = pcall(function() return player:isAsleep() end)
    if not (ok and sleeping) then return end

    local stats = player:getStats()
    if not stats then return end

    local fatigue = stats:get(CharacterStat.FATIGUE)
    local reduction = delta * PER_MINUTE_SCALE
    stats:set(CharacterStat.FATIGUE, math.max(0, fatigue - reduction))
end

if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(onEveryMinute)
end
