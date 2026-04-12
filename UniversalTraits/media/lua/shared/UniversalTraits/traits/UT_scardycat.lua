-- UT_scardycat.lua
-- Scaredy Cat: two independent mechanics.
--
-- 1. Panic cascade: the next time panic rises by >= 0.05 in a single minute,
--    an additional +0.15 is added. Fires at most once per minute.
--
-- 2. Involuntary scream: when 8+ zombies are spotted and the 3% chance fires,
--    addSound() creates world-audible noise (radius 15). Cooldown: 120 ticks.

local TRAIT_ID = "UniversalTraits:UT_scardycat"

local prevPanic = {}

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local current = stats:get(CharacterStat.PANIC)
    local playerId = tostring(player)
    local prev = prevPanic[playerId]

    if prev ~= nil and (current - prev) >= 5 then
        stats:set(CharacterStat.PANIC, math.min(100, current + 15))
    end

    prevPanic[playerId] = current
end

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    md["UT_scardycat_cooldown"] = md["UT_scardycat_cooldown"] or 0

    if md["UT_scardycat_cooldown"] > 0 then
        md["UT_scardycat_cooldown"] = md["UT_scardycat_cooldown"] - 1
        return
    end

    -- Count LIVING zombies only (dead zombies stay in spottedList)
    local zombieCount = 0
    pcall(function()
        local list = player:getSpottedList()
        for i = 0, list:size() - 1 do
            if not list:get(i):isDead() then
                zombieCount = zombieCount + 1
            end
        end
    end)
    if zombieCount <= 8 then return end

    if ZombRand(100) < 3 then
        -- addSound creates world-audible noise (B42 API): guarded separately so Say() always fires
        pcall(function()
            addSound(player, player:getX(), player:getY(), player:getZ(), 15, 15)
        end)
        player:Say("!")
        md["UT_scardycat_cooldown"] = 120
    end
end

Events.EveryOneMinute.Add(onEveryMinute)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
