-- UT_butterfingers.lua
-- Butter fingers: occasional item drop

local TRAIT_ID = "UniversalTraits:UT_butterfingers"

local lastCheckTick = {}

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local playerId = player:getPlayerNum()
    local currentTick = getGameTime():getTicks()

    lastCheckTick[playerId] = lastCheckTick[playerId] or 0

    if currentTick - lastCheckTick[playerId] < 300 then return end
    lastCheckTick[playerId] = currentTick

    if ZombRand(100) < 3 then
        player:getModData()["UT_dropNext"] = true
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
