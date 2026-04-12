-- UT_olympian.lua
-- Olympian: fatigue and endurance degradation reduced by 15%.
-- Same mechanic as UT_marathonrunner; stacks additively when both traits are
-- held (~30% total reduction). Uses separate modData keys and state variables
-- so the two hooks do not interfere.

local TRAIT_ID = "UniversalTraits:UT_olympian"

local tickCounter   = 0
local lastEndurance = nil
local lastFatigue   = nil

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

    -- Fatigue refund
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
