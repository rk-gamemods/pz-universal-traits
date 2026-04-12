-- UTCore_API.lua
-- Public API for Universal Traits shared infrastructure.
-- Phase 1 stub: only hasTrait wrapper implemented. Full API added in Phase 2.

UTCore = UTCore or {}

-- Cache CharacterTrait objects by string ID to avoid repeated registry lookups.
local _traitCache = {}

-- Session-level result cache: traits are fixed at character creation in PZ,
-- so the result of player:hasTrait() is stable for the entire session.
-- This eliminates ~1,300+ Java interop calls/sec from the negative-path
-- (handlers for traits the player doesn't have).
local _cachedPlayer = nil
local _playerTraitResults = {}

local function recordSmoke(scenarioId, detail)
    if UTSmoke and UTSmoke.record then
        UTSmoke.record(scenarioId, detail)
    end
end

--- Invalidate the per-session hasTrait result cache.
-- Call if traits are dynamically added/removed (not normal in vanilla PZ).
function UTCore.invalidateTraitCache()
    _cachedPlayer = nil
    _playerTraitResults = {}
end

--- Context guard for OnPlayerUpdate handlers.
-- Returns true if the player is in a state where tick handlers should be skipped:
--   1. Player is nil
--   2. Player is dead
--   3. Player is in a vehicle (driving or passenger)
-- Most traits and combat hooks are irrelevant while driving/dead.
-- Vehicle-specific traits (vehophobic, motionsickness) should NOT call this.
-- Cost: 2 Java field reads, cached per player within a tick batch.
-- @param player IsoPlayer
-- @return boolean true = skip this tick, false = process normally
function UTCore.shouldSkipTick(player)
    if not player then return true end
    if player:isDead() then return true end
    if player:getVehicle() ~= nil then return true end
    return false
end

--- Nil-safe hasTrait check (B42.16+ registry API).
-- Results are cached for the session since traits don't change during gameplay.
-- @param player IsoPlayer
-- @param traitId string  full namespaced ID e.g. "UniversalTraits:UT_swift"
-- @return boolean
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    if not instanceof(player, "IsoGameCharacter") then return false end

    -- Invalidate cache if player identity changed (new game / load / tests)
    if player ~= _cachedPlayer then
        _playerTraitResults = {}
        _cachedPlayer = player
    end

    -- Fast path: return cached result (Lua table lookup, no Java interop)
    local cached = _playerTraitResults[traitId]
    if cached ~= nil then return cached end

    recordSmoke("player.core-runtime", traitId)
    local ct = _traitCache[traitId]
    if ct == nil then
        ct = CharacterTrait.get(ResourceLocation.of(traitId))
        if ct then _traitCache[traitId] = ct end
    end
    if not ct then
        _playerTraitResults[traitId] = false
        return false
    end
    local result = player:hasTrait(ct)
    _playerTraitResults[traitId] = result
    return result
end

function UTCore.weaponHasCategory(weapon, category)
    if not weapon or not category then return false end
    if type(weapon.isOfWeaponCategory) ~= "function" then return false end

    local ok, result = pcall(function()
        return weapon:isOfWeaponCategory(category)
    end)

    return ok and result == true
end

local function safeCall(target, methodName)
    if not target or type(target[methodName]) ~= "function" then return nil end
    local ok, value = pcall(function()
        return target[methodName](target)
    end)
    if ok then return value end
    return nil
end

function UTCore.getCharacterTraitId(trait)
    if trait == nil then return "<nil>" end
    if type(trait) == "string" then return trait end

    local name = safeCall(trait, "getName")
    if name and name ~= "" then
        return tostring(name)
    end

    local ok, value = pcall(function()
        return tostring(trait)
    end)
    if ok and value then
        return value
    end

    return "<unprintable>"
end

function UTCore.getTraitDefinitionId(traitDefinition)
    if traitDefinition == nil then return "<nil>" end
    local trait = safeCall(traitDefinition, "getType")
    if trait ~= nil then
        return UTCore.getCharacterTraitId(trait)
    end
    return UTCore.getCharacterTraitId(traitDefinition)
end

function UTCore.logCharacterCreationMetNull(traitDefinition, exclusiveTrait, index, isRemovingTrait)
    local selectedId = UTCore.getTraitDefinitionId(traitDefinition)
    local selectedLabel = safeCall(traitDefinition, "getLabel") or "<no-label>"
    local entries = {}
    local mutexList = safeCall(traitDefinition, "getMutuallyExclusiveTraits")

    if mutexList and type(mutexList.size) == "function" and type(mutexList.get) == "function" then
        for listIndex = 0, mutexList:size() - 1 do
            entries[#entries + 1] = UTCore.getCharacterTraitId(mutexList:get(listIndex))
        end
    end

    print(string.format(
        "[UT_MET_DEBUG] selected=%s label=%s removing=%s nil_index=%d exclusive=%s mutex_list=[%s]",
        selectedId,
        tostring(selectedLabel),
        tostring(isRemovingTrait),
        index,
        UTCore.getCharacterTraitId(exclusiveTrait),
        table.concat(entries, ", ")
    ))
end
