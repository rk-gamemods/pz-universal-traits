-- UT_noodlelegs.lua
-- -20% speed and reduced endurance recovery

local TRAIT_ID = "UniversalTraits:UT_noodlelegs"

local function applyTrait(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applySpeedModifier(player, -0.2, TRAIT_ID)
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
    local tick = (md["UT_noodlelegs_tick"] or 0) + 1
    md["UT_noodlelegs_tick"] = tick
    if tick < 30 then return end
    md["UT_noodlelegs_tick"] = 0

    local stats = player:getStats()
    local cur = stats:get(CharacterStat.ENDURANCE)
    if cur > 0 then
        stats:set(CharacterStat.ENDURANCE, math.max(cur - 0.005, 0))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
