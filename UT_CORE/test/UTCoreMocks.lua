-- UTCoreMocks.lua
-- Mock PZ globals for unit tests (standard Lua 5.x, NOT Kahlua).

-- Mock IsoPlayer
function MockPlayer(traits, opts)
    local t = traits or {}
    opts = opts or {}
    local moddata = {}
    local maxWeight = 8
    local primaryHandItem = opts.primaryHandItem or nil
    local perkLevels = opts.perkLevels or {}
    local statsData = {
        panic     = 0,
        stress    = 0,
        hunger    = 0,
        thirst    = 0,
        fatigue   = 0,
        endurance = 1,
    }
    local stats = {
        getPanic     = function(self) return statsData.panic end,
        setPanic     = function(self, v) statsData.panic = v end,
        getStress    = function(self) return statsData.stress end,
        setStress    = function(self, v) statsData.stress = v end,
        getHunger    = function(self) return statsData.hunger end,
        setHunger    = function(self, v) statsData.hunger = v end,
        getThirst    = function(self) return statsData.thirst end,
        setThirst    = function(self, v) statsData.thirst = v end,
        getFatigue   = function(self) return statsData.fatigue end,
        setFatigue   = function(self, v) statsData.fatigue = v end,
        getEndurance = function(self) return statsData.endurance end,
        setEndurance = function(self, v) statsData.endurance = v end,
    }
    local x, y = 0, 0
    local xpCalls = {}
    local bodyDamage = nil
    return {
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
        setX                = function(self, v) x = v end,
        setY                = function(self, v) y = v end,
        isLocalPlayer        = function(self) return true end,
        moveTo               = function(self, nx, ny) x = nx; y = ny end,
        getBodyDamage        = function(self) return bodyDamage end,
        setBodyDamage        = function(self, bd) bodyDamage = bd end,
        getPrimaryHandItem   = function(self) return primaryHandItem end,
        setPrimaryHandItem   = function(self, item) primaryHandItem = item end,
        getPerkLevel         = function(self, perk) return perkLevels[perk] or 0 end,
        setMeleeDelay        = function(self, v) moddata["_lastMeleeDelay"] = v end,
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

_G.getPlayer = function() return nil end  -- tests override this

-- BodyPartType global (needed by BleedHook)
if not _G.BodyPartType then
    _G.BodyPartType = { Neck = "Neck" }
end

-- MockBodyPart: simulates a PZ IsoBodyPart
function MockBodyPart(partType, isBleeding, isStemmed)
    local _type = partType or "Torso_Upper"
    local _bleeding = isBleeding or false
    local _stemmed = isStemmed or false
    local _health = 1.0
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
    for _, p in ipairs(parts or {}) do
        if p:bleeding() then bleedingCount = bleedingCount + 1 end
    end
    return {
        getBodyParts        = function(self) return list end,
        getNumPartsBleeding = function(self) return bleedingCount end,
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
function MockWeapon(weaponType, meleeDelay, isTwoHand, isMelee)
    local _type       = weaponType or "HandAxe"
    local _delay      = meleeDelay or 0
    local _twoHand    = (isTwoHand == nil) and false or isTwoHand
    local _melee      = (isMelee == nil) and true or isMelee
    local setDelayCalls = {}
    return {
        getType          = function(self) return _type end,
        getMeleeDelay    = function(self) return _delay end,
        setMeleeDelay    = function(self, v)
            table.insert(setDelayCalls, v)
            _delay = v
        end,
        isTwoHandWeapon  = function(self) return _twoHand end,
        isMeleeWeapon    = function(self) return _melee end,
        getSetDelayCalls = function(self) return setDelayCalls end,
    }
end
