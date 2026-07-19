-- UTCoreMocks.lua
-- Shared test mock loader for UT_CORE.

local source = debug.getinfo(1, "S").source:sub(2)
local base = source:match("(.*[/\\])") or "./"

dofile(base .. "../../UniversalTraits/test/UTTestMocks.lua")-- UTCoreMocks.lua
-- Mock PZ globals for unit tests (standard Lua 5.x, NOT Kahlua).

-- Mock IsoPlayer
function MockPlayer(traits, opts)
    local t = traits or {}
    opts = opts or {}
    local moddata = {}
    local maxWeight = 8
    local primaryHandItem = opts.primaryHandItem or nil
    local perkLevels = opts.perkLevels or {}
    -- B42.16: pre-register traits so CharacterTrait.get() resolves them
    local traitSet = {}
    for _, id in ipairs(t) do
        traitSet[id] = true
        local rl = ResourceLocation.of(id)
        local key = rl._ns .. ":" .. rl._path
        if not CharacterTrait._byKey[key] then
            CharacterTrait.register(id)
        end
    end
    local statsData = {
        panic          = 0,
        stress         = 0,
        hunger         = 0,
        thirst         = 0,
        fatigue        = 0,
        endurance      = 1,
        pain           = 0,
        boredom        = 0,
        intoxication   = 0,
        unhappiness    = 0,
        wetness        = 0,
        zombie_infection = 0,
        temperature    = opts.bodyTemp or 37.0,
    }
    local stats = {
        -- Generic CharacterStat interface (B42.16 — only API)
        get = function(self, stat)
            local map = {
                [CharacterStat.PAIN] = statsData.pain, [CharacterStat.PANIC] = statsData.panic,
                [CharacterStat.STRESS] = statsData.stress, [CharacterStat.HUNGER] = statsData.hunger,
                [CharacterStat.THIRST] = statsData.thirst, [CharacterStat.BOREDOM] = statsData.boredom,
                [CharacterStat.FATIGUE] = statsData.fatigue, [CharacterStat.UNHAPPINESS] = statsData.unhappiness,
                [CharacterStat.ENDURANCE] = statsData.endurance, [CharacterStat.INTOXICATION] = statsData.intoxication,
                [CharacterStat.WETNESS] = statsData.wetness, [CharacterStat.ZOMBIE_INFECTION] = statsData.zombie_infection,
                [CharacterStat.TEMPERATURE] = statsData.temperature,
            }
            return map[stat] or 0
        end,
        set = function(self, stat, v)
            local setters = {
                [CharacterStat.PAIN] = function(val) statsData.pain = val end,
                [CharacterStat.PANIC] = function(val) statsData.panic = val end,
                [CharacterStat.STRESS] = function(val) statsData.stress = val end,
                [CharacterStat.HUNGER] = function(val) statsData.hunger = val end,
                [CharacterStat.THIRST] = function(val) statsData.thirst = val end,
                [CharacterStat.BOREDOM] = function(val) statsData.boredom = val end,
                [CharacterStat.FATIGUE] = function(val) statsData.fatigue = val end,
                [CharacterStat.UNHAPPINESS] = function(val) statsData.unhappiness = val end,
                [CharacterStat.ENDURANCE] = function(val) statsData.endurance = val end,
                [CharacterStat.INTOXICATION] = function(val) statsData.intoxication = val end,
                [CharacterStat.WETNESS] = function(val) statsData.wetness = val end,
                [CharacterStat.ZOMBIE_INFECTION] = function(val) statsData.zombie_infection = val end,
                [CharacterStat.TEMPERATURE] = function(val) statsData.temperature = val end,
            }
            if setters[stat] then setters[stat](v) end
        end,
        add = function(self, stat, delta)
            local cur = self:get(stat)
            self:set(stat, cur + delta)
        end,
        remove = function(self, stat, delta)
            local cur = self:get(stat)
            self:set(stat, cur - delta)
        end,
    }
    local x, y = 0, 0
    local nx, ny = 0, 0  -- nextX/nextY: engine pending movement targets
    local xpCalls = {}
    local bodyDamage = nil
    local _health     = opts.health or 100
    local _sleeping   = opts.sleeping or false
    local _noiseCalls = {}
    local _bumpType   = ""
    local _bumpedChr  = nil
    local _bumpFall   = false
    local _sprinting  = false
    local _running    = false
    local _driving    = opts.driving or false
    local _vehicle    = opts.vehicle or nil
    local _inventory  = opts.inventory or nil
    local _outside    = (opts.outside == nil) and true or opts.outside
    local _moving     = opts.moving or false
    local _z          = opts.z or 0
    local _square     = opts.square or nil
    local _nutrition  = opts.nutrition or {
        getWeight    = function(self) return 80 end,
        getCalories  = function(self) return 2000 end,
        setCalories  = function(self, v) end,
        getCarbohydrates = function(self) return 50 end,
        getProteins  = function(self) return 50 end,
        getLipids    = function(self) return 50 end,
    }
    return {
        -- B42.16 hasTrait(CharacterTrait): takes a CharacterTrait object
        hasTrait = function(self, ct)
            if not ct then return false end
            return traitSet[ct._id] == true
        end,
        -- Legacy getTraits for backward compat
        getTraits = function(self)
            return {
                contains = function(_, id)
                    for _, v in ipairs(t) do
                        if v == id then return true end
                    end
                    return false
                end
            }
        end,
        getCharacterTraits = function(self)
            local knownList = {}
            for _, id in ipairs(t) do
                local rl = ResourceLocation.of(id)
                local ct = CharacterTrait._byKey[rl._ns .. ":" .. rl._path]
                if ct then knownList[#knownList + 1] = ct end
            end
            return {
                getKnownTraits = function() return { size = function() return #knownList end, get = function(_, i) return knownList[i + 1] end } end,
                add = function(_, ct) if ct and ct._id then traitSet[ct._id] = true end end,
                remove = function(_, ct) if ct and ct._id then traitSet[ct._id] = nil end end,
            }
        end,
        _mockType = "IsoPlayer",
        getModData          = function(self) return moddata end,
        getMaxWeightBase    = function(self) return maxWeight end,
        setMaxWeightBase    = function(self, v) maxWeight = v end,
        getStats            = function(self) return stats end,
        -- Note: returns a new table each call; AddXP captures xpCalls via closure so recording still works.
        getXp               = function(self)
            return {
                AddXP = function(_, perk, amount)
                    table.insert(xpCalls, {perk = perk, amount = amount})
                end
            }
        end,
        getXpCalls          = function(self) return xpCalls end,
        getX                = function(self) return x end,
        getY                = function(self) return y end,
        -- Mirrors IsoMovingObject.setX(): clobbers x, nextX, and scriptNextX to same value.
        -- This is the root cause of the SpeedHook bug — calling setX() during update()
        -- destroys the pending deferred movement stored in nextX.
        setX                = function(self, v) x = v; nx = v end,
        setY                = function(self, v) y = v; ny = v end,
        -- nextX/nextY: engine's pending movement target. In real PZ:
        --   preupdate()  sets nextX = x
        --   doDeferredMovement() adds animation delta to nextX
        --   postupdate() commits dx = nextX - x back into x
        -- Safe to write: setNextX only sets nx, does NOT clobber x or scriptNextX.
        getNextX            = function(self) return nx end,
        getNextY            = function(self) return ny end,
        setNextX            = function(self, v) nx = v end,
        setNextY            = function(self, v) ny = v end,
        isLocalPlayer        = function(self) return true end,
        moveTo               = function(self, mx, my) x = mx; y = my; nx = mx; ny = my end,
        getBodyDamage        = function(self) return bodyDamage end,
        setBodyDamage        = function(self, bd) bodyDamage = bd end,
        getPrimaryHandItem   = function(self) return primaryHandItem end,
        setPrimaryHandItem   = function(self, item) primaryHandItem = item end,
        getSecondaryHandItem = function(self) return opts.secondaryHandItem or nil end,
        getPerkLevel         = function(self, perk) return perkLevels[perk] or 0 end,
        setMeleeDelay        = function(self, v) moddata["_lastMeleeDelay"] = v end,
        getMeleeDelay        = function(self)
            -- B42.16: delay is on the character; delegate to weapon mock for test setup compatibility
            if primaryHandItem and primaryHandItem.getMeleeDelay then
                return primaryHandItem:getMeleeDelay()
            end
            return opts.meleeDelay or 0
        end,
        isSprinting          = function(self) return _sprinting end,
        isRunning            = function(self) return _running end,
        setSprinting         = function(self, v) _sprinting = v end,
        setRunning           = function(self, v) _running = v end,
        isBumped             = function(self) return _bumpType ~= "" end,
        getBumpedChr         = function(self) return _bumpedChr end,
        setBumpedChr         = function(self, chr) _bumpedChr = chr end,
        setBumpType          = function(self, s) _bumpType = s end,
        setBumpFall          = function(self, v) _bumpFall = v end,
        _blockMovement       = false,
        setBlockMovement     = function(self, v) self._blockMovement = v end,
        getBlockMovement     = function(self) return self._blockMovement end,
        getHealth            = function(self) return _health end,
        setHealth            = function(self, v) _health = v end,
        isSleeping           = function(self) return _sleeping end,
        setSleeping          = function(self, v) _sleeping = v end,
        isAsleep             = function(self) return _sleeping end,
        setAsleep            = function(self, v) _sleeping = v end,
        makeNoise            = function(self, v) table.insert(_noiseCalls, v) end,
        addWorldSoundUnlessInvisible = function(self, radius, _volume, _stress)
            -- B42.16 replacement for makeNoise; track radius so NoiseHook tests still pass
            table.insert(_noiseCalls, radius)
        end,
        getNoiseCalls        = function(self) return _noiseCalls end,
        isDriving            = function(self) return _driving end,
        getVehicle           = function(self) return _vehicle end,
        setDriving           = function(self, v) _driving = v end,
        setVehicle           = function(self, v) _vehicle = v end,
        isDead               = function(self) return false end,
        getInventory         = function(self) return _inventory end,
        isOutside            = function(self) return _outside end,
        isMoving             = function(self) return _moving end,
        getZ                 = function(self) return _z end,
        getCurrentSquare     = function(self) return _square end,
        setCurrentSquare     = function(self, sq) _square = sq end,
        getNutrition         = function(self) return _nutrition end,
        -- Animation variable store (BumpDone, BumpFallAnimFinished, etc.)
        _variables           = {},
        setVariable          = function(self, key, val)
            if type(val) == "boolean" then val = tostring(val) end
            self._variables[key] = tostring(val)
        end,
        getVariable          = function(self, key) return self._variables[key] end,
        getVariableBoolean   = function(self, key) return self._variables[key] == "true" end,
        clearVariable        = function(self, key) self._variables[key] = nil end,
        -- BumpDone state
        _bumpDone            = true,
        setBumpDone          = function(self, v) self._bumpDone = v end,
        isBumpDone           = function(self) return self._bumpDone end,
        -- isBlockMovement alias (PZ Java getter style)
        isBlockMovement      = function(self) return self._blockMovement end,
        -- Hit reaction state
        _hitReaction         = "",
        setHitReaction       = function(self, v) self._hitReaction = v end,
        getHitReaction       = function(self) return self._hitReaction end,
        -- Animation state (used by buildTickContext)
        _isHostileAnim       = false,
        isPerformingHostileAnimation = function(self) return self._isHostileAnim end,
        isPerformingAttackAnimation  = function(self) return false end,
        isPathing            = function(self) return false end,
        isAiming             = function(self) return false end,
        -- Spotted list (used by lazy enemy builder)
        _spottedList         = nil,
        getSpottedList       = function(self)
            return self._spottedList or { size = function() return 0 end, get = function(_, i) return nil end }
        end,
        setSpottedList       = function(self, list) self._spottedList = list end,
        DistTo               = function(self, other) return 10.0 end,
    }
end

-- MockZombie: simulates an IsoZombie for ZombieCollisionHook tests
function MockZombie(opts)
    opts = opts or {}
    local _health        = opts.health or 100
    local _knocked       = false
    local _crawling      = opts.crawling or false
    local knockDownCalls = {}
    local _x = opts.x or 0
    local _y = opts.y or 0
    local _z = opts.z or 0
    local _dead          = opts.dead or false
    return {
        _mockType           = "IsoZombie",
        isAlwaysKnockedDown = function(self) return false end,
        knockDown           = function(self, fromBehind)
            _knocked = true
            table.insert(knockDownCalls, fromBehind)
        end,
        isKnockedDown       = function(self) return _knocked end,
        isCrawling          = function(self) return _crawling end,
        setCrawling         = function(self, v) _crawling = v end,
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

-- Mock Events global
Events = Events or {}

local function _makeEventTable()
    local handlers = {}
    return {
        Add    = function(fn) table.insert(handlers, fn) end,
        Remove = function(fn)
            for i, v in ipairs(handlers) do
                if v == fn then table.remove(handlers, i) return end
            end
        end,
        fire   = function(...)
            for _, fn in ipairs(handlers) do fn(...) end
        end,
    }
end

Events.AddXP = _makeEventTable()

Events.EveryOneMinute         = _makeEventTable()
Events.EveryTenMinutes        = _makeEventTable()
Events.EveryHours             = _makeEventTable()
Events.OnPlayerUpdate         = _makeEventTable()
Events.OnPlayerMove           = _makeEventTable()
Events.OnGameBoot             = _makeEventTable()
Events.OnWeaponHitCharacter   = _makeEventTable()
Events.OnCreatePlayer         = _makeEventTable()
Events.OnEnterVehicle         = _makeEventTable()
-- Reset registration flag so UTCore_StatModifiers re-registers into these fresh tables.
if UTCore then UTCore._vehicleTraitEventsRegistered = false end

_G.getPlayer = function() return nil end  -- tests override this

-- BodyPartType global (needed by BleedHook)
-- Ensure BodyPartType has all types needed by hooks (UTTestMocks may have already
-- defined it with only Neck, so we merge rather than guard with if-not).
_G.BodyPartType = _G.BodyPartType or {}
_G.BodyPartType.Neck       = _G.BodyPartType.Neck       or "Neck"
_G.BodyPartType.Leg_L      = _G.BodyPartType.Leg_L      or "Leg_L"
_G.BodyPartType.Leg_R      = _G.BodyPartType.Leg_R      or "Leg_R"
_G.BodyPartType.UpperArm_L = _G.BodyPartType.UpperArm_L or "UpperArm_L"
_G.BodyPartType.UpperArm_R = _G.BodyPartType.UpperArm_R or "UpperArm_R"
_G.BodyPartType.LowerArm_L = _G.BodyPartType.LowerArm_L or "LowerArm_L"
_G.BodyPartType.LowerArm_R = _G.BodyPartType.LowerArm_R or "LowerArm_R"

-- ZombRand: always returns 0 in tests (lowest roll — fracture/chance checks always succeed)
_G.ZombRand = _G.ZombRand or function(n) return 0 end

-- MockBodyPart: simulates a PZ IsoBodyPart
function MockBodyPart(partType, isBleeding, isStemmed)
    local _type = partType or "Torso_Upper"
    local _bleeding = isBleeding or false
    local _stemmed = isStemmed or false
    local _health = 1.0
    local _fractureTime = 0
    local addHealthCalls = 0
    local reduceHealthCalls = 0
    return {
        getType              = function(self) return _type end,
        bleeding             = function(self) return _bleeding end,
        IsBleedingStemmed    = function(self) return _stemmed end,
        getHealth            = function(self) return _health end,
        AddHealth            = function(self, v) addHealthCalls = addHealthCalls + 1; _health = _health + v end,
        ReduceHealth         = function(self, v) reduceHealthCalls = reduceHealthCalls + 1; _health = _health - v end,
        getAddHealthCalls    = function(self) return addHealthCalls end,
        getReduceHealthCalls = function(self) return reduceHealthCalls end,
        isFractured          = function(self) return _fractureTime > 0 end,
        setFractured         = function(self, v) _fractureTime = v and 1 or 0 end,
        setFractureTime      = function(self, v) _fractureTime = v end,
        getFractureTime      = function(self) return _fractureTime end,
    }
end

-- MockBodyPartsList: Java-like ArrayList with 0-indexed get(i) and size()
function MockBodyPartsList(parts)
    local _parts = parts or {}
    return {
        size = function(self) return #_parts end,
        get  = function(self, i) return _parts[i + 1] end,  -- 0-indexed like Java
    }
end

-- MockBodyDamage: simulates player:getBodyDamage()
function MockBodyDamage(parts)
    local list = MockBodyPartsList(parts)
    local bleedingCount = 0
    local _byType = {}
    for _, p in ipairs(parts or {}) do
        if p:bleeding() then bleedingCount = bleedingCount + 1 end
        _byType[p:getType()] = p
    end
    return {
        getBodyParts        = function(self) return list end,
        getNumPartsBleeding = function(self) return bleedingCount end,
        getBodyPart         = function(self, partType) return _byType[partType] end,
    }
end

-- MockTimedAction: simulates a PZ TimedAction for WorkSpeedHook tests
function MockTimedAction(player, actionType, baseDuration)
    local character = player
    local Type = actionType or "ISCraftItem"
    local maxTime = baseDuration or 100
    return {
        character = character,
        Type = Type,
        getDuration = function(self) return maxTime end,
    }
end

-- MockWeapon: simulates a PZ HandWeapon for MeleeDelayHook tests
function MockWeapon(weaponType, meleeDelay, isTwoHand, isMelee, opts)
    opts = opts or {}
    local _type       = weaponType or "HandAxe"
    local _delay      = meleeDelay or 0
    local _twoHand    = (isTwoHand == nil) and false or isTwoHand
    local _melee      = (isMelee == nil) and true or isMelee
    local _moddata    = opts.moddata or {}
    local _criticalChance = opts.criticalChance or 0
    local _conditionLowerChance = opts.conditionLowerChance or 1
    local setDelayCalls = {}
    local categories = opts.categories or {}
    return {
        _mockType        = "HandWeapon",
        getType          = function(self) return _type end,
        getMeleeDelay    = function(self) return _delay end,
        setMeleeDelay    = function(self, v)
            table.insert(setDelayCalls, v)
            _delay = v
        end,
        isTwoHandWeapon  = function(self) return _twoHand end,
        isMeleeWeapon    = function(self) return _melee end,
        isOfWeaponCategory = function(self, category)
            for _, value in ipairs(categories) do
                if value == category then return true end
            end
            return false
        end,
        getModData       = function(self) return _moddata end,
        getCriticalChance = function(self) return _criticalChance end,
        setCriticalChance = function(self, value) _criticalChance = value end,
        getConditionLowerChance = function(self) return _conditionLowerChance end,
        setConditionLowerChance = function(self, value) _conditionLowerChance = value end,
        getSetDelayCalls = function(self) return setDelayCalls end,
    }
end
