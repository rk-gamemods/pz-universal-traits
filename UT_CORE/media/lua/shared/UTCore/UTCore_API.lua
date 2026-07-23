-- UTCore_API.lua
-- Public API for Universal Traits shared infrastructure.

UTCore = UTCore or {}

---------------------------------------------------------------------
-- Core handler infrastructure (Phase 1 perf: unified dispatch)
--
-- Core handlers are UT_CORE's own OnPlayerUpdate hooks (bleed, pain,
-- freeze detection, stat reconciliation, etc.) that previously each
-- registered a separate Events.OnPlayerUpdate handler with redundant
-- Java interop calls. Moving them into the central dispatch loop
-- eliminates those redundant calls and gives them the shared tick
-- context for free.
--
-- Defined here (UTCore_API) because PZ loads files alphabetically
-- and hooks (B*, D*, F*, ...) load before TickDispatch (T*).
---------------------------------------------------------------------
UTCore._coreHandlers = UTCore._coreHandlers or {}
UTCore._coreHandlerCount = UTCore._coreHandlerCount or 0
UTCore._coreHandlersDirty = UTCore._coreHandlersDirty ~= false

local function validateCoreHandler(id, fn, opts)
    if type(id) ~= "string" or id == "" then
        error("core handler id must be a non-empty string", 3)
    end
    if type(fn) ~= "function" then
        error("core handler fn must be a function", 3)
    end
    if opts ~= nil and type(opts) ~= "table" then
        error("core handler opts must be a table or nil", 3)
    end

    opts = opts or {}
    local throttle = opts.throttle
    if throttle == nil then throttle = 0 end
    if type(throttle) ~= "number"
        or throttle ~= throttle
        or throttle == math.huge
        or throttle == -math.huge
        or throttle < 0
        or throttle % 1 ~= 0 then
        error("core handler throttle must be a non-negative finite integer", 3)
    end

    local priority = opts.priority
    if priority == nil then priority = 0 end
    if type(priority) ~= "number"
        or priority ~= priority
        or priority == math.huge
        or priority == -math.huge then
        error("core handler priority must be a finite number", 3)
    end

    return throttle, priority
end

--- Register a core infrastructure handler that runs every tick inside
--- the central dispatch, BEFORE trait handlers.
--- @param id   string  identifier for diagnostics
--- @param fn   function(player, tick)  the handler
--- @param opts table   optional:
---   throttle = N     run every Nth tick (0 = every tick, default)
---   priority = N     higher runs first (default 0)
function UTCore.registerCoreHandler(id, fn, opts)
    local throttle, priority = validateCoreHandler(id, fn, opts)
    local handlers = UTCore._coreHandlers
    local count = UTCore._coreHandlerCount
    local kept = {}
    local keptCount = 0
    local replacement = nil

    for i = 1, count do
        local handler = handlers[i]
        if handler.id == id then
            if replacement == nil then
                replacement = handler
                replacement.fn = fn
                replacement.throttle = throttle
                replacement.priority = priority
                keptCount = keptCount + 1
                kept[keptCount] = replacement
            end
        else
            keptCount = keptCount + 1
            kept[keptCount] = handler
        end
    end

    if replacement == nil then
        keptCount = keptCount + 1
        kept[keptCount] = {
            id       = id,
            fn       = fn,
            throttle = throttle,
            priority = priority,
        }
    end

    UTCore._coreHandlers = kept
    UTCore._coreHandlerCount = keptCount
    UTCore._coreHandlersDirty = true
end

--- Return core handler count (testing/diagnostics).
function UTCore.getCoreHandlerCount()
    return UTCore._coreHandlerCount
end

---------------------------------------------------------------------------
-- Diagnostic / profiling subsystem toggles.
-- Set to true to re-enable without code changes; false = disabled at load.
---------------------------------------------------------------------------
UTCore.FREEZE_LOGGER_ENABLED = false    -- per-tick freeze detection (FreezeLogger)
UTCore.MET_DEBUG_ENABLED     = false    -- character-creation MET null-guard + audit

--- Dispatch safety mode: when true, pcall wraps every handler call so a
--- single handler error cannot propagate and break OnPlayerUpdate or PZ's
--- action queue.  The pcall overhead is negligible (~2 µs/call) and the
--- old pre-optimization dispatch ALWAYS used pcall for trait handlers.
--- Keeping this true matches that proven-safe behaviour.
UTCore._debugDispatch = true

function UTCore.setDebugDispatch(enabled)
    UTCore._debugDispatch = enabled ~= false
end

-- Cache CharacterTrait objects by string ID to avoid repeated registry lookups.
local _traitCache = {}
local _recordedTraitSmoke = {}
local _traitRegistryAvailable = true

local function isValidTraitId(traitId)
    if type(traitId) ~= "string" or traitId == "" then return false end
    return string.match(traitId, "^[%w_.-]+:[%w_./-]+$") ~= nil
end

local function recordSmoke(scenarioId, detail)
    if UTSmoke and UTSmoke.record then
        UTSmoke.record(scenarioId, detail)
    end
end

--- Compatibility invalidation boundary for the former per-player result cache.
-- Membership results are read from the player on every hasTrait call, so no
-- stale per-player result remains to clear.
function UTCore.invalidateTraitCache()
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
-- CharacterTrait registry lookups are cached, but the membership result is read
-- from the player every call so dynamic/admin add and remove operations are
-- visible immediately.
-- @param player IsoPlayer
-- @param traitId string  full namespaced ID e.g. "UniversalTraits:UT_swift"
-- @return boolean
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    if not isValidTraitId(traitId) then return false end
    if type(instanceof) ~= "function" then return false end
    if not instanceof(player, "IsoGameCharacter") then return false end
    if type(player.hasTrait) ~= "function" then return false end

    if not _recordedTraitSmoke[traitId] then
        recordSmoke("player.core-runtime", traitId)
        _recordedTraitSmoke[traitId] = true
    end
    local ct = _traitCache[traitId]
    if ct == nil then
        if not _traitRegistryAvailable then return false end
        local ok, registryReady
        ok, ct, registryReady = pcall(function()
            if ResourceLocation == nil or type(ResourceLocation.of) ~= "function" then return nil, false end
            if CharacterTrait == nil or type(CharacterTrait.get) ~= "function" then return nil, false end
            return CharacterTrait.get(ResourceLocation.of(traitId)), true
        end)
        if not ok or not registryReady then
            _traitRegistryAvailable = false
            return false
        end
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

    local printable
    local printableOk, printableValue = pcall(function()
        return tostring(trait)
    end)
    if printableOk and printableValue then
        printable = printableValue
        if printable:match("^[%w_.%-]+:[%w_./%-]+$") then
            return printable
        end
    end

    local name = safeCall(trait, "getName")
    if name and name ~= "" then
        local nameOk, nameValue = pcall(function()
            return tostring(name)
        end)
        if nameOk and nameValue then
            return nameValue
        end
    end

    if printable then return printable end
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
