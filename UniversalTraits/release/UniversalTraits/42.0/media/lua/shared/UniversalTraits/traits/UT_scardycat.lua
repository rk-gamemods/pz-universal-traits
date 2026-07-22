-- UT_scardycat.lua
-- Scaredy Cat: two independent mechanics.
--
-- 1. Panic cascade: when panic rises by at least 5 points between minute
--    checks, an additional 15 points are added. The post-bonus value becomes
--    the next baseline, so the trait cannot retrigger its own increase.
--
-- 2. Involuntary scream: when 9+ living zombies are spotted and the 3% chance fires,
--    addSound() creates world-audible noise (radius 15). Cooldown: 120 ticks.

local TRAIT_ID = "UniversalTraits:UT_scardycat"

UTCore._scardycatState = UTCore._scardycatState or {}
local state = UTCore._scardycatState

local function onEveryMinute(player)
    if state.player ~= player then
        state.player = player
        state.previousPanic = nil
    end
    if not UTCore.hasTrait(player, TRAIT_ID) then
        state.previousPanic = nil
        return
    end

    local stats = player:getStats()
    local current = stats:get(CharacterStat.PANIC)
    local prev = state.previousPanic

    if prev ~= nil and (current - prev) >= 5 then
        current = math.min(100, current + 15)
        stats:set(CharacterStat.PANIC, current)
    end

    state.previousPanic = current
end

local function onTick(player, tick)
    local md = tick.modData
    md["UT_scardycat_cooldown"] = md["UT_scardycat_cooldown"] or 0

    if md["UT_scardycat_cooldown"] > 0 then
        md["UT_scardycat_cooldown"] = md["UT_scardycat_cooldown"] - 1
        return
    end

    -- Build enemy list (lazy in tick context)
    local _, enemyCount = UTCore.getLivingEnemies(tick)

    -- Use living enemy count from tick cache
    if enemyCount <= 8 then return end

    if ZombRand(100) < 3 then
        -- addSound creates world-audible noise (B42 API): guarded separately so Say() always fires
        pcall(function()
            addSound(player, player:getX(), player:getY(), player:getZ(), 15, 15)
        end)
        player:Say("!")
        md["UT_scardycat_cooldown"] = 120
    end
end

if UTCore.unregisterTickHandler then
    UTCore.unregisterTickHandler(TRAIT_ID, "reload")
end
UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", onEveryMinute)
UTCore.registerTickHandler(TRAIT_ID, onTick)
