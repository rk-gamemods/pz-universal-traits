-- UTCoreMocks.lua
-- Mock PZ globals for unit tests (standard Lua 5.x, NOT Kahlua).

-- Mock IsoPlayer
function MockPlayer(traits)
    local t = traits or {}
    local moddata = {}
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
        getModData = function(self) return moddata end,
    }
end
