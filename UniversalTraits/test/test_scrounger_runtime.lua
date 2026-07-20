local M = {}

function M.run(test, assert_eq, assert_true, base)
    local runtimePath = base .. "../media/lua/shared/UniversalTraits/traits/UT_scrounger.lua"

    local function scenario(options)
        options = options or {}
        local handlers = {}
        local player = { hasScrounger = options.hasTrait ~= false }
        local selectedPlayerIndex
        local sent = {}
        local randomValues = options.randomValues or { 0, 0 }
        local randomIndex = 0

        Events.OnRefreshInventoryWindowContainers = {
            Add = function(handler) handlers[#handlers + 1] = handler end,
            fire = function(...)
                assert_eq(select("#", ...), 2, "engine event emits exactly two arguments")
                for _, handler in ipairs(handlers) do handler(...) end
            end,
        }
        UTCore.hasTrait = function(actual, traitId)
            assert_eq(actual, player, "trait check uses the page player")
            assert_eq(traitId, "UniversalTraits:UT_scrounger")
            return actual.hasScrounger
        end
        getSpecificPlayer = function(index)
            selectedPlayerIndex = index
            if options.nilPlayer then return nil end
            return player
        end
        instanceof = function(object, className)
            return object and object._classes and object._classes[className] == true
        end
        ZombRand = function(limit)
            randomIndex = randomIndex + 1
            local value = randomValues[randomIndex]
            assert_true(value ~= nil, "unexpected extra random roll")
            assert_true(value >= 0 and value < limit, "mock random value must fit the engine bound")
            return value
        end
        sendAddItemToContainer = function(container, item)
            sent[#sent + 1] = { container = container, item = item }
        end

        local modData = options.modData or {}
        local worldObject = {
            _classes = { IsoObject = true, IsoDeadBody = options.deadBody == true },
            getModData = function() return modData end,
            transmitModData = function(self) self.transmits = (self.transmits or 0) + 1 end,
        }
        local sourceItems = options.items or { "Base.Apple", "Base.Bandage" }
        local javaItems = {
            size = function() return #sourceItems end,
            get = function(_, index)
                local fullType = sourceItems[index + 1]
                if not fullType then return nil end
                return { getFullType = function() return fullType end }
            end,
        }
        local inventory = {
            getParent = function() return worldObject end,
            getItems = function() return javaItems end,
            AddItem = function(self, fullType)
                local item = { fullType = fullType }
                self.added = self.added or {}
                self.added[#self.added + 1] = item
                return item
            end,
        }
        local page = { player = options.playerIndex or 2, backpacks = { { inventory = inventory } } }

        UTScroungerRuntime = nil
        dofile(runtimePath)
        if options.reload then dofile(runtimePath) end

        return {
            fire = function(state) Events.OnRefreshInventoryWindowContainers.fire(page, state) end,
            handlers = handlers,
            inventory = inventory,
            modData = modData,
            worldObject = worldObject,
            sent = sent,
            randomCalls = function() return randomIndex end,
            selectedPlayerIndex = function() return selectedPlayerIndex end,
        }
    end

    test("scrounger event contract, Lua-array receiver, player resolution, and four-phase gating", function()
        local s = scenario()
        assert_eq(#s.handlers, 1)
        for _, state in ipairs({ "start", "refresh", "middle" }) do s.fire(state) end
        assert_eq(s.randomCalls(), 0, "only the completed inspection may roll")
        s.fire("end")
        assert_eq(s.selectedPlayerIndex(), 2, "inventory page player index is resolved")
        assert_eq(#s.inventory.added, 1, "plain Lua backpacks array is traversed")
    end)

    test("scrounger gates nil player and missing trait", function()
        local nilPlayer = scenario({ nilPlayer = true })
        nilPlayer.fire("end")
        assert_eq(nilPlayer.randomCalls(), 0)
        local noTrait = scenario({ hasTrait = false })
        noTrait.fire("end")
        assert_eq(noTrait.randomCalls(), 0)
    end)

    test("scrounger excludes dead bodies and handles empty containers", function()
        local corpse = scenario({ deadBody = true })
        corpse.fire("end")
        assert_eq(corpse.modData.UT_scroungerRolled, nil)
        local empty = scenario({ items = {} })
        empty.fire("end")
        assert_true(empty.modData.UT_scroungerRolled, "completed empty inspection is permanently marked")
        assert_eq(empty.randomCalls(), 0)
    end)

    test("scrounger 30 percent failure marks once and never rebuilds", function()
        local s = scenario({ randomValues = { 30 } })
        s.fire("end")
        s.fire("end")
        assert_true(s.modData.UT_scroungerRolled)
        assert_eq(s.worldObject.transmits, 1)
        assert_eq(s.randomCalls(), 1)
        assert_eq(s.inventory.added, nil)
    end)

    test("scrounger success duplicates exactly one zero-based Java-list item and sends it globally", function()
        local s = scenario({ randomValues = { 29, 1 } })
        s.fire("end")
        assert_eq(#s.inventory.added, 1)
        assert_eq(s.inventory.added[1].fullType, "Base.Bandage")
        assert_eq(#s.sent, 1)
        assert_eq(s.sent[1].container, s.inventory)
        assert_eq(s.sent[1].item, s.inventory.added[1])
        s.fire("end")
        assert_eq(#s.inventory.added, 1, "persistent flag prevents a rebuild duplicate")
    end)

    test("scrounger repeated module load registers only once", function()
        local s = scenario({ reload = true })
        assert_eq(#s.handlers, 1, "trait-local registration is idempotent")
    end)

    test("scrounger source, release, definition, and EN description stay exact", function()
        local function read(path)
            local file = assert(io.open(path, "rb"))
            local content = file:read("*a")
            file:close()
            return content
        end
        local source = read(runtimePath)
        local release = read(base .. "../release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_scrounger.lua")
        assert_eq(release, source, "runtime source/release parity")
        local scripts = read(base .. "../media/scripts/UT_character_traits.txt")
        assert_true(scripts:find("Cost = 3,", 1, true) ~= nil)
        assert_true(scripts:find("XPBoosts = PlantScavenging=1,", 1, true) ~= nil)
        local expected = '"UI_UT_scroungerDesc": "+1 to Plant Scavenging. When opening a container for the first time, 30 percent chance to find an additional item."'
        local uiSource = read(base .. "../media/lua/shared/Translate/EN/UI.json")
        local uiRelease = read(base .. "../release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json")
        assert_true(uiSource:find(expected, 1, true) ~= nil, "source EN description has exact outcome parity")
        assert_eq(uiRelease, uiSource, "EN source/release parity")
    end)
end

if arg and arg[0] and arg[0]:match("test_scrounger_runtime%.lua$") then
    local base = arg[0]:match("(.*[/\\])") or "./"
    dofile(base .. "UTTestMocks.lua")
    local passed, failed = 0, 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        if ok then print("PASS  " .. name); passed = passed + 1
        else print("FAIL  " .. name .. "\n      " .. tostring(err)); failed = failed + 1 end
    end
    local function assert_eq(actual, expected, message)
        if actual ~= expected then error((message or "") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual), 2) end
    end
    local function assert_true(value, message)
        if not value then error(message or "expected true", 2) end
    end
    M.run(test, assert_eq, assert_true, base)
    print(string.format("\n%d passed, %d failed", passed, failed))
    if failed > 0 then os.exit(1) end
end

return M
