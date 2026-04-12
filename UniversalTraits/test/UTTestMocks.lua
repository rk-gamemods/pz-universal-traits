-- UTTestMocks.lua
-- Mock PZ globals for UniversalTraits unit tests.

-- ============================================================
-- Timing mock
-- ============================================================

-- Mock getTimestampMs: returns milliseconds (controllable from tests)
_mockTimestampMs = 0
function getTimestampMs()
    return _mockTimestampMs
end
function setMockTimestampMs(ms)
    _mockTimestampMs = ms
end
function advanceMockTimestampMs(delta)
    _mockTimestampMs = _mockTimestampMs + (delta or 1)
end

-- ============================================================
-- B42.16 Registry API mocks
-- ============================================================

-- instanceof: PZ global that checks Java class hierarchy.
-- In tests, MockPlayer objects are tagged with _mockType = "IsoGameCharacter".
function instanceof(obj, className)
    if obj == nil then return false end
    if type(obj) ~= "table" then return false end
    if obj._mockType == className then return true end
    -- IsoPlayer is-a IsoGameCharacter
    if className == "IsoGameCharacter" and obj._mockType == "IsoPlayer" then return true end
    -- IsoZombie is-a IsoGameCharacter
    if className == "IsoGameCharacter" and obj._mockType == "IsoZombie" then return true end
    return false
end

-- ResourceLocation mock: mirrors PZ's ResourceLocation.of("namespace:path").
ResourceLocation = {
    of = function(id)
        if not id or id == "" then error("Identifier cannot be null or empty") end
        local ns, path = id:match("^([^:]+):(.+)$")
        if not ns then ns = "base"; path = id end
        return { _ns = ns:lower(), _path = path:lower(), toString = function(self) return self._ns .. ":" .. self._path end }
    end,
}

