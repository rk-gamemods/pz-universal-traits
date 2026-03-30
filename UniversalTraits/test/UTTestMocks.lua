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
    -- Mutable stats object (shared across getStats() calls)
    local stats = {
        _endurance = 1.0,
        _panic     = 0.0,
        setStress    = function() end, setHunger  = function() end,
        setThirst    = function() end, setFatigue = function() end,
        setPanic     = function(self, v) self._panic = v end,
        getPanic     = function(self) return self._panic end,
        setEndurance = function(self, v) self._endurance = v end,
        getEndurance    = function(self) return self._endurance end,
        getMaxEndurance = function(self) return 1.0 end,
    }
    -- Mutable bodyDamage object (shared across getBodyDamage() calls)
    local bodyDamage = {
        _panicLevel      = 0,
        _unhappinessLevel = 50,
        getPanicLevel         = function(self) return self._panicLevel end,
        setPanicLevel         = function(self, v) self._panicLevel = v end,
        getUnhappinessLevel   = function(self) return self._unhappinessLevel end,
        setUnhappinessLevel   = function(self, v) self._unhappinessLevel = v end,
    }
    -- Mutable xp object
    local xp = {
        _log = {},
        AddXP = function(self, perk, amount) table.insert(self._log, { perk=perk, amount=amount }) end,
    }
    local player = {
        _bumpFallDown = false,
        _said         = nil,
        _shouted      = false,
        _sprinting    = false,
        _running      = false,
        _moving       = false,
        _indoors      = false,
        _bumpType     = "",
        _bumpedChr    = nil,
        _bumpFall     = false,
        getModData = function(self) return moddata end,
        getTraits  = function(self)
            return { contains = function(_, id) return traits[id] == true end }
        end,
        getStats      = function(self) return stats end,
        getBodyDamage = function(self) return bodyDamage end,
        getXp         = function(self) return xp end,
        getPerkLevel  = function(self, perk)
            return moddata["_perkLevel_" .. tostring(perk)] or 0
        end,
        setPerkLevel  = function(self, perk, level)
            moddata["_perkLevel_" .. tostring(perk)] = level
        end,
        setMaxWeightBase = function(self, v) moddata["_maxWeight"] = v end,
        getMaxWeightBase = function(self) return moddata["_maxWeight"] or 8 end,
        -- Runtime-behavior mocks
        setBumpFallDown   = function(self, v) self._bumpFallDown = v end,
        isSprinting       = function(self) return self._sprinting end,
        isRunning         = function(self) return self._running end,
        isMoving          = function(self) return self._moving end,
        isIndoors         = function(self) return self._indoors end,
        Say               = function(self, text) self._said = text end,
        ShouldBeShouting  = function(self, v) self._shouted = v end,
        isBumped          = function(self) return self._bumpType ~= "" end,
        getBumpedChr      = function(self) return self._bumpedChr end,
        setBumpedChr      = function(self, chr) self._bumpedChr = chr end,
        setBumpType       = function(self, s) self._bumpType = s end,
        setBumpFall       = function(self, v) self._bumpFall = v end,
    }
    return player
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
UTCore.applyBleedDecayMult  = function(player, mult, bandagedOnly)
    player:getModData()["UT_bleedDecayMult"]        = mult
    player:getModData()["UT_bleedDecayBandagedOnly"] = bandagedOnly and true or false
end
UTCore.applyBleedDrainMult  = function(player, mult) player:getModData()["UT_bleedDrainMult"] = mult end
UTCore.registerPeriodicHandler = function(traitId, interval, fn) end  -- no-op stub

UTCore._zombieCollisionCallbacks = {}
UTCore.registerZombieCollisionHandler = function(traitId, fn)
    UTCore._zombieCollisionCallbacks[traitId] = fn
end
UTCore.unregisterZombieCollisionHandler = function(traitId)
    UTCore._zombieCollisionCallbacks[traitId] = nil
end

-- MockZombie: simulates an IsoZombie for batteringram collision tests
function MockZombie(opts)
    opts = opts or {}
    local _health        = opts.health or 100
    local _knocked       = false
    local knockDownCalls = {}
    return {
        isAlwaysKnockedDown = function(self) return false end,
        knockDown           = function(self, fromBehind)
            _knocked = true
            table.insert(knockDownCalls, fromBehind)
        end,
        isKnockedDown       = function(self) return _knocked end,
        getHealth           = function(self) return _health end,
        setHealth           = function(self, v) _health = v end,
        getKnockDownCalls   = function(self) return knockDownCalls end,
    }
end

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

if not _G.Events.OnCreatePlayer then
    local _createPlayerHandlers = {}
    _G.Events.OnCreatePlayer = {
        Add  = function(fn) table.insert(_createPlayerHandlers, fn) end,
        fire = function(self, playerIndex, player)
            for _, fn in ipairs(_createPlayerHandlers) do fn(playerIndex, player) end
        end,
    }
end

-- Events.OnCreatePlayer stub
-- PZ fires OnCreatePlayer(playerIndex, player) on both new game and save load.
if not _G.Events.OnCreatePlayer then
    local _createPlayerHandlers = {}
    _G.Events.OnCreatePlayer = {
        Add  = function(fn) table.insert(_createPlayerHandlers, fn) end,
        fire = function(self, playerIndex, player)
            for _, fn in ipairs(_createPlayerHandlers) do fn(playerIndex, player) end
        end,
    }
end

-- Events.OnPlayerUpdate stub
-- Stores registered handlers so tests can fire them directly via :fire(player).
if not _G.Events.OnPlayerUpdate then
    local _updateHandlers = {}
    _G.Events.OnPlayerUpdate = {
        Add  = function(fn) table.insert(_updateHandlers, fn) end,
        fire = function(self, player)
            for _, fn in ipairs(_updateHandlers) do fn(player) end
        end,
    }
end

-- Events.OnWeaponHitCharacter stub
-- Stores all registered handlers so tests can fire them via :fire(player, weapon, target).
if not _G.Events.OnWeaponHitCharacter then
    local _weaponHitHandlers = {}
    _G.Events.OnWeaponHitCharacter = {
        Add  = function(fn) table.insert(_weaponHitHandlers, fn) end,
        fire = function(self, player, weapon, target)
            for _, fn in ipairs(_weaponHitHandlers) do fn(player, weapon, target) end
        end,
    }
end

-- ZombRand stub: deterministic — always returns 0 (triggers any crit check with critchance > 0)
if not _G.ZombRand then
    _G.ZombRand = function(n) return 0 end
end

-- Perks stub: provides SmallBlunt and Nimble sentinels
if not _G.Perks then
    _G.Perks = { SmallBlunt = "SmallBlunt", Nimble = "Nimble" }
else
    _G.Perks.Nimble = _G.Perks.Nimble or "Nimble"
end

-- Events.OnPanic stub
if not _G.Events.OnPanic then
    local _panicHandlers = {}
    _G.Events.OnPanic = {
        Add  = function(fn) table.insert(_panicHandlers, fn) end,
        fire = function(self, player)
            for _, fn in ipairs(_panicHandlers) do fn(player) end
        end,
    }
end

-- Events.EveryOneMinute stub
-- UTCore_ZombieCollisionHook registers an integrity check on this event.
if not _G.Events.EveryOneMinute then
    local _everyOneMinuteHandlers = {}
    _G.Events.EveryOneMinute = {
        Add  = function(fn) table.insert(_everyOneMinuteHandlers, fn) end,
        fire = function(self)
            for _, fn in ipairs(_everyOneMinuteHandlers) do fn() end
        end,
    }
end
