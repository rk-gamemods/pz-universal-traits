-- UTCore_NoiseHook.lua
-- Emits mod-defined extra sleeping noise for players with UT_noiseMult.

UTCore = UTCore or {}

local EXTRA_NOISE_RADIUS_SCALE = 5

local function onSleepingMinute()
    if type(getPlayer) ~= "function" then return end

    local playerOk, player = pcall(getPlayer)
    if not (playerOk and player) then return end

    local asleepOk, asleep = pcall(function() return player:isAsleep() end)
    if not (asleepOk and asleep) then return end

    local ok, md = pcall(function() return player:getModData() end)
    if not (ok and md) then return end

    local mult = md["UT_noiseMult"]
    if type(mult) ~= "number" or mult ~= mult or mult == math.huge or mult == -math.huge or mult <= 1.0 then return end

    local scaledNoise = EXTRA_NOISE_RADIUS_SCALE * (mult - 1.0)
    if scaledNoise ~= scaledNoise or scaledNoise == math.huge then return end

    local extraNoise = math.floor(scaledNoise)
    if extraNoise <= 0 then return end

    local soundOk, addWorldSound = pcall(function()
        return player.addWorldSoundUnlessInvisible
    end)
    if not (soundOk and type(addWorldSound) == "function") then return end

    pcall(function()
        addWorldSound(player, extraNoise, 1, false)
    end)
end

local sleepingMinuteEvent = Events and Events.EveryOneMinute
if sleepingMinuteEvent
        and type(sleepingMinuteEvent.Add) == "function"
        and type(sleepingMinuteEvent.Remove) == "function" then
    local removed = true
    if UTCore.NoiseHookHandler then
        removed = pcall(function()
            sleepingMinuteEvent.Remove(UTCore.NoiseHookHandler)
        end)
    end

    if removed then
        local added = pcall(function()
            sleepingMinuteEvent.Add(onSleepingMinute)
        end)
        if added then
            UTCore.NoiseHookHandler = onSleepingMinute
        end
    end
end
