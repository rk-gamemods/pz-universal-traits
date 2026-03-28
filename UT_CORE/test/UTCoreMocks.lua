-- UTCoreMocks.lua
-- Mock PZ globals for unit tests (standard Lua 5.x, NOT Kahlua).

-- Mock IsoPlayer
function MockPlayer(traits)
    local t = traits or {}
    local moddata = {}
    local maxWeight = 8
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
        isLocalPlayer       = function(self) return true end,
        moveTo              = function(self, nx, ny) x = nx; y = ny end,
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

Events.EveryOneMinute  = _makeEventTable()
Events.EveryTenMinutes = _makeEventTable()
Events.EveryHours      = _makeEventTable()
Events.OnPlayerUpdate  = _makeEventTable()
Events.OnPlayerMove    = _makeEventTable()
Events.OnGameBoot      = _makeEventTable()

_G.getPlayer = function() return nil end  -- tests override this

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
