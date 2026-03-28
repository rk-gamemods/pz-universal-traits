-- UT_noodlelegs.lua
-- -20% speed and reduced endurance recovery

local TRAIT_ID = "UniversalTraits:UT_noodlelegs"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_speedMod"] = -0.2
end

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local tick = (md["UT_noodlelegs_tick"] or 0) + 1
    md["UT_noodlelegs_tick"] = tick
    if tick < 30 then return end
    md["UT_noodlelegs_tick"] = 0

    local stats = player:getStats()
    local cur = stats:getEndurance()
    if cur > 0 then
        stats:setEndurance(math.max(cur - 0.005, 0))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