-- Mock CharacterTrait registry (captures register() calls)
-- B42.16: register() returns an object; get() looks it up by ResourceLocation.
CharacterTrait = {
    _registered = {},
    _byKey = {},
    register = function(id)
        CharacterTrait._registered[id] = true
        local rl = ResourceLocation.of(id)
        local key = rl._ns .. ":" .. rl._path
        local ct = { _id = id, _key = key }
        CharacterTrait._byKey[key] = ct
        return ct
    end,
    get = function(rl)
        if not rl then return nil end
        local key = rl._ns .. ":" .. rl._path
        return CharacterTrait._byKey[key]
    end,
    reset = function()
        CharacterTrait._registered = {}
        CharacterTrait._byKey = {}
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

local function makeStats(opts)
    -- B42.16: only generic get/set/add/remove via CharacterStat keys
    local data = {
        [CharacterStat.ENDURANCE]        = opts.endurance or 1.0,
        [CharacterStat.PANIC]            = opts.panic or 0.0,
        [CharacterStat.STRESS]           = opts.stress or 0.0,
        [CharacterStat.HUNGER]           = opts.hunger or 0.0,
        [CharacterStat.THIRST]           = opts.thirst or 0.0,
        [CharacterStat.FATIGUE]          = opts.fatigue or 0.0,
        [CharacterStat.BOREDOM]          = opts.boredom or 0.0,
        [CharacterStat.PAIN]             = opts.pain or 0.0,
        [CharacterStat.INTOXICATION]     = opts.intoxication or opts.drunkenness or 0.0,
        [CharacterStat.UNHAPPINESS]      = opts.unhappiness or 0.0,
        [CharacterStat.WETNESS]          = opts.wetness or 0.0,
        [CharacterStat.ZOMBIE_INFECTION] = opts.zombieInfection or 0.0,
        [CharacterStat.ZOMBIE_FEVER]     = opts.zombieFever or 0.0,
        [CharacterStat.FOOD_SICKNESS]    = opts.foodSickness or 0.0,
        [CharacterStat.TEMPERATURE]      = opts.bodyTemp or 37.0,
    }
    local charStatAccum = {}
    return {
        _charStatAccum = charStatAccum,
        get = function(self, stat)
            return data[stat] or 0
        end,
        set = function(self, stat, v)
            data[stat] = v
        end,
        add = function(self, stat, delta)
            data[stat] = (data[stat] or 0) + delta
            charStatAccum[stat] = (charStatAccum[stat] or 0) + delta
        end,
        remove = function(self, stat, delta)
            data[stat] = (data[stat] or 0) - delta
            charStatAccum[stat] = (charStatAccum[stat] or 0) - delta
        end,
    }
end

local function makeBodyDamage(opts, statsRef)
    return {
        -- B42.16: getPanicReductionValue/setPanicReductionValue still on BodyDamage
        _panicReductionValue   = opts.panicReductionValue or 0.06,
        getPanicReductionValue = function(self) return self._panicReductionValue end,
        setPanicReductionValue = function(self, v) self._panicReductionValue = v end,
        -- B42.16: getApparentInfectionLevel = max(ZOMBIE_FEVER, ZOMBIE_INFECTION, FOOD_SICKNESS)
        getApparentInfectionLevel = function(self)
            if statsRef then
                local zi = statsRef:get(CharacterStat.ZOMBIE_INFECTION) or 0
                local zf = statsRef:get(CharacterStat.ZOMBIE_FEVER) or 0
                local fs = statsRef:get(CharacterStat.FOOD_SICKNESS) or 0
                return math.max(zi, zf, fs)
            end
            return 0
        end,
        _healthFromFoodTimer   = opts.healthFromFoodTimer or 0,
        getHealthFromFoodTimer = function(self) return self._healthFromFoodTimer end,
        setHealthFromFoodTimer = function(self, v) self._healthFromFoodTimer = v end,
        _bodyParts             = {},
        getBodyPart            = function(self, partType)
            local key = tostring(partType)
            if not self._bodyParts[key] then
                self._bodyParts[key] = {
                    _pain = 0,
                    getAdditionalPain = function(s) return s._pain end,
                    setAdditionalPain = function(s, v) s._pain = v end,
                }
            end
            return self._bodyParts[key]
        end,
    }
end

local function makeNutrition(opts)
    return {
        _weight = opts.weight or 80.0,
        _calories = opts.calories or 2000.0,
        getWeight = function(self) return self._weight end,
        setWeight = function(self, v) self._weight = v end,
        getCalories = function(self) return self._calories end,
        setCalories = function(self, v) self._calories = v end,
    }
end

local function makeIndexedList(entries)
    return {
        size = function(self) return #entries end,
        get = function(self, index) return entries[index + 1] end,
        contains = function(self, value)
            for _, entry in ipairs(entries) do
                if entry == value then return true end
            end
            return false
        end,
        isEmpty = function(self) return #entries == 0 end,
    }
end

function MockVehicle(opts)
    opts = opts or {}
    local moddata = opts.moddata or {}
    return {
        _maxSpeed = opts.maxSpeed or 100,
        _brakingForce = opts.brakingForce or 10,
        _engineQuality = opts.engineQuality or 100,
        _engineLoudness = opts.engineLoudness or 100,
        _enginePower = opts.enginePower or 100,
        _mass = opts.mass or 1000,
        _initialMass = opts.initialMass or (opts.mass or 1000),
        _updateTotalMassCalls = 0,
        getModData = function(self) return moddata end,
        getMaxSpeed = function(self) return self._maxSpeed end,
        setMaxSpeed = function(self, v) self._maxSpeed = v end,
        getBrakingForce = function(self) return self._brakingForce end,
        setBrakingForce = function(self, v) self._brakingForce = v end,
        getEngineQuality = function(self) return self._engineQuality end,
        getEngineLoudness = function(self) return self._engineLoudness end,
        getEnginePower = function(self) return self._enginePower end,
        setEngineFeature = function(self, quality, loudness, power)
            self._engineQuality = quality
            self._engineLoudness = loudness
            self._enginePower = power
        end,
        getMass = function(self) return self._mass end,
        setMass = function(self, v) self._mass = v end,
        getInitialMass = function(self) return self._initialMass end,
        setInitialMass = function(self, v) self._initialMass = v end,
        updateTotalMass = function(self) self._updateTotalMassCalls = self._updateTotalMassCalls + 1 end,
    }
end

-- MockPlayer for trait moddata tests
function MockPlayer(traitList, opts)
    opts = opts or {}
    local moddata = opts.moddata or {}
    local traits = {}
    for _, id in ipairs(traitList or {}) do traits[id] = true end
    -- B42.16: register trait objects so CharacterTrait.get() can resolve them
    for _, id in ipairs(traitList or {}) do
        local rl = ResourceLocation.of(id)
        local key = rl._ns .. ":" .. rl._path
        if not CharacterTrait._byKey[key] then
            CharacterTrait.register(id)
        end
    end
    local stats = opts.stats or makeStats(opts)
    local bodyDamage = opts.bodyDamage or makeBodyDamage(opts, stats)
    local nutrition = opts.nutrition or makeNutrition(opts)
    local x = opts.x or 0
    local y = opts.y or 0
    local primaryHandItem   = opts.primaryHandItem or nil
    local secondaryHandItem  = opts.secondaryHandItem or nil
    local wornItems          = opts.wornItems or nil  -- MockWornItems object or nil
    local inventory          = opts.inventory or nil  -- MockInventory object or nil
    local square             = opts.square or nil    -- mock square object or nil
    local variables          = {}                     -- generic animation variables store
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
        _driving      = opts.driving == nil and opts.vehicle ~= nil or opts.driving,
        _playerNum    = opts.playerNum or 0,
        _vehicle      = opts.vehicle,
        getModData = function(self) return moddata end,
        -- B42.16 hasTrait(CharacterTrait): takes a CharacterTrait object, not a string
        hasTrait = function(self, ct)
            if not ct then return false end
            return traits[ct._id] == true
        end,
        -- Legacy getTraits for backward compat with any remaining string-based checks
        getTraits  = function(self)
            return { contains = function(_, id) return traits[id] == true end }
        end,
        getCharacterTraits = function(self)
            local knownList = {}
            for id, _ in pairs(traits) do
                local rl = ResourceLocation.of(id)
                local ct = CharacterTrait._byKey[rl._ns .. ":" .. rl._path]
                if ct then knownList[#knownList + 1] = ct end
            end
            return {
                getKnownTraits = function() return { size = function() return #knownList end, get = function(_, i) return knownList[i + 1] end } end,
                add = function(_, ct) if ct and ct._id then traits[ct._id] = true end end,
                remove = function(_, ct) if ct and ct._id then traits[ct._id] = nil end end,
            }
        end,
        _mockType = "IsoPlayer",
        getStats      = function(self) return stats end,
        getBodyDamage = function(self) return bodyDamage end,
        setBodyDamage = function(self, value) bodyDamage = value end,
        getXp         = function(self) return xp end,
        getXpCalls    = function(self) return xp._log end,
        getPerkLevel  = function(self, perk)
            return moddata["_perkLevel_" .. tostring(perk)] or 0
        end,
        setPerkLevel  = function(self, perk, level)
            moddata["_perkLevel_" .. tostring(perk)] = level
        end,
        setMaxWeightBase = function(self, v) moddata["_maxWeight"] = v end,
        getMaxWeightBase = function(self) return moddata["_maxWeight"] or 8 end,
        getX = function(self) return x end,
        getY = function(self) return y end,
        setX = function(self, v) x = v end,
        setY = function(self, v) y = v end,
        moveTo = function(self, nx, ny) x = nx; y = ny end,
        isLocalPlayer = function(self) return true end,
        getNutrition = function(self) return nutrition end,
        getPlayerNum = function(self) return self._playerNum end,
        isDriving = function(self) return self._driving end,
        getVehicle = function(self) return self._vehicle end,
        setVehicle = function(self, vehicle)
            self._vehicle = vehicle
            self._driving = vehicle ~= nil
        end,
        getPrimaryHandItem   = function(self) return primaryHandItem end,
        setPrimaryHandItem   = function(self, item) primaryHandItem = item end,
        getSecondaryHandItem = function(self) return secondaryHandItem end,
        setSecondaryHandItem = function(self, item) secondaryHandItem = item end,
        getWornItems         = function(self) return wornItems end,
        getInventory         = function(self) return inventory end,
        getCurrentSquare     = function(self) return square end,
        removeFromHands      = function(self, _item)
            primaryHandItem   = nil
            secondaryHandItem = nil
        end,
        setMeleeDelay = function(self, v) moddata["_lastMeleeDelay"] = v end,
        -- Runtime-behavior mocks
        setBumpFallDown   = function(self, v) self._bumpFallDown = v end,
        isSprinting       = function(self) return self._sprinting end,
        isRunning         = function(self) return self._running end,
        setSprinting      = function(self, v) self._sprinting = v end,
        setRunning        = function(self, v) self._running = v end,
        isMoving          = function(self) return self._moving end,
        isIndoors         = function(self) return self._indoors end,
        Say               = function(self, text) self._said = text end,
        ShouldBeShouting  = function(self, v) self._shouted = v end,
        isBumped          = function(self) return self._bumpType ~= "" end,
        getBumpedChr      = function(self) return self._bumpedChr end,
        setBumpedChr      = function(self, chr) self._bumpedChr = chr end,
        setBumpType       = function(self, s) self._bumpType = s end,
        setBumpFall          = function(self, v) self._bumpFall = v end,
        _blockMovement       = false,
        setBlockMovement     = function(self, v) self._blockMovement = v end,
        getBlockMovement     = function(self) return self._blockMovement end,
        _bumpDone            = false,
        setBumpDone          = function(self, v) self._bumpDone = v end,
        isBumpDone           = function(self) return self._bumpDone end,
        -- Generic animation variable store (setVariable/getVariable/clearVariable)
        setVariable          = function(self, key, val)
            variables[key] = tostring(val)
        end,
        getVariable          = function(self, key) return variables[key] end,
        getVariableBoolean   = function(self, key)
            return variables[key] == "true"
        end,
        clearVariable        = function(self, key) variables[key] = nil end,
        _variables           = variables,  -- expose for test assertions
        _z                   = opts.z or 0,
        getZ                 = function(self) return self._z end,
        setZ                 = function(self, v) self._z = v end,
        _bodyTemp            = opts.bodyTemp or 37.0,
        getBodyTemperature   = function(self) return self._bodyTemp end,
        setBodyTemperature   = function(self, v) self._bodyTemp = v end,
        _sleeping            = opts.sleeping or false,
        isSleeping           = function(self) return self._sleeping end,
        setSleeping          = function(self, v) self._sleeping = v end,
        isAsleep             = function(self) return self._sleeping end,
        setAsleep            = function(self, v) self._sleeping = v end,
        _backpack            = opts.backpack or nil,
        getClothingItem_Back = function(self) return self._backpack end,
        isOutside            = function(self) return not self._indoors end,
        _falling             = opts.falling or false,
        isFalling            = function(self) return self._falling end,
        setFalling           = function(self, v) self._falling = v end,
        setbFalling          = function(self, v) self._falling = v end,
        _currentActionState  = opts.currentActionState or "idle",
        getCurrentActionContextStateName = function(self) return self._currentActionState end,
        -- Public field: runningTime (IsoPlayer line 347)
        -- Used by separate() for bump threshold check (runningTime > 0.5)
        runningTime = opts.runningTime or 1.0,
        _dead = opts.dead or false,
        isDead = function(self) return self._dead end,
    }
    return player
end

-- UTCore stub for trait tests
UTCore = UTCore or {}

-- Central context guard: skip tick for nil, dead, or in-vehicle players.
-- Mirrors UTCore_API.lua; simplified for test harness.
UTCore.shouldSkipTick = function(player)
    if not player then return true end
    if player.isDead and player:isDead() then return true end
    if player.getVehicle and player:getVehicle() ~= nil then return true end
    return false
end

local function ensureModifierBuckets(player)
    local md = player:getModData()
    local buckets = md["UT_modifierBuckets"]
    if type(buckets) ~= "table" then
        buckets = {}
        md["UT_modifierBuckets"] = buckets
    end
    if type(buckets.speedAdd) ~= "table" then buckets.speedAdd = {} end
    if type(buckets.workAdd) ~= "table" then buckets.workAdd = {} end
    if type(buckets.transferMult) ~= "table" then buckets.transferMult = {} end
    if type(buckets.carryFlatAdd) ~= "table" then buckets.carryFlatAdd = {} end
    if type(buckets.carryStrengthAdd) ~= "table" then buckets.carryStrengthAdd = {} end
    return md, buckets
end

local function sumBucket(bucket)
    local total = 0
    for _, value in pairs(bucket) do
        if type(value) == "number" then
            total = total + value
        end
    end
    return total
end

local function productBucket(bucket)
    local total = 1.0
    for _, value in pairs(bucket) do
        if type(value) == "number" then
            total = total * value
        end
    end
    return total
end

local function hasEntries(bucket)
    for _ in pairs(bucket) do
        return true
    end
    return false
end

function UTCore.refreshAggregatedModifierCache(player)
    local md, buckets = ensureModifierBuckets(player)
    md["UT_speedMod"] = sumBucket(buckets.speedAdd)
    md["UT_workSpeedMod"] = sumBucket(buckets.workAdd)
    md["UT_transferSpeedMult"] = productBucket(buckets.transferMult)
    md["UT_carryFlatMod"] = sumBucket(buckets.carryFlatAdd)
    md["UT_carryStrengthBonus"] = sumBucket(buckets.carryStrengthAdd)
    return md
end

function UTCore.reconcileAggregatedModifiers(player)
    local md, buckets = ensureModifierBuckets(player)
    UTCore.refreshAggregatedModifierCache(player)

    local carryFlat = md["UT_carryFlatMod"] or 0
    local carryStrengthBonus = md["UT_carryStrengthBonus"] or 0
    if hasEntries(buckets.carryStrengthAdd) or carryFlat ~= 0 then
        local strength = player:getPerkLevel(Perks.Strength)
        local base = hasEntries(buckets.carryStrengthAdd) and (5 + strength) or 8
        player:setMaxWeightBase(base + carryStrengthBonus + carryFlat)
    end
end

UTCore.hasTrait = function(player, traitId)
    if not player then return false end
    return player:getTraits():contains(traitId)
end
UTCore.weaponHasCategory = function(weapon, category)
    if not weapon or not category or type(weapon.isOfWeaponCategory) ~= "function" then return false end
    return weapon:isOfWeaponCategory(category)
end
UTCore.applySpeedModifier   = function(player, v, sourceId)
    local _, buckets = ensureModifierBuckets(player)
    buckets.speedAdd[sourceId or "__anonymous"] = v
    UTCore.refreshAggregatedModifierCache(player)
end
UTCore.applyWorkSpeed       = function(player, v, sourceId)
    local _, buckets = ensureModifierBuckets(player)
    buckets.workAdd[sourceId or "__anonymous"] = v
    UTCore.refreshAggregatedModifierCache(player)
end
UTCore.applyTransferSpeedMultiplier = function(player, v, sourceId)
    local _, buckets = ensureModifierBuckets(player)
    buckets.transferMult[sourceId or "__anonymous"] = v
    UTCore.refreshAggregatedModifierCache(player)
end
UTCore.applyBleedRate       = function(player, v) player:getModData()["UT_bleedMult"] = v end
UTCore.applyXPMultiplier    = function(player, perk, v) player:getModData()["UT_xpMult_" .. perk] = v end
UTCore.disableXP            = function(player, perk) player:getModData()["UT_xpDisable_" .. perk] = true end
UTCore.applyCarryWeight     = function(player, v, sourceId)
    local _, buckets = ensureModifierBuckets(player)
    buckets.carryFlatAdd[sourceId or "__anonymous"] = v
    UTCore.reconcileAggregatedModifiers(player)
end
UTCore.applyStrengthCarryWeight = function(player, bonus, sourceId)
    local _, buckets = ensureModifierBuckets(player)
    buckets.carryStrengthAdd[sourceId or "__anonymous"] = bonus
    UTCore.reconcileAggregatedModifiers(player)
end
UTCore.applyMoodModifier    = function(player, v) player:getModData()["UT_moodMod"] = v end
UTCore.applySpawnStats      = function(player, t)
    for k, v in pairs(t) do player:getModData()["_spawn_" .. k] = v end
end
UTCore.applyNoiseMod        = function(player, v) player:getModData()["UT_noiseMult"] = v end
UTCore.applySleepQuality    = function(player, v) player:getModData()["UT_sleepQualMod"] = v end
UTCore.applyPanicResistance = function(player, v) player:getModData()["UT_panicResist"] = v end
UTCore.applyWetnessReductionProfile = function(player, indoor, outdoor, rain)
    local md = player:getModData()
    md["UT_wetnessReductionIndoor"] = indoor
    md["UT_wetnessReductionOutdoor"] = outdoor
    md["UT_wetnessReductionRain"] = rain
end
UTCore.applyThermalRegulationProfile = function(player, comfortFloor, warmThreshold, hotThreshold, warmCooling, hotCooling)
    local md = player:getModData()
    md["UT_thermalComfortFloor"] = comfortFloor
    md["UT_thermalWarmThreshold"] = warmThreshold
    md["UT_thermalHotThreshold"] = hotThreshold
    md["UT_thermalWarmCooling"] = warmCooling
    md["UT_thermalHotCooling"] = hotCooling
end
UTCore.getModData = function(player, key, default)
    local value = player:getModData()[key]
    if value == nil then return default end
    return value
end
UTCore.setModData = function(player, key, value)
    player:getModData()[key] = value
end
UTCore.applySpawnCondition  = function(player, t) player:getModData()["_spawnCond"] = t end
UTCore.applyBleedDecayMult  = function(player, mult, bandagedOnly)
    player:getModData()["UT_bleedDecayMult"]        = mult
    player:getModData()["UT_bleedDecayBandagedOnly"] = bandagedOnly and true or false
end
UTCore.applyBleedDrainMult  = function(player, mult) player:getModData()["UT_bleedDrainMult"] = mult end
UTCore.stripSpawnItems      = UTCore.stripSpawnItems or function(player)
    player:getModData()["_stripCalled"] = true
end
UTCore.applyStatFloor       = UTCore.applyStatFloor or function(player, key, floor)
    local name = (type(key) == "table" and key._name) or tostring(key)
    player:getModData()["UT_statFloor_" .. name] = floor
end
UTCore._periodicHandlers = UTCore._periodicHandlers or {}
UTCore._vehicleTraitDefs = UTCore._vehicleTraitDefs or {}
local function periodicHandlerKey(traitId, interval)
    return traitId .. "::" .. interval
end
UTCore.registerPeriodicHandler = function(traitId, interval, fn)
    local key = periodicHandlerKey(traitId, interval)
    if UTCore._periodicHandlers[key] then return end
    local wrapped = function()
        if getPlayer then
            fn(getPlayer())
        end
    end
    UTCore._periodicHandlers[key] = { traitId = traitId, event = interval, fn = fn, wrapped = wrapped }
    if _G.Events and _G.Events[interval] then
        _G.Events[interval].Add(wrapped)
    end
end
UTCore.unregisterPeriodicHandler = function(traitId, interval)
    local keys = {}
    if interval then
        keys[1] = periodicHandlerKey(traitId, interval)
    else
        local prefix = traitId .. "::"
        for key in pairs(UTCore._periodicHandlers) do
            if key:sub(1, #prefix) == prefix then
                keys[#keys + 1] = key
            end
        end
    end

    for _, key in ipairs(keys) do
        local entry = UTCore._periodicHandlers[key]
        if entry and _G.Events and _G.Events[entry.event] then
            _G.Events[entry.event].Remove(entry.wrapped)
        end
        UTCore._periodicHandlers[key] = nil
    end
end

local function _cacheVehicleBaseline(vehicle)
    local vmd = vehicle:getModData()
    if vmd.UT_baseMaxSpeed ~= nil then return vmd end
    vmd.UT_baseMaxSpeed = vehicle:getMaxSpeed()
    vmd.UT_baseBrakingForce = vehicle:getBrakingForce()
    vmd.UT_baseEngineQuality = vehicle:getEngineQuality()
    vmd.UT_baseEngineLoudness = vehicle:getEngineLoudness()
    vmd.UT_baseEnginePower = vehicle:getEnginePower()
    vmd.UT_baseMass = vehicle:getMass()
    vmd.UT_baseInitialMass = vehicle:getInitialMass()
    return vmd
end

UTCore.applyVehicleMod = function(player, stateKey, mods)
    if not player:isDriving() then return end
    local vehicle = player:getVehicle()
    if not vehicle then return end
    local vmd = _cacheVehicleBaseline(vehicle)
    if vmd.UT_vehicleTraitState == stateKey then return end
    vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed * (mods.maxSpeed or 1.0))
    vehicle:setBrakingForce(vmd.UT_baseBrakingForce * (mods.brakingForce or 1.0))
    vehicle:setEngineFeature(
        vmd.UT_baseEngineQuality * (mods.engineQuality or 1.0),
        vmd.UT_baseEngineLoudness * (mods.engineLoudness or 1.0),
        vmd.UT_baseEnginePower * (mods.enginePower or 1.0)
    )
    vehicle:setMass(vmd.UT_baseMass * (mods.mass or 1.0))
    vehicle:setInitialMass(vmd.UT_baseInitialMass * (mods.mass or 1.0))
    vehicle:updateTotalMass()
    vmd.UT_vehicleTraitState = stateKey
end

UTCore.restoreVehicleMod = function(vehicle)
    if not vehicle then return end
    local vmd = vehicle:getModData()
    if vmd.UT_baseMaxSpeed == nil then return end
    vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed)
    vehicle:setBrakingForce(vmd.UT_baseBrakingForce)
    vehicle:setEngineFeature(vmd.UT_baseEngineQuality, vmd.UT_baseEngineLoudness, vmd.UT_baseEnginePower)
    vehicle:setMass(vmd.UT_baseMass)
    vehicle:setInitialMass(vmd.UT_baseInitialMass)
    vehicle:updateTotalMass()
    vmd.UT_vehicleTraitState = nil
end

UTCore.registerVehicleTrait = function(traitId, stateKey, mods, priority)
    UTCore._vehicleTraitDefs[#UTCore._vehicleTraitDefs + 1] = {
        traitId = traitId,
        stateKey = stateKey,
        mods = mods,
        priority = priority or 0,
    }
end

UTCore.syncVehicleTrait = function(player, vehicle)
    local targetVehicle = vehicle or (player and player.getVehicle and player:getVehicle())
    if not player or not targetVehicle then return end
    if player.isDriving and not player:isDriving() then
        UTCore.restoreVehicleMod(targetVehicle)
        return
    end
    local selected = nil
    for _, def in ipairs(UTCore._vehicleTraitDefs) do
        if UTCore.hasTrait(player, def.traitId) then
            if not selected or def.priority > selected.priority then
                selected = def
            end
        end
    end
    if selected then
        UTCore.applyVehicleMod(player, selected.stateKey, selected.mods)
    else
        UTCore.restoreVehicleMod(targetVehicle)
    end
end

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
    local _x = opts.x or 0
    local _y = opts.y or 0
    local _z = opts.z or 0
    local _dead = opts.dead or false
    return {
        _mockType           = "IsoZombie",
        isAlwaysKnockedDown = function(self) return false end,
        knockDown           = function(self, fromBehind)
            _knocked = true
            table.insert(knockDownCalls, fromBehind)
        end,
        isKnockedDown       = function(self) return _knocked end,
        isOnFloor           = function(self) return _knocked end,
        isDead              = function(self) return _dead or _health <= 0 end,
        setDead             = function(self, v) _dead = v end,
        getHealth           = function(self) return _health end,
        setHealth           = function(self, v) _health = v end,
        getKnockDownCalls   = function(self) return knockDownCalls end,
        getX                = function(self) return _x end,
        getY                = function(self) return _y end,
        getZ                = function(self) return _z end,
    }
end

local function fireHandlers(eventTable, handlers, ...)
    local args = { ... }
    if args[1] == eventTable then
        table.remove(args, 1)
    end
    for _, fn in ipairs(handlers) do
        fn(table.unpack(args))
    end
end

-- Events.OnNewGame mock
-- PZ trait files call Events.OnNewGame.Add(fn) with dot notation (no self).
-- The mock's Add must accept that: first arg IS the handler function.
if not _G.Events then _G.Events = {} end
if not _G.Events.AddXP then
    local _xpHandlers = {}
    _G.Events.AddXP = {
        Add  = function(fn) table.insert(_xpHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.AddXP, _xpHandlers, ...) end,
    }
end

if not _G.Events.OnNewGame then
    local _newGameHandlers = {}
    _G.Events.OnNewGame = {
        Add  = function(fn) table.insert(_newGameHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnNewGame, _newGameHandlers, ...) end,
    }
end

if not _G.Events.OnCreatePlayer then
    local _createPlayerHandlers = {}
    _G.Events.OnCreatePlayer = {
        Add  = function(fn) table.insert(_createPlayerHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnCreatePlayer, _createPlayerHandlers, ...) end,
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
        Remove = function(fn)
            for i, handler in ipairs(_updateHandlers) do
                if handler == fn then table.remove(_updateHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnPlayerUpdate, _updateHandlers, ...) end,
    }
end

if not _G.Events.OnPlayerMove then
    local _moveHandlers = {}
    _G.Events.OnPlayerMove = {
        Add  = function(fn) table.insert(_moveHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_moveHandlers) do
                if handler == fn then table.remove(_moveHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnPlayerMove, _moveHandlers, ...) end,
    }
end

if not _G.Events.OnGameBoot then
    local _bootHandlers = {}
    _G.Events.OnGameBoot = {
        Add  = function(fn) table.insert(_bootHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_bootHandlers) do
                if handler == fn then table.remove(_bootHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnGameBoot, _bootHandlers, ...) end,
    }
end

-- Events.OnWeaponHitCharacter stub
-- Stores all registered handlers so tests can fire them via :fire(player, weapon, target).
if not _G.Events.OnWeaponHitCharacter then
    local _weaponHitHandlers = {}
    _G.Events.OnWeaponHitCharacter = {
        Add  = function(fn) table.insert(_weaponHitHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnWeaponHitCharacter, _weaponHitHandlers, ...) end,
    }
end

if not _G.Events.OnActionAdded then
    local _actionAddedHandlers = {}
    _G.Events.OnActionAdded = {
        Add  = function(fn) table.insert(_actionAddedHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnActionAdded, _actionAddedHandlers, ...) end,
    }
end

if not _G.Events.OnVehicleEnter then
    local _vehicleEnterHandlers = {}
    _G.Events.OnVehicleEnter = {
        Add  = function(fn) table.insert(_vehicleEnterHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_vehicleEnterHandlers) do
                if handler == fn then table.remove(_vehicleEnterHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnVehicleEnter, _vehicleEnterHandlers, ...) end,
    }
end

if not _G.Events.OnVehicleExit then
    local _vehicleExitHandlers = {}
    _G.Events.OnVehicleExit = {
        Add  = function(fn) table.insert(_vehicleExitHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_vehicleExitHandlers) do
                if handler == fn then table.remove(_vehicleExitHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnVehicleExit, _vehicleExitHandlers, ...) end,
    }
end

local _mockGameTime = {
    worldAgeHours = 0,
    ticks = 0,
    timeOfDay = 0.5,  -- 0.0–1.0; < 0.25 or > 0.75 = night
}

function setMockGameTime(worldAgeHours, ticks)
    _mockGameTime.worldAgeHours = worldAgeHours or 0
    _mockGameTime.ticks = ticks or 0
end

function setMockTimeOfDay(v)
    _mockGameTime.timeOfDay = v or 0.5
end

function advanceMockGameTimeHours(delta)
    _mockGameTime.worldAgeHours = _mockGameTime.worldAgeHours + (delta or 0)
end

function advanceMockGameTicks(delta)
    _mockGameTime.ticks = _mockGameTime.ticks + (delta or 0)
end

function getGameTime()
    return {
        getWorldAgeHours = function(self) return _mockGameTime.worldAgeHours end,
        getTicks         = function(self) return _mockGameTime.ticks end,
        getTimeOfDay     = function(self) return _mockGameTime.timeOfDay end,
    }
end

-- ─── Climate Manager mock ──────────────────────────────────────────────────────
_mockClimate = {
    precipitationIntensity = 0.0,
    cloudIntensity         = 0.5,
}

function setMockClimate(precip, clouds)
    _mockClimate.precipitationIntensity = precip or 0.0
    _mockClimate.cloudIntensity         = clouds or 0.5
end

function getClimateManager()
    return {
        getPrecipitationIntensity = function(self) return _mockClimate.precipitationIntensity end,
        getCloudIntensity         = function(self) return _mockClimate.cloudIntensity end,
    }
end

if not _G.getPlayer then
    _G.getPlayer = function() return nil end
end

if not _G.getSpecificPlayer then
    _G.getSpecificPlayer = function(index)
        if index == 0 then
            return _G.getPlayer()
        end
        return nil
    end
end

if not _G.BodyPartType then
    _G.BodyPartType = { Neck = "Neck" }
end
_G.BodyPartType.Head        = _G.BodyPartType.Head        or "Head"
_G.BodyPartType.Hand_L      = _G.BodyPartType.Hand_L      or "Hand_L"
_G.BodyPartType.Hand_R      = _G.BodyPartType.Hand_R      or "Hand_R"
_G.BodyPartType.Foot_L      = _G.BodyPartType.Foot_L      or "Foot_L"
_G.BodyPartType.Torso_Upper = _G.BodyPartType.Torso_Upper or "Torso_Upper"
_G.BodyPartType.Torso_Lower = _G.BodyPartType.Torso_Lower or "Torso_Lower"
_G.BodyPartType.UpperArm_L  = _G.BodyPartType.UpperArm_L  or "UpperArm_L"
_G.BodyPartType.UpperArm_R  = _G.BodyPartType.UpperArm_R  or "UpperArm_R"
_G.BodyPartType.FromString   = _G.BodyPartType.FromString  or function(s) return s end

function MockBodyPart(partType, isBleeding, isStemmed)
    local _type = partType or "Torso_Upper"
    local _bleeding = isBleeding or false
    local _stemmed = isStemmed or false
    local _health = 1.0
    local addHealthCalls = 0
    local reduceHealthCalls = 0
    return {
        getType = function(self) return _type end,
        bleeding = function(self) return _bleeding end,
        IsBleedingStemmed = function(self) return _stemmed end,
        getHealth = function(self) return _health end,
        AddHealth = function(self, v) addHealthCalls = addHealthCalls + 1; _health = _health + v end,
        ReduceHealth = function(self, v) reduceHealthCalls = reduceHealthCalls + 1; _health = _health - v end,
        getAddHealthCalls = function(self) return addHealthCalls end,
        getReduceHealthCalls = function(self) return reduceHealthCalls end,
    }
end

function MockBodyPartsList(parts)
    local _parts = parts or {}
    return {
        size = function(self) return #_parts end,
        get = function(self, i) return _parts[i + 1] end,
    }
end

function MockBodyDamage(parts)
    local list = MockBodyPartsList(parts)
    local bleedingCount = 0
    for _, p in ipairs(parts or {}) do
        if p:bleeding() then bleedingCount = bleedingCount + 1 end
    end
    return {
        getBodyParts = function(self) return list end,
        getNumPartsBleeding = function(self) return bleedingCount end,
    }
end

function MockTimedAction(player, actionType, baseDuration)
    local character = player
    local Type = actionType or "ISCraftItem"
    local maxTime = baseDuration or 100
    return {
        character = character,
        Type = Type,
        maxTime = maxTime,
        getDuration = function(self) return maxTime end,
        getMaxTime = function(self) return self.maxTime end,
        setMaxTime = function(self, value)
            self.maxTime = value
            maxTime = value
        end,
    }
end

function MockWeapon(weaponType, meleeDelay, isTwoHand, isMelee, opts)
    opts = opts or {}
    local _type = weaponType or "HandAxe"
    local _delay = meleeDelay or 0
    local _twoHand = (isTwoHand == nil) and false or isTwoHand
    local _melee = (isMelee == nil) and true or isMelee
    local _moddata = opts.moddata or {}
    local _criticalChance = opts.criticalChance or 0
    local _conditionLowerChance = opts.conditionLowerChance or 1
    local setDelayCalls = {}
    local categories = opts.categories
    if not categories then
        categories = {}
        local lowerType = string.lower(_type)
        if string.find(lowerType, "axe", 1, true) then
            categories[#categories + 1] = WeaponCategory.AXE
        end
        if string.find(lowerType, "spear", 1, true) or string.find(lowerType, "pitchfork", 1, true) then
            categories[#categories + 1] = WeaponCategory.SPEAR
        end
    end
    return {
        _mockType = "HandWeapon",
        getType = function(self) return _type end,
        getMeleeDelay = function(self) return _delay end,
        setMeleeDelay = function(self, v)
            table.insert(setDelayCalls, v)
            _delay = v
        end,
        isTwoHandWeapon = function(self) return _twoHand end,
        isMeleeWeapon = function(self) return _melee end,
        isOfWeaponCategory = function(self, category)
            for _, value in ipairs(categories) do
                if value == category then return true end
            end
            return false
        end,
        getCategories = function(self)
            local legacyNames = {}
            for _, category in ipairs(categories) do
                if category == WeaponCategory.AXE then legacyNames[#legacyNames + 1] = "Axe" end
                if category == WeaponCategory.SPEAR then legacyNames[#legacyNames + 1] = "Spear" end
            end
            return makeIndexedList(legacyNames)
        end,
        getModData = function(self) return _moddata end,
        getCriticalChance = function(self) return _criticalChance end,
        setCriticalChance = function(self, value) _criticalChance = value end,
        getConditionLowerChance = function(self) return _conditionLowerChance end,
        setConditionLowerChance = function(self, value) _conditionLowerChance = value end,
        getSetDelayCalls = function(self) return setDelayCalls end,
    }
end

local _mockZombRand = {
    default = 0,
    queue = {},
}

function setMockZombRandDefault(value)
    _mockZombRand.default = value or 0
end

function setMockZombRandSequence(values)
    _mockZombRand.queue = {}
    for _, value in ipairs(values or {}) do
        table.insert(_mockZombRand.queue, value)
    end
end

function resetMockZombRand()
    _mockZombRand.default = 0
    _mockZombRand.queue = {}
end

-- ZombRand stub: configurable queue with a deterministic default of 0.
if not _G.ZombRand then
    _G.ZombRand = function(n)
        local value = _mockZombRand.default
        if #_mockZombRand.queue > 0 then
            value = table.remove(_mockZombRand.queue, 1)
        end
        if n and n > 0 then
            if value < 0 then value = 0 end
            if value >= n then value = value % n end
        end
        return value
    end
end

-- Perks stub: provides SmallBlunt and Nimble sentinels
if not _G.Perks then
    _G.Perks = { SmallBlunt = "SmallBlunt", Nimble = "Nimble", Strength = "Strength" }
else
    _G.Perks.Nimble = _G.Perks.Nimble or "Nimble"
    _G.Perks.Strength = _G.Perks.Strength or "Strength"
end

WeaponCategory = WeaponCategory or {
    AXE = "AXE",
    SPEAR = "SPEAR",
}

-- MockJavaPerk: simulates a PZ Java Perks enum object passed from the engine.
-- In Kahlua, perk args arrive as Java objects: tostring() works, but '..' concat
-- fails with "__concat not defined for operands" unless the code calls tostring()
-- first. Standard Lua mirrors this: a plain table with __tostring but no __concat
-- causes "attempt to concatenate a table value" when used with '..'.
-- Use this in XPHook tests to catch any regression where perk is not tostring()'d.
function MockJavaPerk(name)
    return setmetatable({ _name = name }, {
        __tostring = function(t) return t._name end,
        -- intentionally NO __concat: concatenation must crash if ..'d directly
    })
end

-- Events.OnPanic stub
if not _G.Events.OnPanic then
    local _panicHandlers = {}
    _G.Events.OnPanic = {
        Add  = function(fn) table.insert(_panicHandlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnPanic, _panicHandlers, ...) end,
    }
end

-- Events.EveryOneMinute stub
-- UTCore_ZombieCollisionHook registers an integrity check on this event.
if not _G.Events.EveryOneMinute then
    local _everyOneMinuteHandlers = {}
    _G.Events.EveryOneMinute = {
        Add  = function(fn) table.insert(_everyOneMinuteHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_everyOneMinuteHandlers) do
                if handler == fn then table.remove(_everyOneMinuteHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.EveryOneMinute, _everyOneMinuteHandlers, ...) end,
    }
end

if not _G.Events.EveryTenMinutes then
    local _everyTenMinutesHandlers = {}
    _G.Events.EveryTenMinutes = {
        Add  = function(fn) table.insert(_everyTenMinutesHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_everyTenMinutesHandlers) do
                if handler == fn then table.remove(_everyTenMinutesHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.EveryTenMinutes, _everyTenMinutesHandlers, ...) end,
    }
end

if not _G.Events.EveryHours then
    local _everyHoursHandlers = {}
    _G.Events.EveryHours = {
        Add  = function(fn) table.insert(_everyHoursHandlers, fn) end,
        Remove = function(fn)
            for i, handler in ipairs(_everyHoursHandlers) do
                if handler == fn then table.remove(_everyHoursHandlers, i) return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.EveryHours, _everyHoursHandlers, ...) end,
    }
end

if not UTCore._vehicleTraitEventsRegistered then
    _G.Events.OnVehicleEnter.Add(function(player, vehicle)
        UTCore.syncVehicleTrait(player, vehicle)
    end)
    _G.Events.OnVehicleExit.Add(function(player, vehicle)
        UTCore.restoreVehicleMod(vehicle)
    end)
    _G.Events.OnCreatePlayer.Add(function(_playerIndex, player)
        UTCore.syncVehicleTrait(player)
    end)
    UTCore._vehicleTraitEventsRegistered = true
end

-- ============================================================
-- Additional helpers for behavioral tests (P0 coverage suite)
-- ============================================================

-- MockItem — lightweight item stub for consumption hook tests
-- opts.forageCategory: if set, getScriptItem():getForageFocusCategories() returns a non-empty set
function MockItem(typeName, opts)
    opts = opts or {}
    local forageCategory = opts.forageCategory
    local isFood = opts.isFood
    if isFood == nil then
        isFood = true
    end
    local isCooked = opts.isCooked or false
    local hungerChange = opts.hungerChange
    if hungerChange == nil then
        hungerChange = -10
    end
    local calories = opts.calories or 100
    local moddata = opts.moddata or {}
    -- Build the scriptItem with a forage category set compatible with B42 API
    local scriptItem = {
        getForageFocusCategories = function(self)
            if forageCategory then
                -- Return a non-empty set-like object
                return { isEmpty = function() return false end }
            else
                return { isEmpty = function() return true end }
            end
        end,
    }
    return {
        _mockType = "InventoryItem",
        _type = typeName,
        getType           = function(self) return self._type end,
        getFullType       = function(self) return self._type end,
        getScriptItem     = function(self) return scriptItem end,
        isFood            = function(self) return isFood end,
        isCooked          = function(self) return isCooked end,
        setCooked         = function(self, value) isCooked = value end,
        getHungerChange   = function(self) return hungerChange end,
        setHungerChange   = function(self, value) hungerChange = value end,
        getCalories       = function(self) return calories end,
        setCalories       = function(self, value) calories = value end,
        getModData        = function(self) return moddata end,
    }
end

-- MockFirearm — weapon stub with reload/aim/jam stats for gunspecialist tests
function MockFirearm(opts)
    opts = opts or {}
    local _reload  = opts.reloadTime  or 30
    local _aim     = opts.aimingTime  or 20
    local _jammed  = opts.jammed      or false
    local _moddata = {}
    return {
        _mockType     = "HandWeapon",
        getModData    = function(self) return _moddata end,
        getReloadTime = function(self) return _reload end,
        setReloadTime = function(self, v) _reload = v end,
        getAimingTime = function(self) return _aim end,
        setAimingTime = function(self, v) _aim = v end,
        isJammed      = function(self) return _jammed end,
        setJammed     = function(self, v) _jammed = v end,
        isRanged      = function(self) return true end,
    }
end

-- MockWornItems — worn-item container for humanhamster backpack detection
-- bagCount: number of inventory-container items (bags)
-- nonBagCount: number of non-container worn items
function MockWornItems(bagCount, nonBagCount)
    local slots = {}
    for _ = 1, (bagCount or 0) do
        table.insert(slots, {
            getItem = function(self)
                return { IsInventoryContainer = function() return true end }
            end
        })
    end
    for _ = 1, (nonBagCount or 0) do
        table.insert(slots, {
            getItem = function(self)
                return { IsInventoryContainer = function() return false end }
            end
        })
    end
    return {
        size    = function(self) return #slots end,
        getItem = function(self, i) return slots[i + 1] end,  -- 0-indexed like Java
    }
end

-- MockInventory — simple inventory with configurable weight
function MockInventory(currentWeight, maxWeight)
    local _items = {}
    return {
        getWeight        = function(self) return currentWeight or 0 end,
        getCapacityWeight = function(self) return currentWeight or 0 end,
        getMaxWeight     = function(self) return maxWeight or 8 end,
        getItems         = function(self) return makeIndexedList(_items) end,
        Remove       = function(self, item)
            for i, v in ipairs(_items) do
                if v == item then table.remove(_items, i); return end
            end
        end,
        AddItem      = function(self, item) table.insert(_items, item) end,
        _items       = _items,
    }
end

-- MockSquare — world square stub for item drop
function MockSquare()
    local _dropped = {}
    return {
        _dropped = _dropped,
        AddWorldInventoryItem = function(self, item, _x, _y, _z)
            table.insert(self._dropped, item)
        end,
    }
end

-- MockCollisionSquare — square with positioned moving objects for separate() tests
-- sqX, sqY, sqZ: tile coordinates (integers)
-- movingObjects: array of mock zombie/player objects
function MockCollisionSquare(sqX, sqY, sqZ, movingObjects)
    movingObjects = movingObjects or {}
    local list = {
        size = function(self) return #movingObjects end,
        get  = function(self, i) return movingObjects[i + 1] end,  -- 0-indexed
    }
    return {
        getX = function(self) return sqX end,
        getY = function(self) return sqY end,
        getZ = function(self) return sqZ end,
        getMovingObjects = function(self) return list end,
        AddWorldInventoryItem = function(self, item, _x, _y, _z) end,
    }
end

-- MockCell — minimal cell mock for getCell():getGridSquare(x, y, z)
-- squares: table keyed by "x,y,z" → MockCollisionSquare
function MockCell(squares)
    return {
        getGridSquare = function(self, x, y, z)
            local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
            return squares[key]
        end,
    }
end

-- getCell() global mock — set _G._mockCell before tests that need it
if not _G.getCell then
    _G.getCell = function()
        return _G._mockCell
    end
end

-- OnGameStart event mock (needed for UT_physicallyactive and UT_ItemConsumptionHooks)
if not _G.Events.OnGameStart then
    local _handlers = {}
    _G.Events.OnGameStart = {
        Add  = function(self_or_fn, fn)
            local f = fn or self_or_fn
            table.insert(_handlers, f)
        end,
        fire = function(...)
            for _, h in ipairs(_handlers) do h(...) end
        end,
        _reset = function()
            _handlers = {}
        end,
    }
end

if not _G.Events.OnFishCaught then
    local _handlers = {}
    _G.Events.OnFishCaught = {
        Add = function(self_or_fn, fn)
            local f = fn or self_or_fn
            table.insert(_handlers, f)
        end,
        fire = function(...)
            fireHandlers(_G.Events.OnFishCaught, _handlers, ...)
        end,
    }
end

if not _G.Events.OnFenceClimb then
    local _handlers = {}
    _G.Events.OnFenceClimb = {
        Add = function(self_or_fn, fn)
            local f = fn or self_or_fn
            table.insert(_handlers, f)
        end,
        fire = function(...)
            fireHandlers(_G.Events.OnFenceClimb, _handlers, ...)
        end,
    }
end

if not _G.Events.OnClimbFence then
    local _handlers = {}
    _G.Events.OnClimbFence = {
        Add = function(self_or_fn, fn)
            local f = fn or self_or_fn
            table.insert(_handlers, f)
        end,
        fire = function(...)
            fireHandlers(_G.Events.OnClimbFence, _handlers, ...)
        end,
    }
end

-- ISEatFoodAction stub — must exist before UT_ItemConsumptionHooks wraps perform
if not _G.ISEatFoodAction then
    _G.ISEatFoodAction = {
        perform = function(self) end,
    }
end

-- ISDrinkFluidAction stub
if not _G.ISDrinkFluidAction then
    _G.ISDrinkFluidAction = {
        perform = function(self) end,
    }
end

-- ISFitnessAction stub — needed by UT_physicallyactive to wrap exeLooped
if not _G.ISFitnessAction then
    _G.ISFitnessAction = {
        exeLooped = function(self) end,
    }
end

-- ============================================================
-- Extended stubs for Phase-4 behavioral tests (70 new traits)
-- ============================================================

-- CharacterStat global (B42.16 — all named getters/setters replaced with generic get/set)
if not _G.CharacterStat then
    local function makeStat(name, min, max, default)
        return {
            _name = name,
            getMaximumValue = function(self) return max end,
            getMinimumValue = function(self) return min end,
            getDefaultValue = function(self) return default end,
            clamp = function(self, v) return math.max(min, math.min(max, v)) end,
        }
    end
    _G.CharacterStat = {
        ANGER            = makeStat("Anger", 0, 1, 0),
        BOREDOM          = makeStat("Boredom", 0, 100, 0),
        DISCOMFORT       = makeStat("Discomfort", 0, 100, 0),
        ENDURANCE        = makeStat("Endurance", 0, 1, 1),
        FATIGUE          = makeStat("Fatigue", 0, 1, 0),
        FITNESS          = makeStat("Fitness", -1, 1, 0),
        FOOD_SICKNESS    = makeStat("FoodSickness", 0, 100, 0),
        HUNGER           = makeStat("Hunger", 0, 1, 0),
        IDLENESS         = makeStat("Idleness", 0, 1, 0),
        INTOXICATION     = makeStat("Intoxication", 0, 100, 0),
        MORALE           = makeStat("Morale", 0, 1, 1),
        PAIN             = makeStat("Pain", 0, 100, 0),
        PANIC            = makeStat("Panic", 0, 100, 0),
        SICKNESS         = makeStat("Sickness", 0, 1, 0),
        STRESS           = makeStat("Stress", 0, 1, 0),
        TEMPERATURE      = makeStat("Temperature", 20, 40, 37),
        THIRST           = makeStat("Thirst", 0, 1, 0),
        UNHAPPINESS      = makeStat("Unhappiness", 0, 100, 0),
        WETNESS          = makeStat("Wetness", 0, 100, 0),
        ZOMBIE_FEVER     = makeStat("ZombieFever", 0, 100, 0),
        ZOMBIE_INFECTION = makeStat("ZombieInfection", 0, 100, 0),
    }
end

-- GameTime.getInstance() (used by sloth/squirrel for getMultiplier)
if not _G.GameTime then
    _G.GameTime = {
        getInstance = function()
            return { getMultiplier = function(self) return 1.0 end }
        end,
    }
end

-- isRaining() global (used by lesssweaty)
if not _G.isRaining then
    _G.isRaining = function()
        return _mockClimate.precipitationIntensity > 0.1
    end
end

-- addSound global (used by fearful inside pcall — must exist as a no-op)
if not _G.addSound then
    _G.addSound = function() end
end

-- Events.OnZombieDead stub (used by UT_maniac)
if not _G.Events.OnZombieDead then
    local _handlers = {}
    _G.Events.OnZombieDead = {
        Add  = function(fn) table.insert(_handlers, fn) end,
        fire = function(...) fireHandlers(_G.Events.OnZombieDead, _handlers, ...) end,
    }
end

-- Events.OnWeaponSwingHitPoint stub (used by UT_highsweaty)
if not _G.Events.OnWeaponSwingHitPoint then
    local _handlers = {}
    _G.Events.OnWeaponSwingHitPoint = {
        Add  = function(fn) table.insert(_handlers, fn) end,
        Remove = function(fn)
            for i, h in ipairs(_handlers) do
                if h == fn then table.remove(_handlers, i); return end
            end
        end,
        fire = function(...) fireHandlers(_G.Events.OnWeaponSwingHitPoint, _handlers, ...) end,
    }
end

-- MockBackpack helper — stub for testing UT_flimsy backpack weight checks
function MockBackpack(contentsWeight)
    return {
        _contentsWeight = contentsWeight or 0,
        getContentsWeight = function(self) return self._contentsWeight end,
    }
end
