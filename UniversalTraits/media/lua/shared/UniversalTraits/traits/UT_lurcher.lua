-- UT_lurcher.lua
-- -15% work speed and -15% movement speed
-- Runtime: random stumble/bump while moving with low endurance.

local TRAIT_ID = "UniversalTraits:UT_lurcher"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyWorkSpeed(player, 0.15)
    player:getModData()["UT_speedMod"] = -0.15
end

Events.OnNewGame.Add(onNewGame)

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_lurcher_cooldown"] == nil then
        md["UT_lurcher_cooldown"] = 0
    end

    if md["UT_lurcher_cooldown"] > 0 then
        md["UT_lurcher_cooldown"] = md["UT_lurcher_cooldown"] - 1
        return
    end

    -- Must be moving
    local ok, moving = pcall(function() return player:isMoving() end)
    if not (ok and moving) then return end

    -- Must have low endurance (< 0.3)
    local endurance = 1.0
    pcall(function()
        endurance = player:getStats():get(CharacterStat.ENDURANCE)
    end)
    if endurance >= 0.3 then return end

    -- Chance reduced by Nimble level: base 3% minus nimble level
    local nimbleLevel = 0
    pcall(function()
        nimbleLevel = player:getPerkLevel(Perks.Nimble)
    end)
    local chance = 3 - nimbleLevel
    if chance <= 0 then return end

    if ZombRand(100) < chance then
        pcall(function() player:setBumpFallDown(true) end)
        md["UT_lurcher_cooldown"] = 30
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
