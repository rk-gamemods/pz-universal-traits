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

local function onTick(player, tick)
    local md = tick.modData
    local t = (md["UT_noodlelegs_tick"] or 0) + 1
    md["UT_noodlelegs_tick"] = t
    if t < 30 then return end
    md["UT_noodlelegs_tick"] = 0

    local stats = tick.stats
    local cur = stats:get(CharacterStat.ENDURANCE)
    if cur > 0 then
        stats:set(CharacterStat.ENDURANCE, math.max(cur - 0.005, 0))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.OnCreatePlayer.Add(onCreatePlayer)
UTCore.registerTickHandler(TRAIT_ID, onTick)
