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
