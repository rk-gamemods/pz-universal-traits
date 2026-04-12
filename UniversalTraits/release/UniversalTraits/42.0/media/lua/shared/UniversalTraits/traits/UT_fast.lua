-- UT_fast.lua
-- Speed boost and improved endurance recovery

local TRAIT_ID = "UniversalTraits:UT_fast"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySpeedModifier(player, 0.3, TRAIT_ID)
end

local function onNewGame(player)
    applyTrait(player)
end

local function onCreatePlayer(_playerIndex, player)
    applyTrait(player)
end

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local tick = (md["UT_fast_tick"] or 0) + 1
    md["UT_fast_tick"] = tick
    if tick < 30 then return end
    md["UT_fast_tick"] = 0

    local stats = player:getStats()
    if stats:get(CharacterStat.ENDURANCE) < CharacterStat.ENDURANCE:getMaximumValue() then
        stats:set(CharacterStat.ENDURANCE, math.min(stats:get(CharacterStat.ENDURANCE) + 0.01, CharacterStat.ENDURANCE:getMaximumValue()))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
