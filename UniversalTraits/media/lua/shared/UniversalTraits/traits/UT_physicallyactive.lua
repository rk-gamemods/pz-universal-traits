-- UT_physicallyactive.lua
-- Physically active: fitness XP bonus marker

local TRAIT_ID = "UniversalTraits:UT_physicallyactive"

local lastCheckTick = {}

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local playerId = player:getPlayerNum()
    local currentTick = getGameTime():getTicks()

    lastCheckTick[playerId] = lastCheckTick[playerId] or 0

    if currentTick - lastCheckTick[playerId] < 600 then return end
    lastCheckTick[playerId] = currentTick

    player:getModData()["UT_physActiveBonus"] = true
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
