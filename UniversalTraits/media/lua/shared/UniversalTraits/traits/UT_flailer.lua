-- UT_flailer.lua
-- -15% combat accuracy
-- Runtime: random stumble/trip while panicked and sprinting.

local TRAIT_ID = "UniversalTraits:UT_flailer"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_combatAccuracyMod"] = -0.15
end

Events.OnNewGame.Add(onNewGame)

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_flailer_cooldown"] == nil then
        md["UT_flailer_cooldown"] = 0
    end

    if md["UT_flailer_cooldown"] > 0 then
        md["UT_flailer_cooldown"] = md["UT_flailer_cooldown"] - 1
        return
    end

    -- Must be sprinting
    local ok, sprinting = pcall(function() return player:isSprinting() end)
    if not (ok and sprinting) then return end

    -- Must have panic moodle active
    local panicLevel = 0
    pcall(function()
        panicLevel = player:getBodyDamage():getPanicLevel()
    end)
    if panicLevel <= 0 then return end

    -- 5% chance to stumble
    if ZombRand(100) < 5 then
        pcall(function() player:setBumpFallDown(true) end)
        md["UT_flailer_cooldown"] = 30
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
