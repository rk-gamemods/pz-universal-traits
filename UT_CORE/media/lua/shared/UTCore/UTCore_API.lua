-- UTCore_API.lua
-- Public API for Universal Traits shared infrastructure.
-- Phase 1 stub: only hasTrait wrapper implemented. Full API added in Phase 2.

UTCore = UTCore or {}

-- Cache CharacterTrait objects by string ID to avoid repeated registry lookups.
local _traitCache = {}

local function recordSmoke(scenarioId, detail)
    if UTSmoke and UTSmoke.record then
        UTSmoke.record(scenarioId, detail)
    end
end

--- Nil-safe hasTrait check (B42.16+ registry API).
-- @param player IsoPlayer
-- @param traitId string  full namespaced ID e.g. "UniversalTraits:UT_swift"
-- @return boolean
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    if not instanceof(player, "IsoGameCharacter") then return false end
    recordSmoke("player.core-runtime", traitId)
    local ct = _traitCache[traitId]
    if ct == nil then
        ct = CharacterTrait.get(ResourceLocation.of(traitId))
        if ct then _traitCache[traitId] = ct end
    end
    if not ct then return false end
    return player:hasTrait(ct)
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
