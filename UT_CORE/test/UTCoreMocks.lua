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
    }
end
