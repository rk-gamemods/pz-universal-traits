-- UTCore_API.lua
-- Public API for Universal Traits shared infrastructure.
-- Phase 1 stub: only hasTrait wrapper implemented. Full API added in Phase 2.

UTCore = UTCore or {}

--- Nil-safe hasTrait check.
-- @param player IsoPlayer
-- @param traitId string  full namespaced ID e.g. "UniversalTraits:UT_swift"
-- @return boolean
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
