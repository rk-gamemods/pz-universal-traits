-- UT_superimmune.lua
-- Super immune: infection resistance

local TRAIT_ID = "UniversalTraits:UT_superimmune"

UTSuperimmuneRuntime = UTSuperimmuneRuntime or {}

if UTSuperimmuneRuntime.onEveryOneMinute then
    Events.EveryOneMinute.Remove(UTSuperimmuneRuntime.onEveryOneMinute)
end

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_superimmune"] = true
end

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local infectionLevel = stats:get(CharacterStat.ZOMBIE_INFECTION)
    if infectionLevel and infectionLevel > 0 then
        stats:set(CharacterStat.ZOMBIE_INFECTION, math.max(0, infectionLevel - 2))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.EveryOneMinute.Add(onEveryOneMinute)
UTSuperimmuneRuntime.onEveryOneMinute = onEveryOneMinute
