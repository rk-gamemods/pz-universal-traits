-- UTCore_NoiseHook.lua
-- Reads UT_noiseMult from player moddata.
-- While the player is sleeping, emits periodic noise pulses scaled by the multiplier.
-- Fires on EveryOneMinute (in-game minute). When asleep, extra noise is produced
-- every in-game minute beyond the minimal default sleeping noise.
--
-- UT_noiseMult reference values:
--   1.0 → no extra noise (hook exits early; also catches "not set" case)
--   2.0 → double sleeping noise (UT_snorer default: loud snoring, ~10 unit radius)
--
-- Noise radius is a linear multiple of a base sleeping noise level of 5 units.
-- A mult of 2.0 emits 5 units of extra noise (total 10), attracting zombies
-- within a short radius even through walls if sufficiently loud.
--
-- Requires player:isAsleep() which returns true during the PZ sleep cycle.
-- If the API is unavailable (version mismatch), the hook exits silently.

UTCore = UTCore or {}

local BASE_SLEEPING_NOISE = 5

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    local mult = md["UT_noiseMult"]
    if not mult or mult <= 1.0 then return end

    -- Only emit when actually sleeping
    local ok, sleeping = pcall(function() return player:isAsleep() end)
    if not (ok and sleeping) then return end

    -- Emit noise: extra amount above baseline sleeping noise
    local extraNoise = math.floor(BASE_SLEEPING_NOISE * (mult - 1.0))
    if extraNoise <= 0 then return end

    pcall(function()
        player:addWorldSoundUnlessInvisible(extraNoise, 1, false)
    end)
end

if Events and Events.EveryOneMinute then
    if UTCore.profiledHandler then
        Events.EveryOneMinute.Add(UTCore.profiledHandler("NoiseHook", onEveryMinute))
    else
        Events.EveryOneMinute.Add(onEveryMinute)
    end
end
