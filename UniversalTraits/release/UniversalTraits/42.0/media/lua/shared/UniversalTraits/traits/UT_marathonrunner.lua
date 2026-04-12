-- UT_marathonrunner.lua
-- Marathon Runner: fatigue and endurance degradation reduced by 15%.
-- Checks every 5 ticks for responsiveness; when endurance or fatigue drops,
-- refunds 15% of the loss.

local TRAIT_ID = "UniversalTraits:UT_marathonrunner"

local tickCounter    = 0
local lastEndurance  = nil
local lastFatigue    = nil

local function onTick(player, tick)
    tickCounter = tickCounter + 1
    if tickCounter % 5 ~= 0 then return end

    local stats = tick.stats
    if not stats then return end

    -- Endurance refund
    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    if lastEndurance ~= nil and currentEndurance < lastEndurance then
        local drain  = lastEndurance - currentEndurance
        local refund = drain * 0.15
        stats:set(CharacterStat.ENDURANCE, math.min(1.0, currentEndurance + refund))
        currentEndurance = stats:get(CharacterStat.ENDURANCE)
    end
    lastEndurance = currentEndurance

    -- Fatigue refund (fatigue increases as the player tires; cap at 1.0)
    local currentFatigue = stats:get(CharacterStat.FATIGUE)
    if lastFatigue ~= nil and currentFatigue > lastFatigue then
        local rise   = currentFatigue - lastFatigue
        local refund = rise * 0.15
        stats:set(CharacterStat.FATIGUE, math.max(0.0, currentFatigue - refund))
        currentFatigue = stats:get(CharacterStat.FATIGUE)
    end
    lastFatigue = currentFatigue
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
