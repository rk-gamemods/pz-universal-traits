-- UT_motionsickness.lua
-- Motion sickness: stress buildup while in vehicle

local TRAIT_ID = "UniversalTraits:UT_motionsickness"

local lastCheckTick = {}

local function onTick(player, tick)
    local playerId = player:getPlayerNum()
    local currentTick = getGameTime():getTicks()

    lastCheckTick[playerId] = lastCheckTick[playerId] or 0

    if currentTick - lastCheckTick[playerId] < 60 then return end
    lastCheckTick[playerId] = currentTick

    if tick.vehicle ~= nil then
        local stats = tick.stats
        stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.01))
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick, { vehicleAware = true })
