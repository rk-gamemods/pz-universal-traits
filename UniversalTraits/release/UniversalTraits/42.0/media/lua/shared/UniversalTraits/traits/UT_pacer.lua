-- UT_pacer.lua
-- +15% movement speed modifier
-- Runtime: restlessness indoors — gains unhappiness after extended time inside.

local TRAIT_ID = "UniversalTraits:UT_pacer"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySpeedModifier(player, 0.15, TRAIT_ID)
end

local function onNewGame(player)
    applyTrait(player)
end

local function onCreatePlayer(_playerIndex, player)
    applyTrait(player)
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_pacer_indoor_ticks"] == nil then
        md["UT_pacer_indoor_ticks"] = 0
    end

    -- Check if indoors (isIndoors removed in B42 -- use not isOutside())
    local indoors = false
    local ok, result = pcall(function() return not player:isOutside() end)
    if ok then indoors = result end

    if not indoors then
        md["UT_pacer_indoor_ticks"] = 0
        return
    end

    -- Increment indoor counter
    md["UT_pacer_indoor_ticks"] = md["UT_pacer_indoor_ticks"] + 1

    -- After 600 ticks indoors, apply unhappiness penalty
    if md["UT_pacer_indoor_ticks"] >= 600 then
        pcall(function()
            local stats = player:getStats()
            stats:set(CharacterStat.UNHAPPINESS, math.min(100, stats:get(CharacterStat.UNHAPPINESS) + 2))
        end)
        md["UT_pacer_indoor_ticks"] = 0
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
