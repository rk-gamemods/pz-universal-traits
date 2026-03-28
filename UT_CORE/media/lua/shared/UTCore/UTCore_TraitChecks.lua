-- UTCore_TraitChecks.lua
-- hasTrait convenience wrappers.

UTCore = UTCore or {}

--- Check if player has any trait from a set (for tier series).
-- @param player IsoPlayer
-- @param traitIds table  array of namespaced trait ID strings
-- @return boolean
function UTCore.hasAnyTrait(player, traitIds)
    if not player then return false end
    for _, id in ipairs(traitIds) do
        if UTCore.hasTrait(player, id) then return true end
    end
    return false
end

--- Safe ModData read with UT_ key prefix.
-- @param player IsoPlayer
-- @param key string
-- @param default any
-- @return any
function UTCore.getModData(player, key, default)
    if not player then return default end
    local data = player:getModData()
    local val = data["UT_" .. key]
    if val == nil then return default end
    return val
end

--- Safe ModData write with UT_ key prefix.
-- @param player IsoPlayer
-- @param key string
-- @param value any
function UTCore.setModData(player, key, value)
    if not player then return end
    player:getModData()["UT_" .. key] = value
end
