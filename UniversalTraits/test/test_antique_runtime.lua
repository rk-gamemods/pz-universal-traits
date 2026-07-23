local M = {}

function M.run(test, assert_eq, assert_true, base)
    local runtimePath = base .. "../media/lua/shared/UniversalTraits/traits/UT_antique.lua"

    local function scenario(options)
        options = options or {}
        local handlers = {}
        local player = { hasAntique = options.hasTrait ~= false }
        local selectedPlayerIndex
        local sent = {}
        local randomValues = options.randomValues or { 0, 0 }
        local randomIndex = 0
        local worldAgeHours = options.worldAgeHours or 100

        Events.OnRefreshInventoryWindowContainers = {
            Add = function(handler) handlers[#handlers + 1] = handler end,
            fire = function(...)
                assert_eq(select("#", ...), 2, "engine event emits exactly two arguments")
                for _, handler in ipairs(handlers) do handler(...) end
            end,
        }
        UTCore.hasTrait = function(actual, traitId)
            assert_eq(actual, player, "trait check uses the inventory page player")
            assert_eq(traitId, "UniversalTraits:UT_antique")
            return actual.hasAntique
        end
        getSpecificPlayer = function(index)
            selectedPlayerIndex = index
            if options.nilPlayer then return nil end
            return player
        end
        getGameTime = function()
            return { getWorldAgeHours = function() return worldAgeHours end }
        end
        SandboxVars = { LootRespawn = options.lootRespawn or 1 }
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
        local inventory
        local worldObject = {
            _classes = {
                IsoObject = options.isoObject ~= false,
                IsoDeadBody = options.deadBody == true,
            },
            getContainer = function() return inventory end,
            getModData = function() return modData end,
            transmitModData = function(self) self.transmits = (self.transmits or 0) + 1 end,
        }
        inventory = {
            getType = function() return options.containerType or "crate" end,
            getParent = function() return worldObject end,
            AddItem = function(self, fullType)
                if options.addFails then return nil end
                local item = { fullType = fullType }
                self.added = self.added or {}
                self.added[#self.added + 1] = item
                return item
            end,
        }
        local backpacks = options.backpacks or { { inventory = inventory } }
        local page = { player = options.playerIndex or 2, backpacks = backpacks }

        UTAntiqueRuntime = nil
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
            setWorldAgeHours = function(value) worldAgeHours = value end,
        }
    end

    test("antique follows the exact event contract, Lua-array receiver, and end-phase cadence", function()
        local s = scenario()
        assert_eq(#s.handlers, 1)
        for _, state in ipairs({ "begin", "beforeFloor", "buttonsAdded" }) do
            s.fire(state)
            assert_eq(s.randomCalls(), 0, state .. " must not roll")
            assert_eq(s.modData.UT_antiqueRolled, nil, state .. " must not mark the container")
            assert_eq(s.worldObject.transmits, nil, state .. " must not transmit mod data")
            assert_eq(s.inventory.added, nil, state .. " must not add an item")
            assert_eq(#s.sent, 0, state .. " must not sync an item")
        end
        s.fire("end")
        assert_true(s.modData.UT_antiqueRolled, "end phase marks the completed roll")
        assert_eq(s.modData.UT_antiqueChecked, 100, "end phase records world age")
        assert_eq(s.worldObject.transmits, 1, "end phase transmits mod data once")
        assert_eq(s.randomCalls(), 2, "successful end phase makes one chance and one item roll")
        assert_eq(s.selectedPlayerIndex(), 2, "inventory page player index is resolved")
        assert_eq(#s.inventory.added, 1, "plain Lua backpacks array is traversed")
        assert_eq(#s.sent, 1, "the added item uses the verified global sync surface")
    end)

    test("antique gates missing page player, missing trait, and repeated module loads", function()
        local nilPlayer = scenario({ nilPlayer = true })
        nilPlayer.fire("end")
        assert_eq(nilPlayer.randomCalls(), 0)
        local noTrait = scenario({ hasTrait = false })
        noTrait.fire("end")
        assert_eq(noTrait.randomCalls(), 0)
        local reloaded = scenario({ reload = true })
        assert_eq(#reloaded.handlers, 1, "trait-local registration is idempotent")
    end)

    test("antique accepts only live IsoObject crates and metal shelves", function()
        for _, containerType in ipairs({ "crate", "metal_shelves" }) do
            local eligible = scenario({ containerType = containerType, randomValues = { 8 } })
            eligible.fire("end")
            assert_true(eligible.modData.UT_antiqueRolled, containerType .. " must be inspected")
            assert_eq(eligible.randomCalls(), 1)
        end
        for _, options in ipairs({
            { containerType = "freezer" },
            { deadBody = true },
            { isoObject = false },
            { backpacks = {} },
        }) do
            local excluded = scenario(options)
            excluded.fire("end")
            assert_eq(excluded.randomCalls(), 0)
            assert_eq(excluded.modData.UT_antiqueRolled, nil)
        end
    end)

    test("antique chance boundary is exactly 8 in 1000 and rolls only once per cycle", function()
        for _, roll in ipairs({ 0, 7 }) do
            local success = scenario({ randomValues = { roll, 0 } })
            success.fire("end")
            success.fire("end")
            assert_eq(#success.inventory.added, 1, "roll " .. roll .. " succeeds once")
            assert_eq(success.randomCalls(), 2, "success consumes one chance and one item roll")
        end
        for _, roll in ipairs({ 8, 999 }) do
            local failure = scenario({ randomValues = { roll } })
            failure.fire("end")
            failure.fire("end")
            assert_eq(failure.inventory.added, nil, "roll " .. roll .. " fails")
            assert_eq(failure.randomCalls(), 1, "failed cycle cannot reroll")
            assert_true(failure.modData.UT_antiqueRolled)
        end
    end)

    test("antique loot-respawn modes reopen the roll at the exact hour boundary", function()
        local modes = { [2] = 24, [3] = 168, [4] = 720, [5] = 1440 }
        for mode, hours in pairs(modes) do
            local modData = { UT_antiqueRolled = true, UT_antiqueChecked = 100 }
            local s = scenario({ lootRespawn = mode, modData = modData, randomValues = { 999 } })
            s.setWorldAgeHours(100 + hours - 0.001)
            s.fire("end")
            assert_eq(s.randomCalls(), 0, "mode " .. mode .. " must wait for the full interval")
            s.setWorldAgeHours(100 + hours)
            s.fire("end")
            assert_eq(s.randomCalls(), 1, "mode " .. mode .. " reopens exactly at the boundary")
            assert_eq(modData.UT_antiqueChecked, 100 + hours)
        end
        local never = scenario({
            lootRespawn = 1,
            modData = { UT_antiqueRolled = true, UT_antiqueChecked = 100 },
        })
        never.setWorldAgeHours(100000)
        never.fire("end")
        assert_eq(never.randomCalls(), 0, "no-respawn mode never reopens the roll")
    end)

    test("antique item selection covers both table boundaries and nil insertion", function()
        local first = scenario({ randomValues = { 0, 0 } })
        first.fire("end")
        assert_eq(first.inventory.added[1].fullType, "UniversalTraits.AntiqueAxe")
        local last = scenario({ randomValues = { 0, 6 } })
        last.fire("end")
        assert_eq(last.inventory.added[1].fullType, "UniversalTraits.AntiqueBoots")
        local failedInsert = scenario({ randomValues = { 0, 3 }, addFails = true })
        failedInsert.fire("end")
        assert_eq(#failedInsert.sent, 0, "nil AddItem result is never synced")
        assert_true(failedInsert.modData.UT_antiqueRolled, "completed roll remains marked")
    end)

    test("antique source, release, definition, and English contract stay exact", function()
        local function read(path)
            local file = assert(io.open(path, "rb"))
            local content = file:read("*a")
            file:close()
            return content
        end
        local source = read(runtimePath)
        local release = read(base .. "../release/UniversalTraits/42.0/media/lua/shared/UniversalTraits/traits/UT_antique.lua")
        assert_eq(release, source, "runtime source/release parity")
        assert_true(source:find("sendAddItemToContainer(container, item)", 1, true) ~= nil,
            "Antique uses the current global container sync surface")
        assert_true(source:find("addItemOnServer", 1, true) == nil,
            "removed ItemContainer API must not return")

        local scripts = read(base .. "../media/scripts/UT_character_traits.txt")
        local releaseScripts = read(base .. "../release/UniversalTraits/42.0/media/scripts/UT_character_traits.txt")
        assert_eq(releaseScripts, scripts, "definition source/release parity")
        local block = scripts:match("character_trait_definition UniversalTraits:UT_antique%s*(%b{})")
        assert_true(block ~= nil, "Antique definition exists")
        assert_true(block:find("Cost = 6,", 1, true) ~= nil, "Antique cost remains 6")
        assert_true(block:find("XPBoosts", 1, true) == nil, "Antique grants no XP boost")
        assert_true(block:find("GrantedTraits", 1, true) == nil, "Antique grants no trait")
        assert_true(block:find("MutuallyExclusiveTraits", 1, true) == nil, "Antique has no exclusions")
        assert_true(block:find("DisabledInMultiplayer = true,", 1, true) ~= nil,
            "Antique remains unavailable in multiplayer")

        local itemScripts = read(base .. "../media/scripts/UT_items.txt")
        local releaseItemScripts = read(base .. "../release/UniversalTraits/42.0/media/scripts/UT_items.txt")
        assert_eq(releaseItemScripts, itemScripts, "Antique item definitions stay packaged exactly")
        for _, itemName in ipairs({
            "AntiqueAxe", "AntiqueKatana", "AntiqueSpear", "AntiqueHammer",
            "AntiqueJacket", "AntiqueVest", "AntiqueBoots",
        }) do
            assert_true(itemScripts:find("item " .. itemName, 1, true) ~= nil,
                itemName .. " must resolve through ScriptManager")
        end

        local expected = '"UI_UT_antiqueDesc": "Your eye for rare and exceptional craftsmanship gives you a chance to find antique weapons and clothing hidden in crates and metal shelves. These items are significantly better than anything else you can find. Roughly 0.8 percent chance per eligible container, once per loot cycle."'
        local uiSource = read(base .. "../media/lua/shared/Translate/EN/UI.json")
        local uiRelease = read(base .. "../release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json")
        assert_true(uiSource:find(expected, 1, true) ~= nil, "English describes the exact accepted outcome")
        assert_eq(uiRelease, uiSource, "English source/release parity")
    end)
end

if arg and arg[0] and arg[0]:match("test_antique_runtime%.lua$") then
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
