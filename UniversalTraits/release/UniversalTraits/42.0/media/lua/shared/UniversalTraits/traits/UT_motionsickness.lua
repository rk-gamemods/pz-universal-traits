-- UT_motionsickness.lua
-- Motion sickness: stress buildup while in vehicle

local TRAIT_ID = "UniversalTraits:UT_motionsickness"

local lastCheckTick = {}

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local playerId = player:getPlayerNum()
    local currentTick = getGameTime():getTicks()

    lastCheckTick[playerId] = lastCheckTick[playerId] or 0

    if currentTick - lastCheckTick[playerId] < 60 then return end
    lastCheckTick[playerId] = currentTick

    if player:getVehicle() ~= nil then
        local stats = player:getStats()
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.01))
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
