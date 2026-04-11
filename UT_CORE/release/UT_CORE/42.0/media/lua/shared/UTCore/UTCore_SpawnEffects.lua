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
            stats:set(CharacterStat.PANIC, v)
        elseif k == "stress" then
            stats:set(CharacterStat.STRESS, v)
        elseif k == "hunger" then
            stats:set(CharacterStat.HUNGER, v)
        elseif k == "thirst" then
            stats:set(CharacterStat.THIRST, v)
        elseif k == "fatigue" then
            stats:set(CharacterStat.FATIGUE, v)
        elseif k == "endurance" then
            stats:set(CharacterStat.ENDURANCE, v)
        elseif k == "carryDelta" then
            UTCore.applyCarryWeight(player, v)
        end
    end
end

-- Applies spawn conditions: injuries, fractures, and burn severity.
-- conditionTable.injuries  = array of BodyPartType integer IDs to damage directly (legacy path)
-- conditionTable.scratches = array of BodyPartType integer IDs to apply scratched wounds
-- conditionTable.cuts      = array of BodyPartType integer IDs to apply cut wounds
-- conditionTable.deepWounds = array of BodyPartType integer IDs to apply deep wounds
-- conditionTable.fractures = array of BodyPartType integer IDs to fracture (setFractured(true))
-- conditionTable.burnSeverity = 0.0-1.0 float applied to all body parts
function UTCore.applySpawnCondition(player, conditionTable)
    local bodyDamage = player:getBodyDamage()

    if conditionTable.injuries then
        for _, partId in ipairs(conditionTable.injuries) do
            bodyDamage:getBodyPart(partId):setHealth(0.5)
        end
    end

    if conditionTable.scratches then
        for _, partId in ipairs(conditionTable.scratches) do
            bodyDamage:getBodyPart(partId):setScratched(true, true)
        end
    end

    if conditionTable.cuts then
        for _, partId in ipairs(conditionTable.cuts) do
            bodyDamage:getBodyPart(partId):setCut(true, true)
        end
    end

    if conditionTable.deepWounds then
        for _, partId in ipairs(conditionTable.deepWounds) do
            bodyDamage:getBodyPart(partId):setDeepWounded(true)
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

--- stripSpawnItems(player)
-- Clears all worn clothing and inventory items, then creates a fresh key ring.
-- Used by traits that require the player to spawn with nothing.
function UTCore.stripSpawnItems(player)
    player:clearWornItems()
    local inv = player:getInventory()
    if inv then inv:removeAllItems() end
    player:createKeyRing()
end
