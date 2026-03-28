-- UTTestMocks.lua
-- Mock PZ globals for UniversalTraits unit tests.

-- Mock CharacterTrait registry (captures register() calls)
CharacterTrait = {
    _registered = {},
    register = function(id)
        CharacterTrait._registered[id] = true
        return id
    end,
    reset = function()
        CharacterTrait._registered = {}
    end,
}

-- Mock getActivatedMods (returns empty set by default)
_activatedMods = {}
function getActivatedMods()
    return {
        contains = function(_, modId)
            return _activatedMods[modId] == true
        end
    }
end

-- Stub isClient / isServer for registries.lua guard
function isClient() return false end
function isServer() return false end

-- MockPlayer for trait moddata tests
function MockPlayer(traitList)
    local moddata = {}
    local traits = {}
    for _, id in ipairs(traitList or {}) do traits[id] = true end
    return {
        getModData = function(self) return moddata end,
        getTraits  = function(self)
            return { contains = function(_, id) return traits[id] == true end }
        end,
        getStats   = function(self)
            return {
                setStress    = function() end, setHunger  = function() end,
                setThirst    = function() end, setFatigue = function() end,
                setEndurance = function() end, setPanic   = function() end,
                getEndurance    = function() return 1.0 end,
                getMaxEndurance = function() return 1.0 end,
            }
        end,
        getBodyDamage    = function(self) return nil end,
        setMaxWeightBase = function(self, v) moddata["_maxWeight"] = v end,
        getMaxWeightBase = function(self) return moddata["_maxWeight"] or 8 end,
    }
end

-- UTCore stub for trait tests
UTCore = UTCore or {}
UTCore.hasTrait = function(player, traitId)
    if not player then return false end
    return player:getTraits():contains(traitId)
end
UTCore.applySpeedModifier   = function(player, v) player:getModData()["UT_speedMod"] = v end
UTCore.applyWorkSpeed       = function(player, v) player:getModData()["UT_workSpeedMod"] = v end
UTCore.applyBleedRate       = function(player, v) player:getModData()["UT_bleedMult"] = v end
UTCore.applyXPMultiplier    = function(player, perk, v) player:getModData()["UT_xpMult_" .. perk] = v end
UTCore.disableXP            = function(player, perk) player:getModData()["UT_xpDisable_" .. perk] = true end
UTCore.applyCarryWeight     = function(player, v)
    player:setMaxWeightBase(player:getMaxWeightBase() + v)
end
UTCore.applyMoodModifier    = function(player, v) player:getModData()["UT_moodMod"] = v end
UTCore.applySpawnStats      = function(player, t)
    for k, v in pairs(t) do player:getModData()["_spawn_" .. k] = v end
end
UTCore.applyNoiseMod        = function(player, v) player:getModData()["UT_noiseMult"] = v end
UTCore.applySleepQuality    = function(player, v) player:getModData()["UT_sleepQualMod"] = v end
UTCore.applyPanicResistance = function(player, v) player:getModData()["UT_panicResist"] = v end
UTCore.applySpawnCondition  = function(player, t) player:getModData()["_spawnCond"] = t end
UTCore.registerPeriodicHandler = function(traitId, interval, fn) end  -- no-op stub

-- Events.OnNewGame mock
-- PZ trait files call Events.OnNewGame.Add(fn) with dot notation (no self).
-- The mock's Add must accept that: first arg IS the handler function.
if not _G.Events then _G.Events = {} end
if not _G.Events.OnNewGame then
    local _newGameHandlers = {}
    _G.Events.OnNewGame = {
        Add  = function(fn) table.insert(_newGameHandlers, fn) end,
        fire = function(self, player)
            for _, fn in ipairs(_newGameHandlers) do fn(player) end
        end,
    }
end

-- Events.OnPlayerUpdate stub (trait files register update handlers at load time)
-- Called as Events.OnPlayerUpdate.Add(fn) — dot notation, fn is first arg.
if not _G.Events.OnPlayerUpdate then
    _G.Events.OnPlayerUpdate = {
        Add = function(fn) end,  -- no-op: update handlers not tested here
    }
end

-- Events.OnWeaponHitCharacter stub
-- Stores the last registered handler so tests can call it directly.
if not _G.Events.OnWeaponHitCharacter then
    _G.Events.OnWeaponHitCharacter = {
        _handler = nil,
        Add  = function(fn) _G.Events.OnWeaponHitCharacter._handler = fn end,
        fire = function(self, player, weapon, target)
            if self._handler then self._handler(player, weapon, target) end
        end,
    }
end

-- ZombRand stub: deterministic — always returns 0 (triggers any crit check with critchance > 0)
if not _G.ZombRand then
    _G.ZombRand = function(n) return 0 end
end
