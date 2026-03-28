-- UTCore_SpawnEffects.lua
-- Spawn-with-condition helpers (injury, burns, fractures).
-- Phase 2 implementation.

UTCore = UTCore or {}

-- Applies a table of stat values to the player at spawn.
-- Supported keys: panic, stress, hunger, thirst, fatigue, endurance, carryDelta
function UTCore.applySpawnStats(player, statTable)
    local stats = player:getStats()
    for k, v in pairs(statTable) do
        if k == "panic" then
            stats:setPanic(v)
        elseif k == "stress" then
            stats:setStress(v)
        elseif k == "hunger" then
            stats:setHunger(v)
        elseif k == "thirst" then
            stats:setThirst(v)
        elseif k == "fatigue" then
            stats:setFatigue(v)
        elseif k == "endurance" then
            stats:setEndurance(v)
        elseif k == "carryDelta" then
            UTCore.applyCarryWeight(player, v)
        end
    end
end

-- Applies spawn conditions: injuries, fractures, and burn severity.
-- conditionTable.injuries  = array of BodyPartType integer IDs to injure (setHealth(0.5))
-- conditionTable.fractures = array of BodyPartType integer IDs to fracture (setFractured(true))
-- conditionTable.burnSeverity = 0.0-1.0 float applied to all body parts
function UTCore.applySpawnCondition(player, conditionTable)
    local bodyDamage = player:getBodyDamage()

    if conditionTable.injuries then
        for _, partId in ipairs(conditionTable.injuries) do
            bodyDamage:getBodyPart(partId):setHealth(0.5)
        end
    end

    if conditionTable.fractures then
        for _, partId in ipairs(conditionTable.fractures) do
            bodyDamage:getBodyPart(partId):setFractured(true)
        end
    end

    if conditionTable.burnSeverity then
        local severity = conditionTable.burnSeverity
        local parts = bodyDamage:getBodyParts()
        if parts then
            for i = 0, parts:size() - 1 do
                parts:get(i):setBurnDamage(severity)
            end
        end
    end
end
