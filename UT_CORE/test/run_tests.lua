-- run_tests.lua  (UT_CORE)
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" test/run_tests.lua

local base = arg[0]:match("(.*[/\\])") or "./"
package.path = base .. "../media/lua/shared/?.lua;" .. package.path

-- Load mocks
dofile(base .. "UTCoreMocks.lua")

-- Load UTCore modules
-- ORDER MATTERS: API must load before TickDispatch and hooks (registerCoreHandler
-- is defined in API). TickDispatch must load before any hook that registers via
-- registerCoreHandler. This mirrors PZ's alphabetical file load order.
dofile(base .. "../media/lua/shared/UTCore/UTCore_Diagnostics.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_API.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_TickDispatch.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_FreezeLogger.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_TraitChecks.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_Events.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_StatModifiers.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_SpawnEffects.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_XPHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_ReadingHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_BleedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_BleedDecayHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_BleedDrainHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_MeleeDelayHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_PainHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_FractureHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_NoiseHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_SleepQualityHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_ThermalRegulationHook.lua")

local passed, failed = 0, 0
local testFilter = os.getenv("UT_CORE_TEST_FILTER")
local function test(name, fn)
    if testFilter and not name:find(testFilter, 1, true) then return end
    local ok, err = pcall(fn)
    if ok then
        print("PASS  " .. name)
        passed = passed + 1
    else
        print("FAIL  " .. name .. "\n      " .. tostring(err))
        failed = failed + 1
    end
end
local function assert_eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a), 2) end
end
local function assert_true(v, msg)
    if not v then error((msg or "expected true, got falsy"), 2) end
end
local function assert_close(a, b, epsilon, msg)
    if math.abs(a - b) > epsilon then
        error((msg or "values differ") .. " expected=" .. tostring(b) .. " got=" .. tostring(a), 2)
    end
end
local function withActivePlayer(player, fn)
    local originalGetPlayer = _G.getPlayer
    _G.getPlayer = function() return player end
    local ok, err = pcall(fn)
    _G.getPlayer = originalGetPlayer
    if not ok then error(err, 0) end
end
-- Export for dofile'd test modules
_G.test = test
_G.assert_eq = assert_eq
_G.assert_true = assert_true

local function withDispatchTeardownHandler(testId, player, fn)
    local baseHandlerCount = UTCore.getTickHandlerCount()
    local eventHandlerCount = Events.OnPlayerUpdate._handlerCount()
    local state = { restored = false, teardownCount = 0, reason = nil }

    UTCore.registerTickHandler(testId, function() end, {
        teardown = function(reason)
            state.restored = true
            state.teardownCount = state.teardownCount + 1
            state.reason = reason
        end,
    })
    Events.OnCreatePlayer.fire(0, player)

    local ok, err = pcall(function()
        assert_eq(UTCore.getTickHandlerCount(), baseHandlerCount + 1,
            "test handler should be registered exactly once")
        assert_eq(UTCore.getActiveHandlerCount(), 1,
            "test handler should be the only active trait handler")
        assert_eq(Events.OnPlayerUpdate._handlerCount(), eventHandlerCount,
            "activating a trait handler must not register another event callback")
        fn(state, eventHandlerCount)
    end)

    UTCore.unregisterTickHandler(testId, "test-cleanup")
    if not ok then error(err, 0) end
    assert_eq(UTCore.getTickHandlerCount(), baseHandlerCount,
        "test cleanup should restore the registered handler count")
end

test("TickDispatch nil player tears down active handler state through registered event", function()
    local traitId = "UniversalTraits:UT_test_dispatch_nil_teardown"
    local player = MockPlayer({ traitId })
    withDispatchTeardownHandler(traitId, player, function(state, eventHandlerCount)
        Events.OnPlayerUpdate.fire(nil)
        assert_true(state.restored, "nil-player dispatch should restore handler-owned state")
        assert_eq(state.teardownCount, 1, "nil-player dispatch should teardown exactly once")
        assert_eq(state.reason, "invalid-player", "nil-player teardown reason")
        assert_eq(UTCore.getActiveHandlerCount(), 1,
            "nil-player teardown should preserve the active handler snapshot")
        assert_eq(Events.OnPlayerUpdate._handlerCount(), eventHandlerCount,
            "nil-player teardown must preserve central callback registration")
    end)
end)

test("TickDispatch dead player tears down active handler state through registered event", function()
    local traitId = "UniversalTraits:UT_test_dispatch_dead_teardown"
    local player = MockPlayer({ traitId }, { dead = true })
    withDispatchTeardownHandler(traitId, player, function(state, eventHandlerCount)
        Events.OnPlayerUpdate.fire(player)
        assert_true(state.restored, "dead-player dispatch should restore handler-owned state")
        assert_eq(state.teardownCount, 1, "dead-player dispatch should teardown exactly once")
        assert_eq(state.reason, "invalid-player", "dead-player teardown reason")
        assert_eq(UTCore.getActiveHandlerCount(), 1,
            "dead-player teardown should preserve the active handler snapshot")
        assert_eq(Events.OnPlayerUpdate._handlerCount(), eventHandlerCount,
            "dead-player teardown must preserve central callback registration")
    end)
end)

local function assertDispatchRequiresTeardown(player, label)
    local original = UTCore.teardownActiveTickHandlers
    local sentinel = label .. " teardown sentinel"
    UTCore.teardownActiveTickHandlers = function() error(sentinel, 0) end
    local ok, err = pcall(Events.OnPlayerUpdate.fire, player)
    UTCore.teardownActiveTickHandlers = original
    assert_eq(ok, false, label .. " dispatch must call the production teardown boundary")
    assert_true(tostring(err):find(sentinel, 1, true) ~= nil,
        label .. " dispatch should propagate the teardown sentinel")
end

test("TickDispatch nil-player call-site sensitivity", function()
    assertDispatchRequiresTeardown(nil, "nil-player")
end)

test("TickDispatch dead-player call-site sensitivity", function()
    assertDispatchRequiresTeardown(MockPlayer({}, { dead = true }), "dead-player")
end)

-- hasTrait
test("hasTrait returns true when player has trait", function()
    local p = MockPlayer({"UniversalTraits:UT_swift"})
    assert_eq(UTCore.hasTrait(p, "UniversalTraits:UT_swift"), true)
end)
test("hasTrait returns false when player missing trait", function()
    local p = MockPlayer({})
    assert_eq(UTCore.hasTrait(p, "UniversalTraits:UT_swift"), false)
end)
test("hasTrait returns false for nil player", function()
    assert_eq(UTCore.hasTrait(nil, "UniversalTraits:UT_swift"), false)
end)

test("invalidateTraitCache is a no-argument compatibility boundary", function()
    assert_eq(UTCore.invalidateTraitCache(), nil)
end)

test("OnCreatePlayer invokes invalidateTraitCache without arguments", function()
    local original = UTCore.invalidateTraitCache
    local callCount, argumentCount = 0, nil
    UTCore.invalidateTraitCache = function(...)
        callCount = callCount + 1
        argumentCount = select("#", ...)
    end

    local ok, err = pcall(Events.OnCreatePlayer.fire, 0, MockPlayer({}))
    UTCore.invalidateTraitCache = original
    if not ok then error(err, 0) end

    assert_eq(callCount, 1)
    assert_eq(argumentCount, 0)
end)

test("weaponHasCategory uses isOfWeaponCategory when available", function()
    local axe = MockWeapon("HandAxe", 10, false, true, { categories = { WeaponCategory.AXE } })
    assert_eq(UTCore.weaponHasCategory(axe, WeaponCategory.AXE), true)
    assert_eq(UTCore.weaponHasCategory(axe, WeaponCategory.SPEAR), false)
end)

test("getCharacterTraitId preserves the full namespaced trait identity", function()
    local trait = setmetatable({
        getName = function(self) return "ut_specmove" end
    }, {
        __tostring = function() return "universaltraits:ut_specmove" end
    })
    assert_eq(UTCore.getCharacterTraitId(trait), "universaltraits:ut_specmove")
end)

test("getCharacterTraitId retains getName and printable fallbacks", function()
    local namedTrait = {
        getName = function(self) return "UT_specmove" end
    }
    local printableTrait = setmetatable({}, {
        __tostring = function() return "diagnostic trait" end
    })
    local nameOnlyTrait = setmetatable({
        getName = function(self) return "UT_specmove" end
    }, {
        __tostring = function() error("not printable") end
    })
    assert_eq(UTCore.getCharacterTraitId(namedTrait), "UT_specmove")
    assert_eq(UTCore.getCharacterTraitId(printableTrait), "diagnostic trait")
    assert_eq(UTCore.getCharacterTraitId(nameOnlyTrait), "UT_specmove")
    assert_eq(UTCore.getCharacterTraitId(nil), "<nil>")
end)

test("getTraitDefinitionId preserves the namespaced identity from an engine-faithful definition", function()
    local trait = setmetatable({
        getName = function(self) return "UT_specaid" end
    }, {
        __tostring = function() return "UniversalTraits:UT_specaid" end
    })
    local definition = {
        getType = function(self) return trait end
    }

    assert_eq(UTCore.getTraitDefinitionId(definition), "UniversalTraits:UT_specaid")
end)

test("getTraitDefinitionId preserves nil and failed getType fallbacks", function()
    local missingGetType = setmetatable({}, {
        __tostring = function() return "UniversalTraits:UT_missing" end
    })
    local throwingGetType = setmetatable({
        getType = function(self) error("getType failed") end
    }, {
        __tostring = function() return "UniversalTraits:UT_throwing" end
    })
    local nilGetType = setmetatable({
        getType = function(self) return nil end
    }, {
        __tostring = function() return "UniversalTraits:UT_niltype" end
    })

    assert_eq(UTCore.getTraitDefinitionId(nil), "<nil>")
    assert_eq(UTCore.getTraitDefinitionId(missingGetType), "UniversalTraits:UT_missing")
    assert_eq(UTCore.getTraitDefinitionId(throwingGetType), "UniversalTraits:UT_throwing")
    assert_eq(UTCore.getTraitDefinitionId(nilGetType), "UniversalTraits:UT_niltype")
end)

test("MET nil diagnostic prints the complete selected definition identity", function()
    local trait = setmetatable({
        getName = function(self) return "UT_specaid" end
    }, {
        __tostring = function() return "UniversalTraits:UT_specaid" end
    })
    local definition = {
        getType = function(self) return trait end,
        getLabel = function(self) return "Spec Aid" end,
        getMutuallyExclusiveTraits = function(self)
            return {
                size = function(list) return 0 end,
                get = function(list, index) return nil end
            }
        end
    }
    local originalPrint = print
    local output
    print = function(message) output = message end
    local ok, err = pcall(UTCore.logCharacterCreationMetNull, definition, nil, 2, false)
    print = originalPrint
    if not ok then error(err, 0) end

    assert_eq(
        output,
        "[UT_MET_DEBUG] selected=UniversalTraits:UT_specaid label=Spec Aid removing=false nil_index=2 exclusive=<nil> mutex_list=[]"
    )
end)

test("MET crash diagnostic prints the complete selected definition identity", function()
    local trait = setmetatable({
        getName = function(self) return "UT_specaid" end
    }, {
        __tostring = function() return "UniversalTraits:UT_specaid" end
    })
    local definition = {
        getType = function(self) return trait end
    }
    local moduleName = "OptionScreens/CharacterCreationProfession"
    local originalModule = package.loaded[moduleName]
    local originalProfession = CharacterCreationProfession
    local originalDefinitionApi = CharacterTraitDefinition
    local originalDebugEnabled = UTCore.MET_DEBUG_ENABLED
    local originalPrint = print
    local output

    package.loaded[moduleName] = true
    CharacterTraitDefinition = nil
    CharacterCreationProfession = {
        doTestForMutuallyExclusiveTraits = function()
            error("vanilla MET failure", 0)
        end
    }
    UTCore.MET_DEBUG_ENABLED = true
    print = function(message) output = message end

    local ok, err = pcall(function()
        dofile(base .. "../media/lua/client/UTCore/UTCore_CharacterCreationMETDebug.lua")
        CharacterCreationProfession:doTestForMutuallyExclusiveTraits(definition, true)
    end)

    print = originalPrint
    UTCore.MET_DEBUG_ENABLED = originalDebugEnabled
    CharacterCreationProfession = originalProfession
    CharacterTraitDefinition = originalDefinitionApi
    package.loaded[moduleName] = originalModule
    if not ok then error(err, 0) end

    assert_eq(
        output,
        "[UT_MET_DEBUG] CRASH prevented in doTestForMutuallyExclusiveTraits selected=UniversalTraits:UT_specaid removing=true err=vanilla MET failure"
    )
end)

-- hasAnyTrait
test("hasAnyTrait returns true when player has one of the set", function()
    local p = MockPlayer({"UniversalTraits:UT_alcoholic_II"})
    assert_eq(UTCore.hasAnyTrait(p, {"UniversalTraits:UT_alcoholic_I","UniversalTraits:UT_alcoholic_II","UniversalTraits:UT_alcoholic_III"}), true)
end)
test("hasAnyTrait returns false when player has none", function()
    local p = MockPlayer({})
    assert_eq(UTCore.hasAnyTrait(p, {"UniversalTraits:UT_alcoholic_I","UniversalTraits:UT_alcoholic_II"}), false)
end)

-- ModData
test("getModData returns default when key absent", function()
    local p = MockPlayer()
    assert_eq(UTCore.getModData(p, "somekey", 42), 42)
end)
test("setModData/getModData round-trip", function()
    local p = MockPlayer()
    UTCore.setModData(p, "testval", "hello")
    assert_eq(UTCore.getModData(p, "testval", nil), "hello")
end)

-- applyCarryWeight
test("applyCarryWeight adds delta to base weight", function()
    local p = MockPlayer()
    UTCore.applyCarryWeight(p, 4, "test_carry")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 12)
end)

test("aggregated speed modifiers stack and clamp above zero movement", function()
    local p = MockPlayer()
    UTCore.applySpeedModifier(p, -0.6, "trait_a")
    UTCore.applySpeedModifier(p, -0.5, "trait_b")
    assert_eq(p:getModData()["UT_speedMod"], -0.75)
end)

test("carry reconciliation combines flat and strength-based bonuses without overwrite", function()
    local p = MockPlayer({}, { perkLevels = { Strength = 5 } })
    UTCore.applyCarryWeight(p, 6, "packmule")
    UTCore.applyStrengthCarryWeight(p, 4, "backpacker")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 20)
end)

test("carry reconciliation never sets inventory capacity above vanilla safe limit", function()
    _activatedMods = {}
    local calls = {}
    local inv = {
        _capacity = 50,
        getCapacity = function(self) return self._capacity end,
        setCapacity = function(self, value)
            table.insert(calls, value)
            assert_true(value <= 100, "inventory capacity write must stay at or below 100")
            self._capacity = value
        end,
    }
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 150, "bulk_test")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 158)
    assert_eq(#calls, 1)
    assert_eq(calls[1], 100)
end)

test("carry reconciliation allows high inventory capacity with RemoveInventoryLimitsZB", function()
    _activatedMods = { RemoveInventoryLimitsZB = true }
    local calls = {}
    local inv = {
        _capacity = 50,
        getCapacity = function(self) return self._capacity end,
        setCapacity = function(self, value)
            table.insert(calls, value)
            self._capacity = value
        end,
    }
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 150, "bulk_test")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 158)
    assert_eq(#calls, 1)
    assert_eq(calls[1], 158)
    _activatedMods = {}
end)

local function makeCarryOwnershipInventory(capacity, failGet, failSet)
    return {
        _capacity = capacity,
        _calls = {},
        getCapacity = function(self)
            if failGet then error("injected getCapacity failure") end
            return self._capacity
        end,
        setCapacity = function(self, value)
            if failSet then error("injected setCapacity failure") end
            self._calls[#self._calls + 1] = value
            self._capacity = value
        end,
    }
end

local function makeCarryReceiverPlayer(opts)
    opts = opts or {}
    local moddata = opts.moddata or {}
    local receiver = opts.maxWeightBase or 8
    local getFailures = opts.getFailures or 0
    local setFailures = opts.setFailures or 0
    local player = MockPlayer({}, {
        inventory = opts.inventory,
        moddata = moddata,
        perkLevels = opts.perkLevels,
    })
    player._carryReceiverWrites = {}
    player.getMaxWeightBase = function()
        if getFailures > 0 then
            getFailures = getFailures - 1
            error("injected getMaxWeightBase failure")
        end
        return receiver
    end
    player.setMaxWeightBase = function(_, value)
        if setFailures > 0 then
            setFailures = setFailures - 1
            error("injected setMaxWeightBase failure")
        end
        player._carryReceiverWrites[#player._carryReceiverWrites + 1] = value
        receiver = value
    end
    player.setExternalMaxWeightBase = function(_, value)
        receiver = value
    end
    return player
end

test("carry receiver ownership restores baseline after one flat source reaches zero", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 11 })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 12)
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 11)
    assert_eq(p:getModData().UT_carryReceiverBaseline, nil)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
end)

test("carry receiver ownership composes multiple sources then restores once", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 9 })
    UTCore.applyCarryWeight(p, 4, "first")
    UTCore.applyCarryWeight(p, 6, "second")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 18)
    UTCore.applyCarryWeight(p, nil, "second")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 12)
    UTCore.applyCarryWeight(p, nil, "first")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 9)
    assert_eq(#p._carryReceiverWrites, 3)
end)

test("carry receiver ownership treats cancelling flat entries as active", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 13 })
    UTCore.applyCarryWeight(p, 4, "positive")
    UTCore.applyCarryWeight(p, -4, "negative")
    local summary = UTCore.reconcileAggregatedModifiers(p)
    assert_eq(summary.carryTargetBase, 8)
    assert_eq(p:getMaxWeightBase(), 8)
    assert_eq(p:getModData().UT_carryReceiverBaseline, 13)
    UTCore.applyCarryWeight(p, nil, "positive")
    UTCore.applyCarryWeight(p, nil, "negative")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 13)
end)

test("carry receiver ownership composes flat and strength then restores baseline", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 7,
        perkLevels = { Strength = 5 },
    })
    UTCore.applyCarryWeight(p, 6, "flat")
    UTCore.applyStrengthCarryWeight(p, 4, "strength")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 20)
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 14)
    UTCore.applyStrengthCarryWeight(p, nil, "strength")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 7)
end)

test("carry receiver ownership invalidates on external change without reacquiring", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 8 })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 12)
    p:setExternalMaxWeightBase(31)
    UTCore.applyCarryWeight(p, 6, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 31)
    assert_eq(p:getModData().UT_carryReceiverBaseline, nil)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 31)
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 31)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
end)

test("carry receiver ownership restoration preserves external inventory capacity", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = makeCarryReceiverPlayer({ maxWeightBase = 8, inventory = inv })
    UTCore.applyCarryWeight(p, 60, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(inv._capacity, 68)
    inv._capacity = 77
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 8)
    assert_eq(inv._capacity, 77)
    assert_eq(p:getModData().UT_inventoryCapacityApplied, nil)
end)

test("carry receiver ownership reconstructs persisted current-version state", function()
    local original = makeCarryReceiverPlayer({ maxWeightBase = 10 })
    UTCore.applyCarryWeight(original, 6, "flat")
    UTCore.reconcileAggregatedModifiers(original)
    assert_eq(original:getMaxWeightBase(), 14)

    local persisted = original:getModData()
    local loaded = makeCarryReceiverPlayer({ maxWeightBase = 14, moddata = persisted })
    UTCore.applyCarryWeight(loaded, nil, "flat")
    UTCore.reconcileAggregatedModifiers(loaded)
    assert_eq(loaded:getMaxWeightBase(), 10)
    assert_eq(loaded:getModData().UT_carryReceiverActive, nil)
end)

test("carry receiver ownership is isolated across player replacement", function()
    local first = makeCarryReceiverPlayer({ maxWeightBase = 10 })
    UTCore.applyCarryWeight(first, 4, "flat")
    UTCore.reconcileAggregatedModifiers(first)
    local replacement = makeCarryReceiverPlayer({ maxWeightBase = 23 })
    UTCore.applyCarryWeight(replacement, 4, "flat")
    UTCore.reconcileAggregatedModifiers(replacement)
    assert_eq(first:getModData().UT_carryReceiverBaseline, 10)
    assert_eq(replacement:getModData().UT_carryReceiverBaseline, 23)
end)

test("carry receiver ownership getter and setter failures preserve retry evidence", function()
    local getFailure = makeCarryReceiverPlayer({ maxWeightBase = 8, getFailures = 1 })
    UTCore.applyCarryWeight(getFailure, 4, "flat")
    assert_true(pcall(UTCore.reconcileAggregatedModifiers, getFailure))
    assert_eq(getFailure:getModData().UT_carryReceiverActive, nil)
    UTCore.reconcileAggregatedModifiers(getFailure)
    assert_eq(getFailure:getMaxWeightBase(), 12)

    local setFailure = makeCarryReceiverPlayer({ maxWeightBase = 9, setFailures = 1 })
    UTCore.applyCarryWeight(setFailure, 4, "flat")
    assert_true(pcall(UTCore.reconcileAggregatedModifiers, setFailure))
    assert_eq(setFailure:getModData().UT_carryReceiverActive, true)
    assert_eq(setFailure:getModData().UT_carryReceiverBaseline, 9)
    assert_eq(setFailure:getModData().UT_carryReceiverLastApplied, 9)
    UTCore.reconcileAggregatedModifiers(setFailure)
    assert_eq(setFailure:getMaxWeightBase(), 12)
end)

test("carry receiver ownership final restoration failure remains retryable", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 8 })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    p.setMaxWeightBase = function()
        p.setMaxWeightBase = function(_, value)
            p._carryReceiverWrites[#p._carryReceiverWrites + 1] = value
            p.setExternalMaxWeightBase(p, value)
        end
        error("injected restoration failure")
    end
    UTCore.applyCarryWeight(p, nil, "flat")
    assert_true(pcall(UTCore.reconcileAggregatedModifiers, p))
    assert_eq(p:getModData().UT_carryReceiverActive, true)
    assert_eq(p:getModData().UT_carryReceiverBaseline, 8)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, 12)
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 8)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
end)

test("carry receiver ownership repeated removal is idempotent", function()
    local p = makeCarryReceiverPlayer({ maxWeightBase = 10 })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 10)
    assert_eq(#p._carryReceiverWrites, 2)
end)

test("carry receiver ownership malformed buckets do not invent ownership", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 17,
        moddata = {
            UT_modifierBucketsVersion = 2,
            UT_modifierBuckets = {
                carryFlatAdd = "malformed",
                carryStrengthAdd = false,
            },
        },
    })
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 17)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
    assert_eq(p:getModData().UT_carryReceiverBaseline, nil)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
end)

test("carry receiver ownership rejects non-boolean active markers", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 19,
        moddata = { UT_carryReceiverActive = "true" },
    })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 19)
    assert_eq(#p._carryReceiverWrites, 0)
    assert_eq(p:getModData().UT_carryReceiverActive, "true")
end)

test("carry receiver ownership rejects partial tuples", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 21,
        moddata = {
            UT_carryReceiverActive = true,
            UT_carryReceiverBaseline = 8,
        },
    })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 21)
    assert_eq(#p._carryReceiverWrites, 0)
    assert_eq(p:getModData().UT_carryReceiverBaseline, 8)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
end)

test("carry receiver ownership rejects malformed baseline and last values", function()
    local cases = {
        { baseline = "8", lastApplied = 12 },
        { baseline = 8, lastApplied = "12" },
        { baseline = 0 / 0, lastApplied = 12 },
        { baseline = 8, lastApplied = math.huge },
    }
    for index, values in ipairs(cases) do
        local p = makeCarryReceiverPlayer({
            maxWeightBase = 22 + index,
            moddata = {
                UT_carryReceiverActive = true,
                UT_carryReceiverBaseline = values.baseline,
                UT_carryReceiverLastApplied = values.lastApplied,
            },
        })
        UTCore.applyCarryWeight(p, 4, "flat")
        UTCore.reconcileAggregatedModifiers(p)
        assert_eq(p:getMaxWeightBase(), 22 + index, "malformed case " .. tostring(index))
        assert_eq(#p._carryReceiverWrites, 0, "malformed case " .. tostring(index))
    end
end)

test("carry receiver ownership preserves foreign receiver for inconsistent tuples", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 27,
        moddata = {
            UT_carryReceiverActive = false,
            UT_carryReceiverBaseline = 8,
            UT_carryReceiverLastApplied = 12,
        },
    })
    UTCore.applyCarryWeight(p, 6, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 27)
    assert_eq(#p._carryReceiverWrites, 0)
    assert_eq(p:getModData().UT_carryReceiverActive, false)
    assert_eq(p:getModData().UT_carryReceiverBaseline, 8)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, 12)
end)

test("carry receiver ownership clears malformed metadata only at zero sources", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 29,
        moddata = {
            UT_carryReceiverActive = "invalid",
            UT_carryReceiverBaseline = 8,
        },
    })
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getModData().UT_carryReceiverActive, "invalid")
    UTCore.applyCarryWeight(p, nil, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 29)
    assert_eq(#p._carryReceiverWrites, 0)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
    assert_eq(p:getModData().UT_carryReceiverBaseline, nil)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
end)

test("carry receiver ownership reacquires after zero-source malformed cleanup", function()
    local p = makeCarryReceiverPlayer({
        maxWeightBase = 31,
        moddata = {
            UT_carryReceiverActive = true,
            UT_carryReceiverLastApplied = "invalid",
        },
    })
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getModData().UT_carryReceiverActive, nil)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, nil)
    UTCore.applyCarryWeight(p, 4, "flat")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 12)
    assert_eq(p:getModData().UT_carryReceiverActive, true)
    assert_eq(p:getModData().UT_carryReceiverBaseline, 31)
    assert_eq(p:getModData().UT_carryReceiverLastApplied, 12)
end)

test("carry ownership initial below-floor reconciliation records the applied floor", function()
    local inv = makeCarryOwnershipInventory(12)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(inv._capacity, 50)
    assert_eq(p:getModData().UT_inventoryCapacityApplied, 50)
end)

test("carry ownership raise records the exact UTCore-applied capacity", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 52, "raise")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(inv._capacity, 60)
    assert_eq(p:getModData().UT_inventoryCapacityApplied, 60)
end)

test("carry ownership safely lowers a capacity still owned by UTCore", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 52, "dynamic")
    UTCore.reconcileAggregatedModifiers(p)
    UTCore.applyCarryWeight(p, 42, "dynamic")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(inv._capacity, 50)
    assert_eq(p:getModData().UT_inventoryCapacityApplied, 50)
end)

test("carry ownership never lowers a capacity changed by an external owner", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 52, "dynamic")
    UTCore.reconcileAggregatedModifiers(p)
    inv._capacity = 55
    UTCore.applyCarryWeight(p, 42, "dynamic")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(inv._capacity, 55)
    assert_eq(p:getModData().UT_inventoryCapacityApplied, nil)
end)

test("carry ownership repeated identical reconciliation is idempotent", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 52, "dynamic")
    UTCore.reconcileAggregatedModifiers(p)
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(#inv._calls, 1)
    assert_eq(inv._calls[1], 60)
end)

test("carry ownership composes flat and strength carry sources", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv, perkLevels = { Strength = 5 } })
    UTCore.applyCarryWeight(p, 60, "flat")
    UTCore.applyStrengthCarryWeight(p, 4, "strength")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 74)
    assert_eq(inv._capacity, 74)
end)

test("carry ownership source removal lowers to the remaining composed target", function()
    local inv = makeCarryOwnershipInventory(50)
    local p = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(p, 60, "persistent")
    UTCore.applyCarryWeight(p, 10, "temporary")
    UTCore.reconcileAggregatedModifiers(p)
    UTCore.applyCarryWeight(p, nil, "temporary")
    UTCore.reconcileAggregatedModifiers(p)
    assert_eq(p:getMaxWeightBase(), 68)
    assert_eq(inv._capacity, 68)
end)

test("carry ownership does not transfer to a replacement player", function()
    local firstInv = makeCarryOwnershipInventory(50)
    local first = MockPlayer({}, { inventory = firstInv })
    UTCore.applyCarryWeight(first, 60, "first")
    UTCore.reconcileAggregatedModifiers(first)

    local replacementInv = makeCarryOwnershipInventory(68)
    local replacement = MockPlayer({}, { inventory = replacementInv })
    UTCore.applyCarryWeight(replacement, 42, "replacement")
    UTCore.reconcileAggregatedModifiers(replacement)
    assert_eq(replacementInv._capacity, 68)
    assert_eq(replacement:getModData().UT_inventoryCapacityApplied, nil)
end)

test("carry ownership reconstructs from persisted player state after save load", function()
    local inv = makeCarryOwnershipInventory(50)
    local original = MockPlayer({}, { inventory = inv })
    UTCore.applyCarryWeight(original, 60, "persistent")
    UTCore.applyCarryWeight(original, 10, "temporary")
    UTCore.reconcileAggregatedModifiers(original)
    assert_eq(original:getMaxWeightBase(), 78)
    assert_eq(inv._capacity, 78)
    assert_eq(original:getModData().UT_inventoryCapacityApplied, 78)

    local loadedInv = makeCarryOwnershipInventory(78)
    local loaded = MockPlayer({}, { inventory = loadedInv })
    for key, value in pairs(original:getModData()) do
        loaded:getModData()[key] = value
    end
    loaded:setMaxWeightBase(78)
    assert_eq(loaded:getModData().UT_inventoryCapacityApplied, 78)
    UTCore.applyCarryWeight(loaded, nil, "temporary")
    assert_eq(loaded:getModData().UT_carryTargetBase, 68)
    assert_eq(loaded:getModData().UT_inventoryCapacityApplied, 78)
    UTCore.reconcileAggregatedModifiers(loaded)
    assert_eq(loadedInv._capacity, 68)
    assert_eq(loaded:getModData().UT_inventoryCapacityApplied, 68)
end)

test("carry ownership tolerates nil missing inventory and bridge failures", function()
    assert_eq(UTCore.reconcileAggregatedModifiers(nil), nil)
    assert_eq(UTCore.reconcileAggregatedModifiers({}), nil)
    UTCore.reconcileAggregatedModifiers(MockPlayer())

    local getFailure = MockPlayer({}, {
        inventory = makeCarryOwnershipInventory(20, true, false),
    })
    assert_true(pcall(UTCore.reconcileAggregatedModifiers, getFailure))

    local setFailureInv = makeCarryOwnershipInventory(20, false, true)
    local setFailure = MockPlayer({}, { inventory = setFailureInv })
    assert_true(pcall(UTCore.reconcileAggregatedModifiers, setFailure))
    assert_eq(setFailure:getModData().UT_inventoryCapacityApplied, nil)
end)

test("carry ownership safely rejects a nil moddata return", function()
    local player = {
        getModData = function() return nil end,
    }
    assert_eq(UTCore.refreshAggregatedModifierCache(player), nil)
    assert_eq(UTCore.reconcileAggregatedModifiers(player), nil)
end)

test("carry ownership safely rejects a throwing getModData bridge", function()
    local player = {
        getModData = function() error("injected getModData failure") end,
    }
    assert_eq(UTCore.refreshAggregatedModifierCache(player), nil)
    assert_eq(UTCore.reconcileAggregatedModifiers(player), nil)
end)

test("carry ownership source and release files have byte parity", function()
    local sourcePath = base .. "../media/lua/shared/UTCore/UTCore_StatModifiers.lua"
    local releasePath = base .. "../release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_StatModifiers.lua"
    local sourceFile = assert(io.open(sourcePath, "rb"))
    local releaseFile = assert(io.open(releasePath, "rb"))
    local sourceBytes = sourceFile:read("*a")
    local releaseBytes = releaseFile:read("*a")
    sourceFile:close()
    releaseFile:close()
    assert_eq(sourceBytes, releaseBytes)
end)

-- applyBleedRate
test("applyBleedRate stores multiplier in moddata", function()
    local p = MockPlayer()
    UTCore.applyBleedRate(p, 1.5)
    assert_eq(p:getModData()["UT_bleedMult"], 1.5)
end)

local function makeBleedDrainEventPlayer(multiplier, modifiers, healths)
    local calls = {}
    modifiers = modifiers or { 0.5, 2.0 }
    healths = healths or { 50.0, 50.0 }
    local parts = {}
    for index, health in ipairs(healths) do
        parts[index] = {
            health = health,
            getHealth = function(self) return self.health end,
            AddHealth = function(self, amount)
                calls[#calls + 1] = {
                    method = "AddHealth",
                    index = index - 1,
                    amount = amount,
                }
                self.health = self.health + amount
            end,
        }
    end
    local bodyParts = {
        size = function() return #parts end,
        get = function(_, index) return parts[index + 1] end,
    }
    local bodyDamage = {
        getBodyParts = function()
            return bodyParts
        end,
        ReduceGeneralHealth = function(_, amount)
            calls[#calls + 1] = { method = "ReduceGeneralHealth", amount = amount }
        end,
    }
    local player = {
        getModData = function()
            return { UT_bleedDrainMult = multiplier }
        end,
        getBodyDamage = function()
            return bodyDamage
        end,
    }
    BodyPartType._damageModifiers = modifiers
    return player, calls, parts
end

test("OnPlayerGetDamage restores exact weighted BodyDamage loss", function()
    local modifiers = { 0.5, 2.0 }
    local player, calls, parts = makeBleedDrainEventPlayer(
        0.5,
        modifiers,
        { 70.0, 87.5 }
    )
    local before = { parts[1].health, parts[2].health }

    local ok, err = pcall(Events.OnPlayerGetDamage.fire, player, "BLEEDING", 10.0)
    assert_eq(ok, true, "finite event call must not error: " .. tostring(err))
    assert_eq(#calls, 2, "each native BodyDamage share must be inverted")
    assert_eq(calls[1].method, "AddHealth")
    assert_eq(calls[2].method, "AddHealth")
    assert_close(calls[1].amount, 5.0, 0.0000001, "low-weight part inverse")
    assert_close(calls[2].amount, 1.25, 0.0000001, "high-weight part inverse")

    local weightedRecovery = 0.0
    for index, modifier in ipairs(modifiers) do
        weightedRecovery = weightedRecovery + (parts[index].health - before[index]) * modifier
    end
    assert_close(weightedRecovery, 5.0, 0.0000001, "0.5x must restore exactly half the native loss")
end)

test("OnPlayerGetDamage applies exact additional weighted BodyDamage loss", function()
    local player, calls = makeBleedDrainEventPlayer(2.0)
    local ok, err = pcall(Events.OnPlayerGetDamage.fire, player, "BLEEDING", 10.0)
    assert_eq(ok, true, "finite event call must not error: " .. tostring(err))
    assert_eq(#calls, 1)
    assert_eq(calls[1].method, "ReduceGeneralHealth")
    assert_eq(calls[1].amount, 10.0)
end)

test("OnPlayerGetDamage validates the full inverse plan before healing", function()
    local player, calls = makeBleedDrainEventPlayer(0.5, { 0.5, 0.0 })
    local ok, err = pcall(Events.OnPlayerGetDamage.fire, player, "BLEEDING", 10.0)
    assert_eq(ok, true, "invalid bridge data must not error: " .. tostring(err))
    assert_eq(#calls, 0, "one invalid body-part modifier must prevent partial healing")
end)

test("OnPlayerGetDamage never heals an already zero-health body part", function()
    local player, calls, parts = makeBleedDrainEventPlayer(
        0.5,
        { 0.5, 2.0 },
        { 0.0, 87.5 }
    )
    local ok, err = pcall(Events.OnPlayerGetDamage.fire, player, "BLEEDING", 10.0)
    assert_eq(ok, true, "clamped body-part state must not error: " .. tostring(err))
    assert_eq(#calls, 1, "only the nonzero body part may be restored")
    assert_eq(calls[1].index, 1)
    assert_close(parts[1].health, 0.0, 0.0000001, "unrelated destroyed part must remain destroyed")
    assert_close(parts[2].health, 88.75, 0.0000001, "unclamped native share remains exact")
end)

test("OnPlayerGetDamage rejects non-finite damage and invalid multipliers", function()
    local nan = 0 / 0
    local cases = {
        { name = "nonnumber damage", damage = "10", multiplier = 0.5 },
        { name = "NaN damage", damage = nan, multiplier = 0.5 },
        { name = "positive infinite damage", damage = math.huge, multiplier = 0.5 },
        { name = "negative infinite damage", damage = -math.huge, multiplier = 0.5 },
        { name = "nonnumber multiplier", damage = 10.0, multiplier = "0.5" },
        { name = "NaN multiplier", damage = 10.0, multiplier = nan },
        { name = "positive infinite multiplier", damage = 10.0, multiplier = math.huge },
        { name = "negative infinite multiplier", damage = 10.0, multiplier = -math.huge },
        { name = "negative multiplier", damage = 10.0, multiplier = -0.5 },
        { name = "identity multiplier", damage = 10.0, multiplier = 1.0 },
        { name = "overflow-produced infinite adjustment", damage = 1e308, multiplier = 1e308 },
    }

    for _, case in ipairs(cases) do
        local player, calls = makeBleedDrainEventPlayer(case.multiplier)
        local ok, err = pcall(Events.OnPlayerGetDamage.fire, player, "BLEEDING", case.damage)
        assert_eq(ok, true, case.name .. " must not error: " .. tostring(err))
        assert_eq(#calls, 0, case.name .. " must not call a health adjustment")
    end
end)

-- applyXPMultiplier
test("applyXPMultiplier stores in moddata", function()
    local p = MockPlayer()
    UTCore.applyXPMultiplier(p, "Aiming", 2.0)
    assert_eq(p:getModData()["UT_xpMult_Aiming"], 2.0)
end)

test("applyWetnessReductionProfile stores wetness values in moddata", function()
    local p = MockPlayer()
    UTCore.applyWetnessReductionProfile(p, 3.0, 1.5, 0.5)
    assert_eq(p:getModData()["UT_wetnessReductionIndoor"], 3.0)
    assert_eq(p:getModData()["UT_wetnessReductionOutdoor"], 1.5)
    assert_eq(p:getModData()["UT_wetnessReductionRain"], 0.5)
end)

test("applyThermalRegulationProfile stores thermal values in moddata", function()
    local p = MockPlayer()
    UTCore.applyThermalRegulationProfile(p, 37.0, 37.2, 37.7, 0.08, 0.12)
    assert_eq(p:getModData()["UT_thermalComfortFloor"], 37.0)
    assert_eq(p:getModData()["UT_thermalWarmThreshold"], 37.2)
    assert_eq(p:getModData()["UT_thermalHotThreshold"], 37.7)
    assert_eq(p:getModData()["UT_thermalWarmCooling"], 0.08)
    assert_eq(p:getModData()["UT_thermalHotCooling"], 0.12)
end)

-- disableXP
test("disableXP stores flag in moddata", function()
    local p = MockPlayer()
    UTCore.disableXP(p, "Shotgun")
    assert_eq(p:getModData()["UT_xpDisable_Shotgun"], true)
end)

-- applySpawnStats
test("applySpawnStats sets panic via stats", function()
    local p = MockPlayer()
    UTCore.applySpawnStats(p, { panic = 0.75 })
    assert_eq(p:getStats():get(CharacterStat.PANIC), 0.75)
end)

-- registerPeriodicHandler
local function withPeriodicHandlerSandbox(eventsValue, listenerLists, fn)
    local originalEvents = _G.Events
    local originalRegistry = UTCore._periodicHandlers
    local snapshots = {}
    for index, listeners in ipairs(listenerLists or {}) do
        snapshots[index] = {}
        for itemIndex, listener in ipairs(listeners) do
            snapshots[index][itemIndex] = listener
        end
    end

    _G.Events = eventsValue
    UTCore._periodicHandlers = {}
    local ok, err = pcall(fn, UTCore._periodicHandlers)

    for index, listeners in ipairs(listenerLists or {}) do
        for itemIndex = #listeners, 1, -1 do
            listeners[itemIndex] = nil
        end
        for itemIndex, listener in ipairs(snapshots[index]) do
            listeners[itemIndex] = listener
        end
    end
    UTCore._periodicHandlers = originalRegistry
    _G.Events = originalEvents

    if not ok then error(err, 0) end
end

local function assertPeriodicRegistrationError(eventsValue, expectedMessage, listenerLists)
    withPeriodicHandlerSandbox(eventsValue, listenerLists, function(registry)
        registry.preexisting = "unchanged"
        local ok, err = pcall(
            UTCore.registerPeriodicHandler,
            "negative_contract_trait",
            "MissingEvent",
            function() end
        )
        assert_eq(UTCore._periodicHandlers, registry, "failed registration must preserve registry identity")
        assert_eq(ok, false, "registration must reject an invalid event contract")
        err = tostring(err)
        assert_eq(err:sub(-#expectedMessage), expectedMessage, "unexpected registration error")
        assert_eq(registry.preexisting, "unchanged", "existing registry state must remain unchanged")
        assert_eq(registry["negative_contract_trait::MissingEvent"], nil, "failed registration must not create an entry")
        for _, listeners in ipairs(listenerLists or {}) do
            assert_eq(#listeners, 1, "failed registration must not mutate event listeners")
            assert_eq(listeners[1], "preexisting", "failed registration must preserve existing listeners")
        end
    end)
end

test("registerPeriodicHandler rejects an unavailable event before mutation", function()
    assertPeriodicRegistrationError(
        {},
        "UTCore periodic handler event is unavailable: MissingEvent"
    )
end)

test("registerPeriodicHandler rejects missing Events before mutation", function()
    assertPeriodicRegistrationError(
        nil,
        "UTCore periodic handler Events table is unavailable"
    )
end)

test("registerPeriodicHandler rejects non-table Events before mutation", function()
    assertPeriodicRegistrationError(
        "not an event table",
        "UTCore periodic handler Events table is unavailable"
    )
end)

test("registerPeriodicHandler rejects a non-table named event before mutation", function()
    assertPeriodicRegistrationError(
        { MissingEvent = "not an event" },
        "UTCore periodic handler event is unavailable: MissingEvent"
    )
end)

test("registerPeriodicHandler rejects non-callable Add before mutation", function()
    local listeners = { "preexisting" }
    assertPeriodicRegistrationError(
        { MissingEvent = { Add = true, Remove = function() end } },
        "UTCore periodic handler event Add is not callable: MissingEvent",
        { listeners }
    )
end)

test("registerPeriodicHandler rejects non-callable Remove before mutation", function()
    local listeners = { "preexisting" }
    assertPeriodicRegistrationError(
        {
            MissingEvent = {
                Add = function(listener) listeners[#listeners + 1] = listener end,
                Remove = true,
            },
        },
        "UTCore periodic handler event Remove is not callable: MissingEvent",
        { listeners }
    )
end)

test("registerPeriodicHandler accepts a complete event contract", function()
    local listeners = { "preexisting" }
    local event = {
        Add = function(listener) listeners[#listeners + 1] = listener end,
        Remove = function(listener)
            for index, existing in ipairs(listeners) do
                if existing == listener then
                    table.remove(listeners, index)
                    return
                end
            end
        end,
    }
    withPeriodicHandlerSandbox({ TestEvent = event }, { listeners }, function(registry)
        local registered = UTCore.registerPeriodicHandler("success_contract_trait", "TestEvent", function() end)
        assert_eq(registered, true)
        assert_true(registry["success_contract_trait::TestEvent"] ~= nil)
        assert_eq(#listeners, 2)
        assert_eq(type(listeners[2]), "function")
    end)
end)

test("registerPeriodicHandler stores handler", function()
    UTCore._periodicHandlers = {}
    UTCore.registerPeriodicHandler("test_trait", "EveryOneMinute", function(player) end)
    assert_eq(UTCore._periodicHandlers["test_trait::EveryOneMinute"] ~= nil, true)
end)

-- registerPeriodicHandler idempotent
test("registerPeriodicHandler is idempotent", function()
    UTCore._periodicHandlers = {}
    local fn = function(player) end
    UTCore.registerPeriodicHandler("test_trait", "EveryOneMinute", fn)
    UTCore.registerPeriodicHandler("test_trait", "EveryOneMinute", fn)
    local count = 0
    for _ in pairs(UTCore._periodicHandlers) do count = count + 1 end
    assert_eq(count, 1)
end)

test("registerPeriodicHandler allows multiple events for one trait", function()
    UTCore._periodicHandlers = {}
    UTCore.registerPeriodicHandler("test_trait", "EveryOneMinute", function(player) end)
    UTCore.registerPeriodicHandler("test_trait", "OnPlayerUpdate", function(player) end)
    local count = 0
    for _ in pairs(UTCore._periodicHandlers) do count = count + 1 end
    assert_eq(count, 2, "expected one handler per trait+event pair")
end)

-- unregisterPeriodicHandler
test("unregisterPeriodicHandler removes handler", function()
    UTCore._periodicHandlers = {}
    UTCore.registerPeriodicHandler("test_trait2", "EveryTenMinutes", function(player) end)
    UTCore.unregisterPeriodicHandler("test_trait2")
    assert_eq(UTCore._periodicHandlers["test_trait2"], nil)
end)

test("ThermalRegulationHook selects indoor, dry-outdoor, and rainy-outdoor wetness reductions", function()
    local originalRainManager = _G.RainManager
    local originalIsRaining = _G.isRaining
    local originalPrecipitation = _mockClimate.precipitationIntensity
    local originalClouds = _mockClimate.cloudIntensity
    local originalGetPlayer = _G.getPlayer
    local originalEveryOneMinute = _G.Events.EveryOneMinute
    local activePlayer

    _G.isRaining = function()
        error("ThermalRegulationHook must call RainManager.isRaining()", 0)
    end
    _G.getPlayer = function() return activePlayer end

    local ok, err = pcall(function()
        local cases = {
            { name = "indoors", outside = false, precipitation = 0.0, expected = 47 },
            { name = "dry outdoors", outside = true, precipitation = 0.0, expected = 48.5 },
            { name = "rainy outdoors", outside = true, precipitation = 0.5, expected = 49.5 },
        }

        for _, case in ipairs(cases) do
            setMockClimate(case.precipitation, 0.5)
            activePlayer = MockPlayer({}, { outside = case.outside })
            activePlayer:getStats():set(CharacterStat.WETNESS, 50)
            UTCore.applyWetnessReductionProfile(activePlayer, 3.0, 1.5, 0.5)
            Events.EveryOneMinute:fire()
            assert_eq(
                activePlayer:getStats():get(CharacterStat.WETNESS),
                case.expected,
                "unexpected wetness after " .. case.name .. " event"
            )
        end
    end)

    _G.RainManager = originalRainManager
    _G.isRaining = originalIsRaining
    _mockClimate.precipitationIntensity = originalPrecipitation
    _mockClimate.cloudIntensity = originalClouds
    _G.getPlayer = originalGetPlayer
    _G.Events.EveryOneMinute = originalEveryOneMinute
    activePlayer = nil

    if not ok then error(err, 0) end
end)

test("ThermalRegulationHook cools mild overheating when configured", function()
    local p = MockPlayer({}, { bodyTemp = 37.4 })
    UTCore.applyThermalRegulationProfile(p, 37.0, 37.2, 37.7, 0.08, 0.12)
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local temp = p:getStats():get(CharacterStat.TEMPERATURE)
    assert_true(math.abs(temp - 37.32) < 0.0001, "expected mild overheating to cool by 0.08")
end)

test("ThermalRegulationHook cools strong overheating when configured", function()
    local p = MockPlayer({}, { bodyTemp = 37.9 })
    UTCore.applyThermalRegulationProfile(p, 37.0, 37.2, 37.7, 0.08, 0.12)
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local temp = p:getStats():get(CharacterStat.TEMPERATURE)
    assert_true(math.abs(temp - 37.78) < 0.0001, "expected strong overheating to cool by 0.12")
end)

test("ThermalRegulationHook skips while sleeping", function()
    local p = MockPlayer({}, { bodyTemp = 37.9, sleeping = true })
    p:getStats():set(CharacterStat.WETNESS, 50)
    UTCore.applyWetnessReductionProfile(p, 3.0, 1.5, 0.5)
    UTCore.applyThermalRegulationProfile(p, 37.0, 37.2, 37.7, 0.08, 0.12)
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.WETNESS), 50, "wetness unchanged while sleeping")
    assert_true(math.abs(p:getStats():get(CharacterStat.TEMPERATURE) - 37.9) < 0.0001, "temperature unchanged while sleeping")
end)

-- XPHook: XP multiplier
test("XPHook applies XP multiplier", function()
    local p = MockPlayer({})
    p:getModData()["UT_xpMult_Aiming"] = 1.5
    Events.AddXP.fire(p, "Aiming", 10)
    local calls = p:getXpCalls()
    local bonus = nil
    for _, c in ipairs(calls) do
        if c.perk == "Aiming" then bonus = c.amount end
    end
    assert_eq(bonus, 5, "XP multiplier 1.5x on 10 should add +5 bonus")
end)

test("XPHook applies global XP multiplier", function()
    local p = MockPlayer({})
    p:getModData()["UT_xpMult_All"] = 1.5
    Events.AddXP.fire(p, "Cooking", 10)
    local calls = p:getXpCalls()
    local bonus = nil
    for _, c in ipairs(calls) do
        if c.perk == "Cooking" then bonus = c.amount end
    end
    assert_eq(bonus, 5, "global XP multiplier 1.5x on 10 should add +5 bonus")
end)

-- XPHook: XP disable
test("XPHook cancels XP when disabled", function()
    local p = MockPlayer()
    p:getModData()["UT_xpDisable_Aiming"] = true
    Events.AddXP.fire(p, "Aiming", 10)
    local calls = p:getXpCalls()
    local found = false
    for _, c in ipairs(calls) do
        if c.perk == "Aiming" and c.amount == -10 then found = true end
    end
    assert_eq(found, true, "expected -10 cancellation for disabled XP ")
end)

-- XPHook: multi-skill penalty fires for 2nd perk
test("XPHook multi-skill penalty fires for 2nd perk", function()
    UTCore._xpPerksThisMinute = {}  -- reset module-level tracking
    local p = MockPlayer()
    p:getModData()["UT_multiSkillPenalty"] = true
    Events.AddXP.fire(p, "Aiming", 10)
    Events.AddXP.fire(p, "Reloading", 10)
    local calls = p:getXpCalls()
    local foundNeg = false
    for _, c in ipairs(calls) do
        if c.perk == "Reloading" and c.amount < 0 then foundNeg = true end
    end
    assert_eq(foundNeg, true, "expected negative XP correction on 2nd perk ")
end)

-- XPHook: multi-skill penalty skips single perk
test("XPHook multi-skill penalty skips single perk", function()
    UTCore._xpPerksThisMinute = {}  -- reset module-level tracking
    local p = MockPlayer()
    p:getModData()["UT_multiSkillPenalty"] = true
    Events.AddXP.fire(p, "Aiming", 10)
    local calls = p:getXpCalls()
    local foundNeg = false
    for _, c in ipairs(calls) do
        if c.perk == "Aiming" and c.amount < 0 then foundNeg = true end
    end
    assert_eq(foundNeg, false, "expected no negative correction for single perk ")
end)

-- XPHook: mult and multi-skill penalty are independent
test("XPHook mult and multi-skill penalty are independent", function()
    UTCore._xpPerksThisMinute = {}  -- reset state
    local p = MockPlayer({})
    p:getModData()["UT_xpMult_Aiming"] = 2.0      -- +10 bonus
    p:getModData()["UT_multiSkillPenalty"] = true
    Events.AddXP.fire(p, "Aiming", 10)    -- first perk, no penalty yet
    Events.AddXP.fire(p, "Reloading", 10) -- second perk, penalty fires
    -- Net for Reloading: original 10 + no mult for Reloading + -5 penalty
    local reloadingNet = 0
    for _, c in ipairs(p:getXpCalls()) do
        if c.perk == "Reloading" then reloadingNet = reloadingNet + c.amount end
    end
    assert_eq(reloadingNet, -5, "penalty on 2nd perk should be -5 (50% of 10)")
end)

-- XPHook: amount <= 0 guard
test("XPHook ignores zero or negative XP events", function()
    local p = MockPlayer({})
    p:getModData()["UT_xpMult_Aiming"] = 2.0
    Events.AddXP.fire(p, "Aiming", 0)
    assert_eq(#p:getXpCalls(), 0, "zero XP event should produce no corrections")
end)

-- XPHook: skill cap enforcement (UT_skillCapReduction / UT_incomprehensive)
test("XPHook blocks XP when player is at or above the skill cap", function()
    -- UT_skillCapReduction = 2  →  hardCap = 10 - 2 = 8
    local p = MockPlayer({}, { perkLevels = { Aiming = 8 } })
    p:getModData()["UT_skillCapReduction"] = 2
    Events.AddXP.fire(p, "Aiming", 10)
    local blocked = false
    for _, c in ipairs(p:getXpCalls()) do
        if c.perk == "Aiming" and c.amount == -10 then blocked = true end
    end
    assert_eq(blocked, true, "XP should be negated at perk level 8 with cap reduction of 2")
end)

test("XPHook allows XP when player is below the skill cap", function()
    -- UT_skillCapReduction = 2  →  hardCap = 8; level 7 is below cap
    local p = MockPlayer({}, { perkLevels = { Aiming = 7 } })
    p:getModData()["UT_skillCapReduction"] = 2
    Events.AddXP.fire(p, "Aiming", 10)
    local blocked = false
    for _, c in ipairs(p:getXpCalls()) do
        if c.perk == "Aiming" and c.amount == -10 then blocked = true end
    end
    assert_eq(blocked, false, "XP should not be blocked at perk level 7 when cap is 8")
end)

test("XPHook does not apply skill cap without UT_skillCapReduction set", function()
    local p = MockPlayer({}, { perkLevels = { Aiming = 9 } })
    Events.AddXP.fire(p, "Aiming", 10)
    local blocked = false
    for _, c in ipairs(p:getXpCalls()) do
        if c.perk == "Aiming" and c.amount < 0 then blocked = true end
    end
    assert_eq(blocked, false, "no cap should apply when UT_skillCapReduction is not set")
end)

-- XPHook: Java enum object regression (Kahlua __concat crash)
-- These tests pass a MockJavaPerk (table with __tostring, no __concat) as the perk
-- argument - the same type the real PZ engine sends. If any XPHook code path uses
-- '..' directly on `perk` instead of tostring(perk), it crashes here in standard Lua
-- exactly as it would crash in Kahlua with "__concat not defined for operands".

test("XPHook disable path does not crash on Java enum perk object", function()
    local p = MockPlayer({})
    local perkObj = MockJavaPerk("Cooking")
    p:getModData()["UT_xpDisable_Cooking"] = true
    Events.AddXP.fire(p, perkObj, 10)
    local cancelled = false
    for _, c in ipairs(p:getXpCalls()) do
        if tostring(c.perk) == "Cooking" and c.amount == -10 then cancelled = true end
    end
    assert_eq(cancelled, true, "XP disable should cancel via tostring(perk) key lookup")
end)

test("XPHook multiplier path does not crash on Java enum perk object", function()
    local p = MockPlayer({})
    local perkObj = MockJavaPerk("Doctor")
    p:getModData()["UT_xpMult_Doctor"] = 2.0
    Events.AddXP.fire(p, perkObj, 10)
    local bonus = nil
    for _, c in ipairs(p:getXpCalls()) do
        if tostring(c.perk) == "Doctor" then bonus = c.amount end
    end
    assert_eq(bonus, 10, "XP multiplier 2x on 10 should add +10 bonus via tostring(perk) key")
end)

test("XPHook skill cap path does not crash on Java enum perk object", function()
    local perkObj = MockJavaPerk("Aiming")
    -- perkObj is used as the table key so UTCoreMocks getPerkLevel(p, perkObj) → 8
    local p = MockPlayer({}, { perkLevels = { [perkObj] = 8 } })
    p:getModData()["UT_skillCapReduction"] = 2
    Events.AddXP.fire(p, perkObj, 10)
    local blocked = false
    for _, c in ipairs(p:getXpCalls()) do
        if tostring(c.perk) == "Aiming" and c.amount == -10 then blocked = true end
    end
    assert_eq(blocked, true, "skill cap should block XP via tostring(perk) key when perk is a Java enum object")
end)

-- =====================================================================
-- SpeedHook tests (delta-scaling via nextX/nextY)
-- These simulate the engine frame pipeline:
--   1. moveTo(x,y) sets x and nextX to the same value (like preupdate)
--   2. setNextX(x + delta) simulates doDeferredMovement adding animation delta
--   3. Events.OnPlayerMove.fire() runs the SpeedHook
--   4. Assert that nextX was scaled correctly (getNextX)
-- =====================================================================

test("SpeedHook duplicate evaluation before activation keeps one stable dispatcher", function()
    local handlerCount = Events.OnPlayerMove._handlerCount()
    local dispatcher = UTSpeedHookLifecycle.dispatcher
    local implementation = UTSpeedHookLifecycle.implementation

    dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")

    assert_eq(Events.OnPlayerMove._handlerCount(), handlerCount,
        "duplicate evaluation must not add another OnPlayerMove callback")
    assert_eq(UTSpeedHookLifecycle.dispatcher, dispatcher,
        "dispatcher identity must remain stable")
    assert_true(UTSpeedHookLifecycle.implementation ~= implementation,
        "duplicate evaluation must replace the current implementation")

    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    withActivePlayer(player, function()
        player:moveTo(0, 0)
        player:setNextX(0.5)
        Events.OnPlayerMove.fire()
        assert_close(player:getNextX(), 0.75, 0.000001,
            "one dispatcher must apply one scaling pass")
    end)
end)

-- SpeedHook: positive speedMod amplifies pending delta
test("SpeedHook positive speedMod amplifies pending delta", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    -- Simulate: player at (0,0), engine wrote pending delta of +0.5 into nextX
    -- (real walking is ~0.06/frame; 0.5 is sprinting-ish but under the 1.5 cap)
    player:moveTo(0, 0)
    player:setNextX(0.5)  -- doDeferredMovement accumulated +0.5
    Events.OnPlayerMove.fire()
    -- SpeedHook should scale: nextX = 0 + 0.5 * 1.5 = 0.75
    local result = player:getNextX()
    assert(math.abs(result - 0.75) < 0.01, "expected nextX ~0.75, got " .. tostring(result))
    -- x should NOT be modified (only nextX changes)
    assert(math.abs(player:getX() - 0.0) < 0.01, "x should remain at 0.0")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: negative speedMod reduces pending delta
test("SpeedHook negative speedMod reduces pending delta", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = -0.3
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextX(0.5)
    Events.OnPlayerMove.fire()
    -- nextX = 0 + 0.5 * 0.7 = 0.35
    local result = player:getNextX()
    assert(math.abs(result - 0.35) < 0.01, "expected nextX ~0.35, got " .. tostring(result))
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: zero speedMod leaves delta unchanged (early return)
test("SpeedHook zero speedMod is a no-op", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextX(2.0)
    Events.OnPlayerMove.fire()
    assert(math.abs(player:getNextX() - 2.0) < 0.01, "nextX should be unchanged at 2.0")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: nil speedMod leaves delta unchanged (early return)
test("SpeedHook nil speedMod is a no-op", function()
    local player = MockPlayer({})
    -- UT_speedMod not set at all
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextX(2.0)
    Events.OnPlayerMove.fire()
    assert(math.abs(player:getNextX() - 2.0) < 0.01, "nextX should be unchanged at 2.0")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: no pending movement (dx=dy=0) is a no-op
test("SpeedHook skips when no pending movement (dx=dy=0)", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    player:moveTo(5, 3)
    -- nextX already equals x (no pending movement)
    Events.OnPlayerMove.fire()
    assert(math.abs(player:getNextX() - 5.0) < 0.01, "nextX unchanged when no delta")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: teleport guard skips when pending delta > 5
test("SpeedHook teleport guard skips when pending delta > 5", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextX(10.0)   -- delta=10 > TELEPORT_GUARD=5
    Events.OnPlayerMove.fire()
    -- Should NOT scale - teleport guard skips
    assert(math.abs(player:getNextX() - 10.0) < 0.01, "nextX should be unchanged (teleport guard)")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: per-frame delta cap prevents extreme jumps
test("SpeedHook per-frame delta cap prevents extreme movement", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 1.0  -- 2x speed
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextX(1.0)
    player:setNextY(1.0)
    Events.OnPlayerMove.fire()
    -- Scaled delta would be (2.0, 2.0), length ~2.83, exceeds MAX_DELTA_PER_FRAME=1.5
    local nx = player:getNextX()
    local ny = player:getNextY()
    local scaledLen = math.sqrt((nx * nx) + (ny * ny))
    assert(scaledLen <= 1.51, "scaled delta length should be capped at ~1.5, got " .. tostring(scaledLen))
    -- Direction should be preserved (45 degrees, so nx ~= ny)
    assert(math.abs(nx - ny) < 0.01, "direction should be preserved (nx ~= ny)")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: does NOT call setX (no position-pinning)
test("SpeedHook never calls setX (no position-pinning bug)", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.3
    _G.getPlayer = function() return player end
    player:moveTo(5.0, 3.0)
    player:setNextX(7.0)  -- pending delta = 2.0
    player:setNextY(4.0)  -- pending delta = 1.0
    Events.OnPlayerMove.fire()
    -- x must remain exactly 5.0 (setX was never called)
    assert_eq(player:getX(), 5.0, "x must not change - SpeedHook must not call setX")
    assert_eq(player:getY(), 3.0, "y must not change - SpeedHook must not call setY")
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: Y axis is scaled too
test("SpeedHook scales Y axis delta too", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    player:setNextY(0.5)  -- only Y movement
    Events.OnPlayerMove.fire()
    -- nextY = 0 + 0.5 * 1.5 = 0.75
    assert(math.abs(player:getNextY() - 0.75) < 0.01, "expected nextY ~0.75, got " .. tostring(player:getNextY()))
    _G.getPlayer = function() return nil end
end)

test("SpeedHook duplicate evaluation after activation replaces behavior without stacking", function()
    local handlerCount = Events.OnPlayerMove._handlerCount()
    local dispatcher = UTSpeedHookLifecycle.dispatcher

    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.25
    withActivePlayer(player, function()
        player:moveTo(2, -1)
        player:setNextX(2.4)
        player:setNextY(-1.2)
        Events.OnPlayerMove.fire()
        assert_close(player:getNextX(), 2.5, 0.000001, "initial X scaling")
        assert_close(player:getNextY(), -1.25, 0.000001, "initial Y scaling")
    end)

    dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
    assert_eq(Events.OnPlayerMove._handlerCount(), handlerCount,
        "post-activation evaluation must not add another callback")
    assert_eq(UTSpeedHookLifecycle.dispatcher, dispatcher,
        "post-activation dispatcher identity must remain stable")

    withActivePlayer(player, function()
        player:moveTo(2, -1)
        player:setNextX(2.4)
        player:setNextY(-1.2)
        Events.OnPlayerMove.fire()
        assert_close(player:getNextX(), 2.5, 0.000001,
            "replacement implementation must scale X exactly once")
        assert_close(player:getNextY(), -1.25, 0.000001,
            "replacement implementation must scale Y exactly once")
    end)
end)

test("SpeedHook sustained movement emits no telemetry or diagnostics", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    player.getCharacterActions = function()
        error("movement path must not inspect actions")
    end

    local originalRefresh = UTCore.refreshAggregatedModifierCache
    local originalPrint = _G.print
    local originalUTSmoke = _G.UTSmoke
    local originalDiagnostic = UTCore.recordDiagnostic
    local refreshCount, printCount, smokeCount, diagnosticCount = 0, 0, 0, 0
    UTCore.refreshAggregatedModifierCache = function(...)
        refreshCount = refreshCount + 1
        return originalRefresh(...)
    end
    _G.print = function(...)
        printCount = printCount + 1
    end
    _G.UTSmoke = {
        record = function(...)
            smokeCount = smokeCount + 1
        end,
    }
    UTCore.recordDiagnostic = function(...)
        diagnosticCount = diagnosticCount + 1
    end

    local ok, err = pcall(function()
        withActivePlayer(player, function()
            for _ = 1, 1000 do
                player:moveTo(0, 0)
                player:setNextX(0.5)
                Events.OnPlayerMove.fire()
            end
        end)
    end)
    UTCore.refreshAggregatedModifierCache = originalRefresh
    _G.print = originalPrint
    _G.UTSmoke = originalUTSmoke
    UTCore.recordDiagnostic = originalDiagnostic
    if not ok then error(err, 0) end

    assert_eq(refreshCount, 0, "movement must use the owner-maintained aggregate cache")
    assert_eq(printCount, 0, "movement must produce no diagnostic output")
    assert_eq(smokeCount, 0, "movement must produce no smoke telemetry")
    assert_eq(diagnosticCount, 0, "movement must not call diagnostic surfaces")
end)

test("SpeedHook rejects invalid modifiers and non-local players", function()
    local invalid = { "0.5", {}, -2, 1.0000001, 1e308, 0 / 0, math.huge, -math.huge }
    for _, modifier in ipairs(invalid) do
        local player = MockPlayer({})
        player:getModData()["UT_speedMod"] = modifier
        withActivePlayer(player, function()
            player:moveTo(0, 0)
            player:setNextX(0.5)
            Events.OnPlayerMove.fire()
            assert_eq(player:getNextX(), 0.5, "invalid modifier must be a no-op")
        end)
    end

    local remotePlayer = MockPlayer({})
    remotePlayer.isLocalPlayer = function() return false end
    remotePlayer:getModData()["UT_speedMod"] = 0.5
    withActivePlayer(remotePlayer, function()
        remotePlayer:moveTo(0, 0)
        remotePlayer:setNextX(0.5)
        Events.OnPlayerMove.fire()
        assert_eq(remotePlayer:getNextX(), 0.5, "remote player must be a no-op")
    end)
end)

test("SpeedHook accepts both authoritative aggregate range boundaries", function()
    for _, case in ipairs({
        { modifier = -0.75, expected = 0.125 },
        { modifier = 1.0, expected = 1.0 },
    }) do
        local player = MockPlayer({})
        player:getModData()["UT_speedMod"] = case.modifier
        withActivePlayer(player, function()
            player:moveTo(0, 0)
            player:setNextX(0.5)
            Events.OnPlayerMove.fire()
            assert_close(player:getNextX(), case.expected, 0.000001,
                "authoritative aggregate boundary must be applied")
        end)
    end
end)

test("SpeedHook rejects non-finite coordinates and overflow intermediates", function()
    local cases = {
        { x = 0 / 0, y = 0, nextX = 0.5, nextY = 0 },
        { x = 0, y = math.huge, nextX = 0.5, nextY = 0 },
        { x = -1e308, y = 0, nextX = 1e308, nextY = 0 },
    }
    for _, case in ipairs(cases) do
        local player = MockPlayer({})
        player:getModData()["UT_speedMod"] = 0.5
        local writes = 0
        player.getX = function() return case.x end
        player.getY = function() return case.y end
        player.getNextX = function() return case.nextX end
        player.getNextY = function() return case.nextY end
        player.setNextX = function() writes = writes + 1 end
        player.setNextY = function() writes = writes + 1 end
        withActivePlayer(player, function()
            Events.OnPlayerMove.fire()
            assert_eq(writes, 0, "invalid arithmetic must fail before mutation")
        end)
    end
end)

test("SpeedHook rejects malformed bridge methods before mutation", function()
    for _, methodName in ipairs({
        "isLocalPlayer", "getModData", "getX", "getY",
        "getNextX", "getNextY", "setNextX", "setNextY",
    }) do
        local player = MockPlayer({})
        player:getModData()["UT_speedMod"] = 0.5
        local original = player[methodName]
        player[methodName] = "malformed"
        local ok = pcall(function()
            withActivePlayer(player, function()
                Events.OnPlayerMove.fire()
            end)
        end)
        player[methodName] = original
        assert_eq(ok, true, methodName .. " must fail closed")
        assert_eq(player:getNextX(), 0, methodName .. " must not partially mutate X")
        assert_eq(player:getNextY(), 0, methodName .. " must not partially mutate Y")
    end
end)

local function exerciseSpeedHookGetterFailures(methodName, malformedResults)
    local failures = {
        { name = "missing", value = false },
        { name = "throw", value = function() error("injected getter failure") end },
    }
    for _, value in ipairs(malformedResults) do
        local result = value
        failures[#failures + 1] = { name = "malformed result", value = function() return result end }
    end

    for _, failure in ipairs(failures) do
        local player = MockPlayer({})
        player:getModData()["UT_speedMod"] = 0.5
        player:moveTo(2, 3)
        player:setNextX(2.4)
        player:setNextY(3.2)

        local originalGetter = player[methodName]
        local originalSetX = player.setNextX
        local originalSetY = player.setNextY
        local writes = 0
        player.setNextX = function(self, value)
            writes = writes + 1
            return originalSetX(self, value)
        end
        player.setNextY = function(self, value)
            writes = writes + 1
            return originalSetY(self, value)
        end
        player[methodName] = failure.value

        local originalPrint = _G.print
        local originalUTSmoke = _G.UTSmoke
        local originalDiagnostic = UTCore.recordDiagnostic
        local diagnostics = 0
        _G.print = function() diagnostics = diagnostics + 1 end
        _G.UTSmoke = { record = function() diagnostics = diagnostics + 1 end }
        UTCore.recordDiagnostic = function() diagnostics = diagnostics + 1 end

        local ok, err = pcall(function()
            withActivePlayer(player, function()
                Events.OnPlayerMove.fire()
            end)
        end)

        _G.print = originalPrint
        _G.UTSmoke = originalUTSmoke
        UTCore.recordDiagnostic = originalDiagnostic
        player[methodName] = originalGetter
        player.setNextX = originalSetX
        player.setNextY = originalSetY

        if not ok then error(err, 0) end
        assert_eq(writes, 0, methodName .. " " .. failure.name .. " must not mutate")
        assert_eq(diagnostics, 0, methodName .. " " .. failure.name .. " must stay silent")
        assert_close(player:getNextX(), 2.4, 0.000001,
            methodName .. " " .. failure.name .. " must preserve X")
        assert_close(player:getNextY(), 3.2, 0.000001,
            methodName .. " " .. failure.name .. " must preserve Y")
    end
end

test("SpeedHook protects isLocalPlayer failures", function()
    exerciseSpeedHookGetterFailures("isLocalPlayer", { "not-a-boolean", 1 })
end)

test("SpeedHook protects getModData failures", function()
    exerciseSpeedHookGetterFailures("getModData", { "not-a-table", 1 })
end)

test("SpeedHook protects getX failures", function()
    exerciseSpeedHookGetterFailures("getX", { "not-a-number", 0 / 0, math.huge })
end)

test("SpeedHook protects getY failures", function()
    exerciseSpeedHookGetterFailures("getY", { "not-a-number", 0 / 0, -math.huge })
end)

test("SpeedHook protects getNextX failures", function()
    exerciseSpeedHookGetterFailures("getNextX", { "not-a-number", 0 / 0, math.huge })
end)

test("SpeedHook protects getNextY failures", function()
    exerciseSpeedHookGetterFailures("getNextY", { "not-a-number", 0 / 0, -math.huge })
end)

local function exerciseSpeedHookSetterFailure(failingAxis, failurePhase)
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    player:moveTo(3, 4)
    player:setNextX(3.4)
    player:setNextY(4.2)

    local originalSetX = player.setNextX
    local originalSetY = player.setNextY
    local xCalls, yCalls = 0, 0
    player.setNextX = function(self, value)
        xCalls = xCalls + 1
        if failingAxis == "x" and xCalls == 1 then
            if failurePhase == "after" then originalSetX(self, value) end
            error("injected X setter failure")
        end
        return originalSetX(self, value)
    end
    player.setNextY = function(self, value)
        yCalls = yCalls + 1
        if failingAxis == "y" and yCalls == 1 then
            if failurePhase == "after" then originalSetY(self, value) end
            error("injected Y setter failure")
        end
        return originalSetY(self, value)
    end

    withActivePlayer(player, function()
        assert_eq(pcall(Events.OnPlayerMove.fire), true, "bridge failure must remain contained")
    end)
    assert_close(player:getNextX(), 3.4, 0.000001, "X must roll back to the exact pending target")
    assert_close(player:getNextY(), 4.2, 0.000001, "Y must roll back to the exact pending target")
end

test("SpeedHook rolls back failures before and after first-axis mutation", function()
    exerciseSpeedHookSetterFailure("x", "before")
    exerciseSpeedHookSetterFailure("x", "after")
end)

test("SpeedHook rolls back failures before and after second-axis mutation", function()
    exerciseSpeedHookSetterFailure("y", "before")
    exerciseSpeedHookSetterFailure("y", "after")
end)

test("SpeedHook retries a transient rollback failure without leaving a partial vector", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    player:moveTo(3, 4)
    player:setNextX(3.4)
    player:setNextY(4.2)

    local originalSetX = player.setNextX
    local originalSetY = player.setNextY
    local xCalls, yCalls = 0, 0
    player.setNextX = function(self, value)
        xCalls = xCalls + 1
        if xCalls == 2 then error("injected rollback failure before X mutation") end
        return originalSetX(self, value)
    end
    player.setNextY = function(self, value)
        yCalls = yCalls + 1
        if yCalls == 1 then
            originalSetY(self, value)
            error("injected second-axis post-mutation failure")
        end
        return originalSetY(self, value)
    end

    withActivePlayer(player, function()
        assert_eq(pcall(Events.OnPlayerMove.fire), true, "rollback failure must remain contained")
    end)
    assert_close(player:getNextX(), 3.4, 0.000001, "verification retry must restore X")
    assert_close(player:getNextY(), 4.2, 0.000001, "rollback must restore Y")
end)

test("SpeedHook teleport guard applies independently to either axis", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    withActivePlayer(player, function()
        player:moveTo(1, 2)
        player:setNextX(1.25)
        player:setNextY(7.01)
        Events.OnPlayerMove.fire()
        assert_eq(player:getNextX(), 1.25, "Y teleport must leave X unchanged")
        assert_eq(player:getNextY(), 7.01, "Y teleport must remain unchanged")
    end)
end)

test("SpeedHook legacy marker requires relaunch without registering or disabling legacy behavior", function()
    local currentState = UTCore._speedHookLifecycle
    local currentPublicState = UTSpeedHookLifecycle
    local handlerCount = Events.OnPlayerMove._handlerCount()
    local legacyCalls = 0
    local legacyHandler = function() legacyCalls = legacyCalls + 1 end
    local legacyState = { onPlayerMove = legacyHandler }

    UTCore._speedHookLifecycle = legacyState
    UTSpeedHookLifecycle = legacyState
    local ok, err = pcall(dofile, base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
    UTCore._speedHookLifecycle = currentState
    UTSpeedHookLifecycle = currentPublicState
    if not ok then error(err, 0) end

    assert_eq(legacyState.implementation, legacyHandler,
        "legacy implementation pointer must be preserved")
    assert_eq(legacyState.dispatcher, nil,
        "unknown legacy registration must not be falsely canonicalized")
    assert_eq(legacyState.legacyRelaunchRequired, true,
        "unknown legacy registration must require a full relaunch")
    assert_eq(legacyState.registration.outcome, "legacy_registration_unknown",
        "legacy callback cardinality must remain unknown")
    assert_eq(Events.OnPlayerMove._handlerCount(), handlerCount,
        "legacy detection must not stack a dispatcher")
    legacyState.implementation()
    assert_eq(legacyCalls, 1, "legacy behavior pointer must remain working")
end)

test("SpeedHook corrupt dispatcher requires relaunch and never registers or retries", function()
    local currentState = UTCore._speedHookLifecycle
    local currentPublicState = UTSpeedHookLifecycle
    local currentEvent = Events.OnPlayerMove
    local corruptDispatcher = {}
    local state = { dispatcher = corruptDispatcher }
    local addCalls = 0

    UTCore._speedHookLifecycle = state
    UTSpeedHookLifecycle = state
    Events.OnPlayerMove = {
        Add = function()
            addCalls = addCalls + 1
            error("corrupt dispatcher state must not call Add")
        end,
    }

    local ok, err = pcall(function()
        dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
        dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
        dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
    end)
    UTCore._speedHookLifecycle = currentState
    UTSpeedHookLifecycle = currentPublicState
    Events.OnPlayerMove = currentEvent
    if not ok then error(err, 0) end

    assert_eq(state.dispatcher, corruptDispatcher, "corrupt pointer must remain untouched")
    assert_eq(state.relaunchRequired, true, "corrupt pointer must require relaunch")
    assert_eq(state.dispatcherCorruptRelaunchRequired, true,
        "corrupt dispatcher terminal state must be explicit")
    assert_eq(state.registration.attempted, true,
        "unknown prior registration must not be treated as disproven")
    assert_eq(state.registration.outcome, "corrupt_dispatcher_unknown",
        "corrupt dispatcher outcome must remain explicit")
    assert_eq(state.registration.cardinality, "unknown",
        "corrupt dispatcher callback cardinality must remain unknown")
    assert_eq(state.registration.terminal, true,
        "corrupt dispatcher state must be terminal for this process")
    assert_eq(addCalls, 0, "repeated loads must not register or retry")
end)

test("SpeedHook registration false nil and post-mutation throw never retry", function()
    local cases = {
        {
            name = "nil",
            add = function(handlers, fn)
                handlers[#handlers + 1] = fn
                return nil
            end,
            expectedOutcome = "call_completed",
        },
        {
            name = "false",
            add = function(handlers, fn)
                handlers[#handlers + 1] = fn
                return false
            end,
            expectedOutcome = "outcome_unknown",
        },
        {
            name = "post-mutation throw",
            add = function(handlers, fn)
                handlers[#handlers + 1] = fn
                error("injected post-mutation registration failure")
            end,
            expectedOutcome = "outcome_unknown",
        },
    }

    for _, case in ipairs(cases) do
        local currentState = UTCore._speedHookLifecycle
        local currentPublicState = UTSpeedHookLifecycle
        local currentEvent = Events.OnPlayerMove
        local state = {}
        local handlers = {}
        local addCalls = 0

        UTCore._speedHookLifecycle = state
        UTSpeedHookLifecycle = state
        Events.OnPlayerMove = {
            Add = function(fn)
                addCalls = addCalls + 1
                return case.add(handlers, fn)
            end,
        }

        local ok, err = pcall(function()
            dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
            dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
        end)
        UTCore._speedHookLifecycle = currentState
        UTSpeedHookLifecycle = currentPublicState
        Events.OnPlayerMove = currentEvent
        if not ok then error(err, 0) end

        assert_eq(addCalls, 1, case.name .. " registration must not retry")
        assert_eq(#handlers, 1, case.name .. " registration must not duplicate the dispatcher")
        assert_eq(state.registration.attempted, true, case.name .. " must record an attempted registration")
        assert_eq(state.registration.outcome, case.expectedOutcome, case.name .. " outcome")
    end
end)

test("SpeedHook source and release copies are byte-identical", function()
    local function readBytes(path)
        local file, openError = io.open(path, "rb")
        if not file then error(openError, 0) end
        local content = file:read("*a")
        file:close()
        return content
    end

    local source = readBytes(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
    local release = readBytes(base .. "../release/UT_CORE/42.0/media/lua/shared/UTCore/UTCore_SpeedHook.lua")
    assert_eq(release, source, "source and release SpeedHook bytes must match")
end)

-- WorkSpeedHook
-- Note: patchTimedActions fires here as it would in-game, but has no global table targets
-- in this test environment. The three tests below exercise applyWorkDuration directly.
Events.OnGameBoot.fire()  -- triggers getDuration override

test("WorkSpeedHook shortens duration for negative workSpeedMod", function()
    local p = MockPlayer({})
    p:getModData()["UT_workSpeedMod"] = -0.5
    local action = MockTimedAction(p, "ISCraftItem", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert(math.abs(result - 50) < 1, "expected ~50, got " .. tostring(result))
end)

test("WorkSpeedHook lengthens duration for positive workSpeedMod", function()
    local p = MockPlayer({})
    p:getModData()["UT_workSpeedMod"] = 0.5
    local action = MockTimedAction(p, "ISCraftItem", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert(math.abs(result - 150) < 1, "expected ~150, got " .. tostring(result))
end)

test("WorkSpeedHook applies readSpeedMod to ISReadABook", function()
    local p = MockPlayer({})
    p:getModData()["UT_workSpeedMod"] = 0
    p:getModData()["UT_readSpeedMod"] = 0.3
    local action = MockTimedAction(p, "ISReadABook", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert(math.abs(result - 130) < 1, "expected ~130, got " .. tostring(result))
end)

test("WorkSpeedHook clamps zero duration to 1", function()
    local p = MockPlayer({})
    local action = MockTimedAction(p, "ISCraftItem", 0)
    local result = UTCore.applyWorkDuration(action, 0)
    assert_eq(result, 1, "expected zero duration to clamp to 1")
end)

test("WorkSpeedHook preserves negative (animation-driven) duration", function()
    local p = MockPlayer({})
    local action = MockTimedAction(p, "ISCraftItem", -1)
    local result = UTCore.applyWorkDuration(action, -1)
    assert_eq(result, -1, "expected animation-driven duration (-1) to pass through unchanged")
end)

test("WorkSpeedHook applies Paramedic independently to all eleven medical actions", function()
    local p = MockPlayer({"UniversalTraits:UT_paramedic"})
    local actionTypes = {
        "ISMedicalCheckAction", "ISApplyBandage", "ISCleanBurn",
        "ISComfreyCataplasm", "ISGarlicCataplasm", "ISPlantainCataplasm", "ISDisinfect",
        "ISRemoveBullet", "ISRemoveGlass", "ISSplint", "ISStitch",
    }
    for _, actionType in ipairs(actionTypes) do
        assert_eq(UTCore.applyWorkDuration(MockTimedAction(p, actionType, 120), 120), 60, actionType)
    end

    p:getModData()["UT_modifierBuckets"] = { workAdd = { test = 0.25 } }
    assert_eq(UTCore.applyWorkDuration(MockTimedAction(p, "ISStitch", 120), 120), 75,
        "Paramedic must halve the duration after the independent +0.25 work factor")
    p:getModData()["UT_modifierBuckets"] = { workAdd = { test = -0.25 } }
    assert_eq(UTCore.applyWorkDuration(MockTimedAction(p, "ISStitch", 120), 120), 45,
        "Paramedic must halve the duration after the independent -0.25 work factor")
end)

test("WorkSpeedHook preserves non-target actions and non-Paramedic players", function()
    local paramedic = MockPlayer({"UniversalTraits:UT_paramedic"})
    local ordinary = MockPlayer({})
    assert_eq(UTCore.applyWorkDuration(MockTimedAction(paramedic, "ISCleanWound", 120), 120), 120)
    assert_eq(UTCore.applyWorkDuration(MockTimedAction(paramedic, "ISReadABook", 120), 120), 120)
    for _, inventedType in ipairs({ "ISApplyComfrey", "ISApplyGarlic", "ISApplyPlantain" }) do
        assert_eq(UTCore.applyWorkDuration(MockTimedAction(paramedic, inventedType, 120), 120), 120,
            inventedType .. " must not be accepted by the medical allowlist")
    end
    assert_eq(UTCore.applyWorkDuration(MockTimedAction(ordinary, "ISComfreyCataplasm", 120), 120), 120)
end)

test("WorkSpeedHook patches constructor-only medical actions once", function()
    local paramedic = MockPlayer({"UniversalTraits:UT_paramedic"})
    local ordinary = MockPlayer({})
    local function newAction(self, character, duration)
        return { character = character, Type = self.Type, maxTime = duration }
    end

    ISMedicalCheckAction = { Type = "ISMedicalCheckAction", new = newAction }
    ISSplint = { Type = "ISSplint", new = newAction }
    Events.OnGameBoot.fire()

    local medicalNew = ISMedicalCheckAction.new
    local splintNew = ISSplint.new
    assert_eq(ISMedicalCheckAction:new(paramedic, 150).maxTime, 75)
    assert_eq(ISSplint:new(paramedic, 100).maxTime, 50)
    assert_eq(ISMedicalCheckAction:new(ordinary, 150).maxTime, 150)

    Events.OnGameBoot.fire()
    assert_eq(ISMedicalCheckAction.new, medicalNew, "medical constructor must not be wrapped twice")
    assert_eq(ISSplint.new, splintNew, "splint constructor must not be wrapped twice")
    assert_eq(ISMedicalCheckAction:new(paramedic, 150).maxTime, 75,
        "duplicate boot must not compound the factor")
end)

test("WorkSpeedHook constructor marker prevents getDuration double application", function()
    local paramedic = MockPlayer({"UniversalTraits:UT_paramedic"})
    ISMedicalCheckAction = {
        Type = "ISMedicalCheckAction",
        new = function(self, character)
            return { character = character, Type = self.Type, maxTime = 150 }
        end,
        getDuration = function(self) return self.maxTime end,
    }
    Events.OnGameBoot.fire()
    local action = ISMedicalCheckAction:new(paramedic)
    assert_eq(action.maxTime, 75)
    setmetatable(action, { __index = ISMedicalCheckAction })
    assert_eq(action:getDuration(), 75, "getDuration must not halve constructor-adjusted maxTime again")
end)

test("WorkSpeedHook duplicate module load keeps one event install", function()
    local handlerCount = Events.OnGameBoot._handlerCount()
    local medicalNew = ISMedicalCheckAction.new
    local medicalGetDuration = ISMedicalCheckAction.getDuration
    dofile(base .. "../media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua")
    assert_eq(Events.OnGameBoot._handlerCount(), handlerCount,
        "duplicate module load must not add another OnGameBoot handler")
    Events.OnGameBoot.fire()
    assert_eq(ISMedicalCheckAction.new, medicalNew,
        "duplicate module load must not wrap constructors again")
    assert_eq(ISMedicalCheckAction.getDuration, medicalGetDuration,
        "duplicate module load must not wrap getDuration again")
end)

test("WorkSpeedHook tolerates absent and malformed constructor classes", function()
    ISMedicalCheckAction = nil
    ISSplint = { new = "not-a-function" }
    assert_eq(pcall(Events.OnGameBoot.fire), true, "malformed classes must not break boot")

    ISMedicalCheckAction = {
        new = function() return "malformed-action" end,
    }
    ISSplint = {
        new = function() return { Type = "ISSplint", maxTime = "not-a-number" } end,
    }
    assert_eq(pcall(Events.OnGameBoot.fire), true, "malformed constructor results must not break boot")
    assert_eq(ISMedicalCheckAction:new(), "malformed-action")
    assert_eq(ISSplint:new().maxTime, "not-a-number")
end)

test("ReadingHook getSkillBookCompletionXP returns tier bonus", function()
    SkillBook = { Cooking = { perk = "Cooking" } }
    local item = {
        getNumberOfPages = function() return 220 end,
        getSkillTrained = function() return "Cooking" end,
        getMaxLevelTrained = function() return 6 end,
    }
    assert_eq(UTCore.getSkillBookCompletionXP(item), 65)
end)

test("ReadingHook applyReadingMoodEffects clears panic and stress and improves mood", function()
    local p = MockPlayer({})
    p:getModData()["UT_readCalm"] = true
    p:getModData()["UT_readMoodBonus"] = 5
    p:getStats():set(CharacterStat.PANIC, 20)
    p:getStats():set(CharacterStat.STRESS, 15)
    p:getStats():set(CharacterStat.BOREDOM, 30)
    p:getStats():set(CharacterStat.UNHAPPINESS, 40)
    p:setBodyDamage({})

    UTCore.applyReadingMoodEffects(p, 1.0)

    assert_eq(p:getStats():get(CharacterStat.PANIC), 0)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0)
    assert_eq(p:getStats():get(CharacterStat.BOREDOM), 25)
    assert_eq(p:getStats():get(CharacterStat.UNHAPPINESS), 35)
end)

test("ReadingHook awards flat XP when a skill book is completed", function()
    SkillBook = { Mechanics = { perk = "Mechanics" } }
    local p = MockPlayer({})
    local item = {
        getNumberOfPages = function() return 200 end,
        getSkillTrained = function() return "Mechanics" end,
        getMaxLevelTrained = function() return 8 end,
    }

    local bonus = UTCore.tryAwardSkillBookCompletionXP(p, item, 120, 200)
    local calls = p:getXpCalls()
    assert_eq(bonus, 120)
    assert_eq(#calls, 1)
    assert_eq(calls[1].perk, "Mechanics")
    assert_eq(calls[1].amount, 120)
end)

-- BleedHook
test("BleedHook calls AddHealth for bleedMult < 1.0", function()
    UTCore._bleedTickCounter = 0
    local p = MockPlayer({})
    p:getModData()["UT_bleedMult"] = 0.4
    local torso = MockBodyPart("Torso_Upper", true, false)
    p:setBodyDamage(MockBodyDamage({ torso }))
    _G.getPlayer = function() return p end
    for i = 1, 60 do Events.OnPlayerUpdate.fire(p) end
    _G.getPlayer = function() return nil end
    assert(torso:getAddHealthCalls() >= 1, "expected AddHealth call for mult 0.4")
end)

test("BleedHook calls ReduceHealth for bleedMult > 1.0", function()
    UTCore._bleedTickCounter = 0
    local p = MockPlayer({})
    p:getModData()["UT_bleedMult"] = 2.0
    local torso = MockBodyPart("Torso_Upper", true, false)
    p:setBodyDamage(MockBodyDamage({ torso }))
    _G.getPlayer = function() return p end
    for i = 1, 60 do Events.OnPlayerUpdate.fire(p) end
    _G.getPlayer = function() return nil end
    assert(torso:getReduceHealthCalls() >= 1, "expected ReduceHealth call for mult 2.0")
end)

local function runBleedDecayInterval(player)
    for _ = 1, 10 do Events.OnPlayerUpdate.fire(player) end
end

test("BleedDecayHook applies a named bandaged-only multiplier without legacy overwrite", function()
    local p = MockPlayer({})
    local bandaged = MockBodyPart("Hand_L", true, false)
    local open = MockBodyPart("Hand_R", true, false)
    bandaged:setBandaged(true)
    p:setBodyDamage(MockBodyDamage({ bandaged, open }))

    UTCore.applyBleedDecayMult(p, 3.0, true, "UniversalTraits:UT_staunch")
    assert_eq(p:getModData()["UT_bleedDecayMult"], nil, "named source must not overwrite legacy scalar")
    runBleedDecayInterval(p)

    assert_close(bandaged:getBleedingTime(), 9.996, 0.0000001, "3x bandaged extra decay")
    assert_close(open:getBleedingTime(), 10.0, 0.0000001, "unbandaged wound must be unchanged")
end)

test("BleedDecayHook composes Staunch and Thick Blood to 4.5x only while bandaged", function()
    local p = MockPlayer({})
    local bandaged = MockBodyPart("Hand_L", true, false)
    local open = MockBodyPart("Hand_R", true, false)
    bandaged:setBandaged(true)
    p:setBodyDamage(MockBodyDamage({ bandaged, open }))

    UTCore.applyBleedDecayMult(p, 1.5, false)
    UTCore.applyBleedDecayMult(p, 3.0, true, "UniversalTraits:UT_staunch")
    runBleedDecayInterval(p)

    assert_close(bandaged:getBleedingTime(), 9.993, 0.0000001, "4.5x bandaged extra decay")
    assert_close(open:getBleedingTime(), 9.9999, 0.0000001, "1.5x unbandaged extra decay")
end)

test("BleedDecayHook removes one named source and preserves the legacy modifier", function()
    local p = MockPlayer({})
    local bandaged = MockBodyPart("Hand_L", true, false)
    bandaged:setBandaged(true)
    p:setBodyDamage(MockBodyDamage({ bandaged }))

    UTCore.applyBleedDecayMult(p, 1.5, false)
    UTCore.applyBleedDecayMult(p, 3.0, true, "UniversalTraits:UT_staunch")
    UTCore.applyBleedDecayMult(p, nil, true, "UniversalTraits:UT_staunch")
    runBleedDecayInterval(p)

    assert_close(bandaged:getBleedingTime(), 9.999, 0.0000001, "Thick Blood must remain after Staunch removal")
end)

test("BleedDecayHook deterministically composes Staunch with the allowed Anemic opposite", function()
    local p = MockPlayer({})
    local bandaged = MockBodyPart("Hand_L", true, false)
    local open = MockBodyPart("Hand_R", true, false)
    bandaged:setBandaged(true)
    p:setBodyDamage(MockBodyDamage({ bandaged, open }))

    UTCore.applyBleedDecayMult(p, 0.33, false)
    UTCore.applyBleedDecayMult(p, 3.0, true, "UniversalTraits:UT_staunch")
    runBleedDecayInterval(p)

    assert_close(bandaged:getBleedingTime(), 10.00002, 0.0000001, "0.99x bandaged composition")
    assert_close(open:getBleedingTime(), 10.000134, 0.0000001, "0.33x unbandaged composition")
end)

-- MeleeDelayHook: 50% reduction for axe category with UT_axes trait
test("MockPlayer owns mutable melee delay and clamps writes at zero", function()
    local p = MockPlayer({}, { meleeDelay = 20 })
    assert_eq(p:getMeleeDelay(), 20, "expected initial character melee delay")
    p:setMeleeDelay(7)
    assert_eq(p:getMeleeDelay(), 7, "expected melee delay read-after-write")
    p:setMeleeDelay(-3)
    assert_eq(p:getMeleeDelay(), 0, "expected negative melee delay clamped to zero")
    assert_eq(p:getModData()["_lastMeleeDelay"], 0, "expected observation surface to record clamped write")
end)

test("MeleeDelayHook reduces delay 50% for axe weapon with UT_axes", function()
    local weapon = MockWeapon("HandAxe", nil, false, true, {
        categories = { WeaponCategory.AXE },
    })
    local p = MockPlayer({"UniversalTraits:UT_axes"}, {
        primaryHandItem = weapon,
        meleeDelay = 20,
    })
    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getMeleeDelay(), 10, "expected character delay reduced to 10 (50% of 20)")
    assert_eq(p:getModData()["UT_meleeDelaySet"], true, "expected same-swing guard set")

    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getMeleeDelay(), 10, "expected same swing to remain at 10")

    p:setMeleeDelay(0)
    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getModData()["UT_meleeDelaySet"], false, "expected guard cleared when character delay reaches zero")
end)

-- MeleeDelayHook: strength-scaled reduction for UT_heavyswing
test("MeleeDelayHook uses strength-scaled formula for UT_heavyswing", function()
    local weapon = MockWeapon("PickAxe", nil, false, true, {
        categories = { WeaponCategory.AXE },
    })
    local p = MockPlayer({"UniversalTraits:UT_heavyswing"}, {
        primaryHandItem = weapon,
        meleeDelay = 20,
        perkLevels = { Strength = 5 },
    })
    local setterCalls = 0
    local setMeleeDelay = p.setMeleeDelay
    p.setMeleeDelay = function(self, value)
        setterCalls = setterCalls + 1
        return setMeleeDelay(self, value)
    end
    assert_eq(weapon:isOfWeaponCategory(WeaponCategory.AXE), true, "expected AXE weapon category")
    assert_eq(p:getMeleeDelay(), 20, "expected initial character delay 20")
    assert_eq(p:getPerkLevel("Strength"), 5, "expected Strength 5")
    -- Perks global not defined in test env; getPerkLevel uses key "Strength"
    local _savedPerks = _G.Perks
    _G.Perks = { Strength = "Strength" }
    UTCore._meleeDelayOnPlayerUpdate(p)
    _G.Perks = _savedPerks
    -- newDelay = 20 - 20 * (5 * 0.1) = 20 - 10 = 10
    assert_eq(p:getMeleeDelay(), 10, "expected character delay reduced from 20 to 10 (strength-scaled)")
    assert_eq(setterCalls, 1, "expected exactly one player setter call")
    assert_eq(p:getModData()["UT_meleeDelaySet"], true, "expected same-swing guard set")
end)

-- MeleeDelayHook: no trait means setMeleeDelay is NOT called
test("MeleeDelayHook does not apply when no relevant trait is present", function()
    local weapon = MockWeapon("HandAxe", 20)
    local p = MockPlayer({}, { primaryHandItem = weapon })
    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getModData()["_lastMeleeDelay"], nil, "expected setMeleeDelay not called")
end)

local function withMeleeDelayTestState(player, fn)
    local savedWeaponCategory = _G.WeaponCategory
    local savedUTSmoke = _G.UTSmoke
    local savedRegistered, savedByKey = {}, {}
    for key, value in pairs(CharacterTrait._registered) do savedRegistered[key] = value end
    for key, value in pairs(CharacterTrait._byKey) do savedByKey[key] = value end
    local savedWeapon = player and player:getPrimaryHandItem() or nil
    local savedSetMeleeDelay = player and player.setMeleeDelay or nil
    local savedDelay = player and player:getMeleeDelay() or nil
    local savedGuard = player and player:getModData()["UT_meleeDelaySet"] or nil
    local savedLastDelay = player and player:getModData()["_lastMeleeDelay"] or nil
    _G.UTSmoke = nil

    local ok, err = pcall(fn)

    _G.WeaponCategory = savedWeaponCategory
    _G.UTSmoke = savedUTSmoke
    CharacterTrait._registered = savedRegistered
    CharacterTrait._byKey = savedByKey
    if player then
        player.setMeleeDelay = savedSetMeleeDelay
        player:setPrimaryHandItem(savedWeapon)
        player:setMeleeDelay(savedDelay)
        player:getModData()["UT_meleeDelaySet"] = savedGuard
        player:getModData()["_lastMeleeDelay"] = savedLastDelay
    end
    if not ok then error(err, 0) end
end

test("MeleeDelayHook classifies every WeaponCategory and rejects an adjacent trait", function()
    withMeleeDelayTestState(nil, function()
        _G.WeaponCategory = {
            AXE = {}, BLUNT = {}, SMALL_BLUNT = {},
            LONG_BLADE = {}, SMALL_BLADE = {}, SPEAR = {},
        }
        local cases = {
            { "AXE",         WeaponCategory.AXE,         "UniversalTraits:UT_axes",         "UniversalTraits:UT_blunts" },
            { "BLUNT",       WeaponCategory.BLUNT,       "UniversalTraits:UT_long_blunts",  "UniversalTraits:UT_short_blunts" },
            { "SMALL_BLUNT", WeaponCategory.SMALL_BLUNT, "UniversalTraits:UT_short_blunts", "UniversalTraits:UT_long_blunts" },
            { "LONG_BLADE",  WeaponCategory.LONG_BLADE,  "UniversalTraits:UT_long_blades",  "UniversalTraits:UT_short_blades" },
            { "SMALL_BLADE", WeaponCategory.SMALL_BLADE, "UniversalTraits:UT_short_blades", "UniversalTraits:UT_long_blades" },
            { "SPEAR",       WeaponCategory.SPEAR,       "UniversalTraits:UT_spears",       "UniversalTraits:UT_axes" },
        }

        for _, case in ipairs(cases) do
            local weapon = MockWeapon(case[1], nil, false, true, { categories = { case[2] } })
            local matching = MockPlayer({ case[3] }, { primaryHandItem = weapon, meleeDelay = 20 })
            local matchingCalls = 0
            local matchingSetter = matching.setMeleeDelay
            matching.setMeleeDelay = function(self, value)
                matchingCalls = matchingCalls + 1
                return matchingSetter(self, value)
            end

            UTCore._meleeDelayOnPlayerUpdate(matching)
            UTCore._meleeDelayOnPlayerUpdate(matching)
            assert_eq(matching:getMeleeDelay(), 10, case[1] .. " matching trait delay")
            assert_eq(matchingCalls, 1, case[1] .. " matching trait setter count")

            local nonmatching = MockPlayer({ case[4] }, { primaryHandItem = weapon, meleeDelay = 20 })
            local nonmatchingCalls = 0
            local nonmatchingSetter = nonmatching.setMeleeDelay
            nonmatching.setMeleeDelay = function(self, value)
                nonmatchingCalls = nonmatchingCalls + 1
                return nonmatchingSetter(self, value)
            end
            UTCore._meleeDelayOnPlayerUpdate(nonmatching)
            assert_eq(nonmatching:getMeleeDelay(), 20, case[1] .. " adjacent trait must not change delay")
            assert_eq(nonmatchingCalls, 0, case[1] .. " adjacent trait setter count")
        end
    end)
end)

test("Short Blade keeps its accepted 50 percent delay effect primary-hand only", function()
    withMeleeDelayTestState(nil, function()
        _G.WeaponCategory = {
            AXE = {}, BLUNT = {}, SMALL_BLUNT = {},
            LONG_BLADE = {}, SMALL_BLADE = {}, SPEAR = {},
        }
        local smallBlade = MockWeapon("Knife", nil, false, true, {
            categories = { WeaponCategory.SMALL_BLADE },
        })
        local unrelatedPrimary = MockWeapon("Bat", nil, false, true, {
            categories = { WeaponCategory.BLUNT },
        })
        local primary = MockPlayer({ "UniversalTraits:UT_short_blades" }, {
            primaryHandItem = smallBlade,
            meleeDelay = 20,
        })
        UTCore._meleeDelayOnPlayerUpdate(primary)
        assert_eq(primary:getMeleeDelay(), 10,
            "Short Blade must retain the primary-hand delay multiplier")

        local secondaryOnly = MockPlayer({ "UniversalTraits:UT_short_blades" }, {
            primaryHandItem = unrelatedPrimary,
            secondaryHandItem = smallBlade,
            meleeDelay = 20,
        })
        UTCore._meleeDelayOnPlayerUpdate(secondaryOnly)
        assert_eq(secondaryOnly:getMeleeDelay(), 20,
            "secondary-hand Small Blade must not drive melee delay")
    end)
end)

test("MeleeDelayHook derives one- and two-handed category flags", function()
    local cases = {
        { "one-handed", false, "UniversalTraits:UT_onehanded_axes", "UniversalTraits:UT_twohanded_axes" },
        { "two-handed", true,  "UniversalTraits:UT_twohanded_axes", "UniversalTraits:UT_onehanded_axes" },
    }

    for _, case in ipairs(cases) do
        local weapon = MockWeapon(case[1], nil, case[2], true, { categories = { WeaponCategory.AXE } })
        local matching = MockPlayer({ case[3] }, { primaryHandItem = weapon, meleeDelay = 20 })
        local matchingCalls = 0
        local matchingSetter = matching.setMeleeDelay
        matching.setMeleeDelay = function(self, value)
            matchingCalls = matchingCalls + 1
            return matchingSetter(self, value)
        end
        UTCore._meleeDelayOnPlayerUpdate(matching)
        UTCore._meleeDelayOnPlayerUpdate(matching)
        assert_eq(matching:getMeleeDelay(), 10, case[1] .. " matching handed trait")
        assert_eq(matchingCalls, 1, case[1] .. " matching handed setter count")

        local nonmatching = MockPlayer({ case[4] }, { primaryHandItem = weapon, meleeDelay = 20 })
        local nonmatchingCalls = 0
        local nonmatchingSetter = nonmatching.setMeleeDelay
        nonmatching.setMeleeDelay = function(self, value)
            nonmatchingCalls = nonmatchingCalls + 1
            return nonmatchingSetter(self, value)
        end
        UTCore._meleeDelayOnPlayerUpdate(nonmatching)
        UTCore._meleeDelayOnPlayerUpdate(nonmatching)
        assert_eq(nonmatching:getMeleeDelay(), 20, case[1] .. " opposite handed trait")
        assert_eq(nonmatchingCalls, 0, case[1] .. " opposite handed setter count")
    end
end)

test("MeleeDelayHook fails closed when weapon category inputs are unavailable", function()
    local player = MockPlayer({ "UniversalTraits:UT_axes" }, { meleeDelay = 20 })
    withMeleeDelayTestState(player, function()
        local effectCalls = 0
        local setMeleeDelay = player.setMeleeDelay
        player.setMeleeDelay = function(self, value)
            effectCalls = effectCalls + 1
            return setMeleeDelay(self, value)
        end
        local cases = {
            { name = "nil weapon", weapon = nil },
            { name = "missing category method", weapon = MockWeapon("NoMethod", nil, false, true, { categories = { WeaponCategory.AXE } }) },
        }
        cases[2].weapon.isOfWeaponCategory = nil

        for _, case in ipairs(cases) do
            player:setPrimaryHandItem(case.weapon)
            setMeleeDelay(player, 20)
            player:getModData()["UT_meleeDelaySet"] = false
            UTCore._meleeDelayOnPlayerUpdate(player)
            assert_eq(player:getMeleeDelay(), 20, case.name .. " delay")
            assert_eq(player:getModData()["UT_meleeDelaySet"], false, case.name .. " guard")
            assert_eq(effectCalls, 0, case.name .. " setter count")
        end

        player:setPrimaryHandItem(MockWeapon("NoEnum", nil, false, true, { categories = { WeaponCategory.AXE } }))
        setMeleeDelay(player, 20)
        player:getModData()["UT_meleeDelaySet"] = false
        _G.WeaponCategory = nil
        UTCore._meleeDelayOnPlayerUpdate(player)
        assert_eq(player:getMeleeDelay(), 20, "missing WeaponCategory delay")
        assert_eq(player:getModData()["UT_meleeDelaySet"], false, "missing WeaponCategory guard")
        assert_eq(effectCalls, 0, "missing WeaponCategory setter count")
    end)
end)

test("MeleeDelayHook accepts a weapon with multiple enum categories", function()
    local weapon = MockWeapon("AxeSpear", nil, true, true, {
        categories = { WeaponCategory.AXE, WeaponCategory.SPEAR },
    })
    local player = MockPlayer({ "UniversalTraits:UT_spears" }, {
        primaryHandItem = weapon,
        meleeDelay = 20,
    })
    local setterCalls = 0
    local setMeleeDelay = player.setMeleeDelay
    player.setMeleeDelay = function(self, value)
        setterCalls = setterCalls + 1
        return setMeleeDelay(self, value)
    end
    UTCore._meleeDelayOnPlayerUpdate(player)
    UTCore._meleeDelayOnPlayerUpdate(player)
    assert_eq(player:getMeleeDelay(), 10)
    assert_eq(player:getModData()["UT_meleeDelaySet"], true)
    assert_eq(setterCalls, 1, "multi-category same-swing setter count")
end)

test("MeleeDelayHook refreshes cached categories across A-B-A identity swaps", function()
    local axe = MockWeapon("A", nil, false, true, { categories = { WeaponCategory.AXE } })
    local spear = MockWeapon("B", nil, true, true, { categories = { WeaponCategory.SPEAR } })
    local player = MockPlayer({ "UniversalTraits:UT_axes" }, {
        primaryHandItem = axe,
        meleeDelay = 20,
    })

    withMeleeDelayTestState(player, function()
        UTCore._meleeDelayOnPlayerUpdate(player)
        assert_eq(player:getMeleeDelay(), 10, "A first swing")
        assert_eq(player:getModData()["UT_meleeDelaySet"], true, "A first guard")

        player:setMeleeDelay(0)
        UTCore._meleeDelayOnPlayerUpdate(player)
        assert_eq(player:getModData()["UT_meleeDelaySet"], false, "A guard reset")

        player:setPrimaryHandItem(spear)
        player:setMeleeDelay(20)
        UTCore._meleeDelayOnPlayerUpdate(player)
        assert_eq(player:getMeleeDelay(), 20, "B must not reuse A categories")
        assert_eq(player:getModData()["UT_meleeDelaySet"], false, "B guard remains clear")

        player:setMeleeDelay(0)
        UTCore._meleeDelayOnPlayerUpdate(player)
        player:setPrimaryHandItem(axe)
        player:setMeleeDelay(20)
        UTCore._meleeDelayOnPlayerUpdate(player)
        assert_eq(player:getMeleeDelay(), 10, "A second swing after B")
        assert_eq(player:getModData()["UT_meleeDelaySet"], true, "A second guard")
    end)
end)

-- Vehicle trait helpers
test("Vehicle trait registration applies modifiers on vehicle enter", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
    }, 1)

    player:setVehicle(vehicle)
    Events.OnEnterVehicle.fire(player)

    assert_eq(vehicle:getMaxSpeed(), 150, "expected vehicle max speed multiplier on enter")
    assert_eq(vehicle:getBrakingForce(), 5, "expected braking force multiplier on enter")
end)

test("Vehicle trait registration does not mutate for a passenger", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = false })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
    }, 1)

    Events.OnEnterVehicle.fire(player)

    assert_eq(vehicle:getMaxSpeed(), 100, "passenger entry must preserve max speed")
    assert_eq(vehicle:getBrakingForce(), 10, "passenger entry must preserve braking force")
end)

test("Vehicle trait helpers restore the baseline on vehicle exit", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
        enginePower = 2.0,
        mass = 0.75,
    }, 1)

    player:setVehicle(vehicle)
    Events.OnEnterVehicle.fire(player)
    assert_eq(vehicle:getMaxSpeed(), 150, "driver entry must apply max speed before restore")
    assert_eq(vehicle:getBrakingForce(), 5, "driver entry must apply braking before restore")
    assert_eq(vehicle:getEnginePower(), 200, "driver entry must apply engine power before restore")
    assert_eq(vehicle:getMass(), 750, "driver entry must apply initial mass before restore")
    player:setVehicle(nil)
    UTCore.updateVehicleTraitState(player)

    assert_eq(vehicle:getMaxSpeed(), 100, "expected max speed restored")
    assert_eq(vehicle:getBrakingForce(), 10, "expected braking restored")
    assert_eq(vehicle:getEnginePower(), 100, "expected engine power restored")
    assert_eq(vehicle:getMass(), 1000, "expected mass restored")
end)

test("Vehicle simple fields reject hostile getter results without inventing baselines", function()
    local hostileResults = {
        { name = "string", value = "100" },
        { name = "boolean", value = true },
        { name = "NaN", value = 0 / 0 },
        { name = "positive infinity", value = math.huge },
        { name = "negative infinity", value = -math.huge },
        { name = "negative domain value", value = -1 },
    }
    for _, hostile in ipairs(hostileResults) do
        UTCore._vehicleTraitDefs = {}
        local vehicle = MockVehicle()
        vehicle.getMaxSpeed = function() return hostile.value end
        local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
        UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
            maxSpeed = 1.5,
        }, 1)

        Events.OnEnterVehicle.fire(player)

        local ownership = vehicle:getModData().UT_vehicleTraitOwnership
        assert_eq(vehicle._setterCalls.maxSpeed or 0, 0,
            hostile.name .. " must not trigger a setter from an invented baseline")
        assert_eq(ownership.fields.maxSpeed, nil,
            hostile.name .. " must remain unresolved during acquisition")
    end

    for _, mode in ipairs({ "throwing", "missing" }) do
        UTCore._vehicleTraitDefs = {}
        local vehicle = MockVehicle()
        vehicle.getMaxSpeed = mode == "throwing" and function() error("hostile getter") end or nil
        local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
        UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
            maxSpeed = 1.5,
        }, 1)

        assert_true(pcall(Events.OnEnterVehicle.fire, player), mode .. " getter must be contained")
        assert_eq(vehicle._setterCalls.maxSpeed or 0, 0,
            mode .. " getter must not trigger a setter from an invented baseline")
    end
end)

test("Vehicle field validation preserves valid float and integer bridge values", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    vehicle._maxSpeed = 100.5
    vehicle._brakingForce = 10.25
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
        engineQuality = 0.5,
        engineLoudness = 0.5,
        enginePower = 2,
    }, 1)

    Events.OnEnterVehicle.fire(player)

    assert_eq(vehicle:getMaxSpeed(), 150.75, "valid simple-field float must remain accepted")
    assert_eq(vehicle:getBrakingForce(), 5.125, "valid braking float must remain accepted")
    assert_eq(vehicle:getEngineQuality(), 50, "valid engine integer must remain accepted")
    assert_eq(vehicle:getEngineLoudness(), 50, "valid loudness integer must remain accepted")
    assert_eq(vehicle:getEnginePower(), 200, "valid power integer must remain accepted")
end)

local function partialEngineApplyFixture(powerAfterFailure)
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local calls = 0
    vehicle.setEngineFeature = function(self, quality, loudness, power)
        calls = calls + 1
        self._setterCalls.engineFeature = (self._setterCalls.engineFeature or 0) + 1
        self._engineQuality = quality
        self._engineLoudness = math.floor(loudness / 2.7)
        if calls == 1 then
            if powerAfterFailure ~= nil then self._enginePower = powerAfterFailure end
            error("partial grouped apply")
        end
        self._enginePower = power
    end
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        engineQuality = 0.5,
        engineLoudness = 0.5,
        enginePower = 2,
    }, 1)
    return vehicle, player
end

test("Vehicle grouped apply retries unchanged baseline power and later succeeds", function()
    local vehicle, player = partialEngineApplyFixture(nil)

    UTCore.syncVehicleTrait(player, vehicle)
    local ownership = vehicle:getModData().UT_vehicleTraitOwnership
    assert_eq(vehicle:getEngineQuality(), 50, "partial quality must remain owned at target")
    assert_eq(vehicle:getEngineLoudness(), 50, "partial loudness must remain owned at target")
    assert_eq(vehicle:getEnginePower(), 100, "unwritten power must remain at baseline")
    assert_true(type(ownership.fields.enginePower) == "table",
        "unchanged baseline power must remain pending")
    assert_eq(ownership.suppressed.enginePower, nil,
        "unchanged baseline power must not be classified as foreign")

    UTCore.syncVehicleTrait(player, vehicle)
    assert_eq(vehicle:getEnginePower(), 200, "later grouped apply must finish power")
    assert_eq(vehicle._setterCalls.engineFeature, 2, "exactly one bounded retry expected")
    assert_eq(ownership.fields.enginePower.lastApplied, 200,
        "later successful power must remain owned")
end)

test("Vehicle grouped apply suppresses observably foreign divergent power", function()
    local vehicle, player = partialEngineApplyFixture(150)

    UTCore.syncVehicleTrait(player, vehicle)
    local ownership = vehicle:getModData().UT_vehicleTraitOwnership
    assert_eq(vehicle:getEnginePower(), 150, "foreign divergent power must be preserved")
    assert_eq(ownership.fields.enginePower, nil, "foreign divergent power must relinquish ownership")
    assert_eq(ownership.suppressed.enginePower, true, "foreign divergent power must be suppressed")

    UTCore.syncVehicleTrait(player, vehicle)
    assert_eq(vehicle:getEnginePower(), 150, "suppressed foreign power must not be overwritten")
end)

test("Vehicle grouped apply permanent failure is bounded", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    vehicle.setEngineFeature = function(self, quality, loudness)
        self._setterCalls.engineFeature = (self._setterCalls.engineFeature or 0) + 1
        self._engineQuality = quality
        self._engineLoudness = math.floor(loudness / 2.7)
        error("permanent grouped apply failure")
    end
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        engineQuality = 0.5,
        engineLoudness = 0.5,
        enginePower = 2,
    }, 1)

    for _ = 1, 5 do UTCore.syncVehicleTrait(player, vehicle) end

    local ownership = vehicle:getModData().UT_vehicleTraitOwnership
    assert_eq(vehicle._setterCalls.engineFeature, 2, "permanent failure must stop at retry limit")
    assert_eq(vehicle:getEnginePower(), 100, "permanently unwritten power must stay at baseline")
    assert_true(type(ownership.fields.enginePower) == "table",
        "bounded failure must retain restore-safe ownership evidence")
    assert_eq(ownership.suppressed.enginePower, nil,
        "bounded unchanged power must not be suppressed")
end)

test("Vehicle engine fields reject fractional acquisition reads without consuming retries", function()
    for _, hostile in ipairs({
        { field = "engineQuality", getter = "getEngineQuality", value = 50.5 },
        { field = "engineLoudness", getter = "getEngineLoudness", value = 100.5 },
        { field = "enginePower", getter = "getEnginePower", value = 100.5 },
    }) do
        UTCore._vehicleTraitDefs = {}
        local vehicle = MockVehicle()
        vehicle[hostile.getter] = function() return hostile.value end
        local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
        UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
            engineQuality = 0.5,
            engineLoudness = 0.5,
            enginePower = 2,
        }, 1)

        Events.OnEnterVehicle.fire(player)

        local ownership = vehicle:getModData().UT_vehicleTraitOwnership
        assert_eq(vehicle._setterCalls.engineFeature or 0, 0,
            hostile.field .. " fractional acquisition must not call the grouped setter")
        assert_eq(ownership.fields[hostile.field], nil,
            hostile.field .. " fractional acquisition must remain unresolved")
        assert_eq(ownership.restoreAttempts.engineFields, nil,
            hostile.field .. " fractional acquisition must not consume retry budget")
    end
end)

test("Vehicle engine fields retain restore evidence for fractional reads without consuming retries", function()
    for _, hostile in ipairs({
        { field = "engineQuality", storage = "_engineQuality", value = 50.5 },
        { field = "engineLoudness", storage = "_engineLoudness", value = 50.5 },
        { field = "enginePower", storage = "_enginePower", value = 200.5 },
    }) do
        UTCore._vehicleTraitDefs = {}
        local vehicle = MockVehicle()
        local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
        UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
            engineQuality = 0.5,
            engineLoudness = 0.5,
            enginePower = 2,
        }, 1)
        Events.OnEnterVehicle.fire(player)
        local callsAfterApply = vehicle._setterCalls.engineFeature
        vehicle[hostile.storage] = hostile.value

        player:setVehicle(nil)
        UTCore.updateVehicleTraitState(player)

        local ownership = vehicle:getModData().UT_vehicleTraitOwnership
        assert_eq(vehicle._setterCalls.engineFeature, callsAfterApply,
            hostile.field .. " fractional restore read must not call the grouped setter")
        assert_true(type(ownership.fields[hostile.field]) == "table",
            hostile.field .. " fractional restore read must retain ownership evidence")
        assert_eq(ownership.restoreAttempts.engineFields, nil,
            hostile.field .. " fractional restore read must not consume retry budget")
    end
end)

test("Vehicle engine fields accept integer domain boundaries", function()
    for _, boundary in ipairs({
        { name = "lower", engineQuality = 0, engineLoudness = 0, enginePower = 0 },
        { name = "quality upper", engineQuality = 100, engineLoudness = 1, enginePower = 1 },
    }) do
        UTCore._vehicleTraitDefs = {}
        local vehicle = MockVehicle()
        vehicle._engineQuality = boundary.engineQuality
        vehicle._engineLoudness = boundary.engineLoudness
        vehicle._enginePower = boundary.enginePower
        local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle, driving = true })
        UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
            engineQuality = 1,
            engineLoudness = 1,
            enginePower = 1,
        }, 1)

        Events.OnEnterVehicle.fire(player)

        local fields = vehicle:getModData().UT_vehicleTraitOwnership.fields
        assert_eq(fields.engineQuality.baseline, boundary.engineQuality,
            boundary.name .. " quality integer must be acquired")
        assert_eq(fields.engineLoudness.baseline, boundary.engineLoudness,
            boundary.name .. " loudness integer must be acquired")
        assert_eq(fields.enginePower.baseline, boundary.enginePower,
            boundary.name .. " power integer must be acquired")
        assert_eq(vehicle._setterCalls.engineFeature or 0, 0,
            boundary.name .. " equal integer targets must not trigger a setter")
    end
end)

-- ===== ZombieCollisionHook tests =====

local function withCollisionDebugHarness(body)
    local oldPrint = _G.print
    local oldFormat = string.format
    local oldTostring = _G.tostring
    local oldDebug = UTCore._debugCollisions
    local oldCell = _G._mockCell
    local messages = {}
    _G.print = function(message) messages[#messages + 1] = message end
    local ok, err = pcall(body, messages)
    _G.print = oldPrint
    string.format = oldFormat
    _G.tostring = oldTostring
    UTCore._debugCollisions = oldDebug
    _G._mockCell = oldCell
    if not ok then error(err, 0) end
end

local function collisionDebugFixture(modData)
    UTCore._zombieCollisionCallbacks = {}
    UTCore._zombieCollisionCallbackCount = 0
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    for key, value in pairs(modData or {}) do p:getModData()[key] = value end
    return p, z
end

test("ZombieCollisionHook per-save debug logs cleanup", function()
    withCollisionDebugHarness(function(messages)
        UTCore._debugCollisions = false
        local p = collisionDebugFixture({ UT_DEBUG_COLLISIONS = true, UT_bumpSuppress = true })
        UTCore.registerZombieCollisionHandler("test_trait", function() end)
        Events.OnPlayerUpdate.fire(p)
        assert_eq(messages[1], "[UTCore:ZCollision] Cleaned up old suppression moddata")
    end)
end)

test("ZombieCollisionHook per-save debug logs entry once and prefixes callback error", function()
    withCollisionDebugHarness(function(messages)
        UTCore._debugCollisions = false
        local p = collisionDebugFixture({ UT_DEBUG_COLLISIONS = true })
        p:setRunning(true)
        UTCore.registerZombieCollisionHandler("test_trait", function() error("debug boom") end)
        Events.OnPlayerUpdate.fire(p)
        Events.OnPlayerUpdate.fire(p)
        assert_eq(#messages, 2, "sustained range should log entry and callback error only once")
        assert_true(messages[1]:find("[UTCore:ZCollision] Zombie in range:", 1, true) == 1)
        assert_true(messages[2]:find("[UTCore:ZCollision] Callback ERROR [test_trait]:", 1, true) == 1)
        assert_true(messages[2]:find("debug boom", 1, true) ~= nil)
    end)
end)

test("ZombieCollisionHook suppresses all debug work when both toggles are false", function()
    withCollisionDebugHarness(function(messages)
        UTCore._debugCollisions = false
        local p = collisionDebugFixture({ UT_bumpSuppress = true })
        UTCore.registerZombieCollisionHandler("test_trait", function() end)
        Events.OnPlayerUpdate.fire(p)
        p:setRunning(true)
        local formatCalls, errorTostringCalls = 0, 0
        local realFormat, realTostring = string.format, tostring
        string.format = function(...) formatCalls = formatCalls + 1; return realFormat(...) end
        local callbackError = setmetatable({}, { __tostring = function() return "silent boom" end })
        _G.tostring = function(value)
            if value == callbackError then errorTostringCalls = errorTostringCalls + 1 end
            return realTostring(value)
        end
        UTCore.registerZombieCollisionHandler("test_trait", function() error(callbackError) end)
        Events.OnPlayerUpdate.fire(p)
        assert_eq(#messages, 0, "cleanup, entry, and callback error should all be silent")
        assert_eq(formatCalls, 0, "range formatting should be lazy while debug is disabled")
        assert_eq(errorTostringCalls, 0, "callback errors should not stringify while debug is disabled")
    end)
end)

test("ZombieCollisionHook global debug still logs when per-save debug is false", function()
    withCollisionDebugHarness(function(messages)
        UTCore._debugCollisions = true
        local p = collisionDebugFixture({ UT_DEBUG_COLLISIONS = false })
        p:setRunning(true)
        UTCore.registerZombieCollisionHandler("test_trait", function() end)
        Events.OnPlayerUpdate.fire(p)
        assert_true(messages[1]:find("[UTCore:ZCollision] Zombie in range:", 1, true) == 1)
    end)
end)

test("registerZombieCollisionHandler stores callback", function()
    UTCore._zombieCollisionCallbacks = {}
    local fn = function() end
    UTCore.registerZombieCollisionHandler("test_trait", fn)
    assert_eq(UTCore._zombieCollisionCallbacks["test_trait"], fn)
end)

test("unregisterZombieCollisionHandler removes callback", function()
    UTCore._zombieCollisionCallbacks = {}
    UTCore.registerZombieCollisionHandler("test_trait", function() end)
    UTCore.unregisterZombieCollisionHandler("test_trait")
    assert_eq(UTCore._zombieCollisionCallbacks["test_trait"], nil)
end)

test("ZombieCollisionHook fires callback on rising edge with zombie", function()
    UTCore._zombieCollisionCallbacks = {}
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    local firedPlayer, firedZombie
    UTCore.registerZombieCollisionHandler("test_trait", function(player, zombie)
        firedPlayer = player
        firedZombie = zombie
    end)
    Events.OnPlayerUpdate.fire(p)
    _G._mockCell = nil
    assert_eq(firedPlayer, p, "callback should receive the player")
    assert_eq(firedZombie, z, "callback should receive the zombie")
end)

test("ZombieCollisionHook does NOT re-fire on sustained bump", function()
    UTCore._zombieCollisionCallbacks = {}
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    local callCount = 0
    UTCore.registerZombieCollisionHandler("test_trait", function() callCount = callCount + 1 end)
    Events.OnPlayerUpdate.fire(p)   -- rising edge
    Events.OnPlayerUpdate.fire(p)   -- still in range
    _G._mockCell = nil
    assert_eq(callCount, 1, "expected exactly 1 fire for a sustained presence")
end)

test("ZombieCollisionHook does NOT fire for non-zombie bumpedChr", function()
    UTCore._zombieCollisionCallbacks = {}
    -- Place non-zombie moving object on the square
    local notZombie = { getName = function() return "survivor" end, _mockType = "IsoPlayer",
        getX = function(self) return 0.3 end, getY = function(self) return 0 end, getZ = function(self) return 0 end }
    local sq = MockCollisionSquare(0, 0, 0, {notZombie})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    local fired = false
    UTCore.registerZombieCollisionHandler("test_trait", function() fired = true end)
    Events.OnPlayerUpdate.fire(p)
    _G._mockCell = nil
    assert_eq(fired, false, "expected no callback for non-zombie moving object")
end)

test("ZombieCollisionHook does NOT fire when bumpedChr is nil", function()
    UTCore._zombieCollisionCallbacks = {}
    local p = MockPlayer()
    local fired = false
    UTCore.registerZombieCollisionHandler("test_trait", function() fired = true end)
    p:setBumpType("stagger")   -- bumped, but no entity set
    Events.OnPlayerUpdate.fire(p)
    assert_eq(fired, false, "expected no callback when bumpedChr is nil")
end)

test("ZombieCollisionHook does NOT set bumpedChr (v4 knockdown-only)", function()
    UTCore._zombieCollisionCallbacks = {}
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    UTCore.registerZombieCollisionHandler("test_trait", function() end)
    Events.OnPlayerUpdate.fire(p)
    _G._mockCell = nil
    -- v4: hook never touches player bump state
    assert_eq(p:getBumpedChr(), nil, "hook must NOT set bumpedChr (v4)")
end)

test("ZombieCollisionHook clears handled set when player stops running", function()
    UTCore._zombieCollisionCallbacks = {}
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    UTCore.registerZombieCollisionHandler("test_trait", function() end)
    Events.OnPlayerUpdate.fire(p)
    assert_true(p:getModData().UT_handledZombies ~= nil, "handled set should exist while running")

    -- Player stops running - handled set should be cleared for fresh start
    p:setRunning(false)
    Events.OnPlayerUpdate.fire(p)
    _G._mockCell = nil
    assert_eq(p:getModData().UT_handledZombies, nil,
        "handled set should be cleared when player stops running")
end)

test("ZombieCollisionHook ignores dead zombies", function()
    UTCore._zombieCollisionCallbacks = {}
    local z = MockZombie({ x = 0.3, y = 0, z = 0 })
    local sq = MockCollisionSquare(0, 0, 0, {z})
    local squares = { ["0,0,0"] = sq }
    for dx = -1, 1 do for dy = -1, 1 do
        if dx ~= 0 or dy ~= 0 then squares[dx..","..dy..",0"] = MockCollisionSquare(dx, dy, 0, {}) end
    end end
    _G._mockCell = MockCell(squares)
    local p = MockPlayer({}, { square = sq })
    p:setRunning(true)
    local callCount = 0
    UTCore.registerZombieCollisionHandler("test_trait", function() callCount = callCount + 1 end)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(callCount, 1, "expected callback for live zombie")

    -- Kill the zombie - corpse stays on the square
    z:setDead(true)
    p:getModData().UT_handledZombies = nil  -- reset dedup so we'd fire again IF it were alive
    Events.OnPlayerUpdate.fire(p)
    _G._mockCell = nil
    assert_eq(callCount, 1, "expected no callback for dead zombie")
end)

-- ===== declareZombieCollisionHandler + auto-registration tests =====

test("declareZombieCollisionHandler auto-registers on OnCreatePlayer for active trait", function()
    UTCore._zombieCollisionCallbacks = {}
    local fn = function() end
    UTCore.declareZombieCollisionHandler("UniversalTraits:UT_test_declare", fn)
    local p = MockPlayer({ "UniversalTraits:UT_test_declare" })
    Events.OnCreatePlayer.fire(0, p)
    assert_eq(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_test_declare"], fn,
        "expected callback registered after OnCreatePlayer")
end)

test("declareZombieCollisionHandler does NOT register for player without trait", function()
    UTCore._zombieCollisionCallbacks = {}
    UTCore._zombieCollisionCallbackCount = 0
    UTCore.declareZombieCollisionHandler("UniversalTraits:UT_test_notrait", function() end)
    local p = MockPlayer({})
    Events.OnCreatePlayer.fire(0, p)
    assert_eq(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_test_notrait"], nil,
        "expected no callback for player lacking the trait")
end)

test("declareZombieCollisionHandler removes stale callback on player switch", function()
    UTCore._zombieCollisionCallbacks = {}
    UTCore._zombieCollisionCallbackCount = 0
    local traitId = "UniversalTraits:UT_test_player_switch"
    local fn = function() end
    UTCore.declareZombieCollisionHandler(traitId, fn)

    Events.OnCreatePlayer.fire(0, MockPlayer({ traitId }))
    assert_eq(UTCore._zombieCollisionCallbacks[traitId], fn,
        "expected callback for the first player")
    assert_eq(UTCore._zombieCollisionCallbackCount, 1,
        "expected one active callback")

    Events.OnCreatePlayer.fire(0, MockPlayer({}))
    assert_eq(UTCore._zombieCollisionCallbacks[traitId], nil,
        "expected callback removed for the next player without the trait")
    assert_eq(UTCore._zombieCollisionCallbackCount, 0,
        "expected reconciled callback count")
end)

test("integrity check re-registers cleared declared handler", function()
    UTCore._zombieCollisionCallbacks = {}
    local fn = function() end
    UTCore.declareZombieCollisionHandler("UniversalTraits:UT_test_integrity", fn)
    local p = MockPlayer({ "UniversalTraits:UT_test_integrity" })
    _G.getPlayer = function() return p end
    Events.OnCreatePlayer.fire(0, p)
    assert_eq(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_test_integrity"], fn)

    -- Simulate something clearing the callbacks table
    UTCore._zombieCollisionCallbacks = {}

    -- Fire EveryOneMinute 10 times to trigger the integrity check
    for _ = 1, 10 do Events.EveryOneMinute.fire() end

    assert_eq(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_test_integrity"], fn,
        "expected integrity check to re-register the cleared callback")
    _G.getPlayer = function() return nil end
end)

test("integrity check removes declared handler after trait loss", function()
    UTCore._zombieCollisionCallbacks = {}
    UTCore._zombieCollisionCallbackCount = 0
    local traitId = "UniversalTraits:UT_test_integrity_removal"
    local fn = function() end
    UTCore.declareZombieCollisionHandler(traitId, fn)
    local activePlayer = MockPlayer({ traitId })
    Events.OnCreatePlayer.fire(0, activePlayer)
    assert_eq(UTCore._zombieCollisionCallbacks[traitId], fn)

    _G.getPlayer = function() return MockPlayer({}) end
    for _ = 1, 10 do Events.EveryOneMinute.fire() end

    assert_eq(UTCore._zombieCollisionCallbacks[traitId], nil,
        "expected integrity reconciliation to remove the inactive callback")
    assert_eq(UTCore._zombieCollisionCallbackCount, 0,
        "expected reconciled callback count")
    _G.getPlayer = function() return nil end
end)

-- ===== PainHook tests =====

test("PainHook zeroes pain when UT_painImmune is true", function()
    local p = MockPlayer({})
    p:getStats():set(CharacterStat.PAIN, 50)
    p:getModData()["UT_painImmune"] = true
    _G.getPlayer = function() return p end
    Events.OnPlayerUpdate.fire(p)
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():get(CharacterStat.PAIN), 0, "expected pain cleared to 0")
end)

test("PainHook does not touch pain when UT_painImmune is absent", function()
    local p = MockPlayer({})
    p:getStats():set(CharacterStat.PAIN, 50)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(p:getStats():get(CharacterStat.PAIN), 50, "expected pain unchanged when trait not set")
end)

-- ===== DamageMultHook tests =====

local function makeDamageMultPlayer(multiplier, initialHealth, partHealths, modifiers)
    local p = MockPlayer({})
    local reportedHealth = initialHealth or 100
    local parts = {}
    local setCalls = {}
    partHealths = partHealths or { reportedHealth }
    modifiers = modifiers or { 1 }

    for index, initialPartHealth in ipairs(partHealths) do
        local partHealth = initialPartHealth
        parts[index] = {
            getType = function() return index - 1 end,
            getHealth = function() return partHealth end,
            SetHealth = function(_, value)
                setCalls[#setCalls + 1] = { index = index, value = value }
                partHealth = value
            end,
            currentHealth = function() return partHealth end,
            setResolvedHealth = function(value) partHealth = value end,
        }
    end

    local bodyParts = {
        size = function() return #parts end,
        get = function(_, index) return parts[index + 1] end,
    }
    local bodyDamage = {
        getOverallBodyHealth = function() return reportedHealth end,
        getBodyParts = function() return bodyParts end,
    }
    p:setBodyDamage(bodyDamage)
    p:getModData()["UT_damageMult"] = multiplier
    local savedModifiers = BodyPartType._damageModifiers
    BodyPartType._damageModifiers = modifiers
    return p, {
        setResolvedHealth = function(value, resolvedPartHealths)
            reportedHealth = value
            if resolvedPartHealths then
                for index, partHealth in ipairs(resolvedPartHealths) do
                    parts[index].setResolvedHealth(partHealth)
                    partHealths[index] = partHealth
                end
            elseif #parts == 1 and modifiers[1] == 1 then
                parts[1].setResolvedHealth(value)
                partHealths[1] = value
            end
        end,
        flushOverallHealth = function()
            local totalDamage = 0
            for index, part in ipairs(parts) do
                totalDamage = totalDamage + (100 - part.currentHealth()) * modifiers[index]
            end
            reportedHealth = math.max(0, 100 - totalDamage)
        end,
        overallAppliedLoss = function()
            local loss = 0
            for _, call in ipairs(setCalls) do
                local before = partHealths[call.index]
                loss = loss + (before - call.value) * modifiers[call.index]
                partHealths[call.index] = call.value
            end
            setCalls = {}
            return loss
        end,
        partHealth = function(index) return parts[index].currentHealth() end,
        setCalls = function() return setCalls end,
        restore = function() BodyPartType._damageModifiers = savedModifiers end,
        bodyDamage = bodyDamage,
        bodyParts = bodyParts,
        parts = parts,
    }
end

test("DamageMultHook applies +50 percent to an observed aggregate health loss", function()
    local p, health = makeDamageMultPlayer(1.5, 100, { 100, 100 }, { 0.25, 0.75 })
    Events.OnPlayerUpdate.fire(p) -- establish the baseline
    -- The aggregate observer sees 20 net loss in the body-part state.
    health.setResolvedHealth(80, { 20, 100 })
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 10, 0.0001, "expected 50 percent extra damage")
    health.restore()
end)

test("DamageMultHook does not multiply its own deferred body-part reduction", function()
    local p, health = makeDamageMultPlayer(1.5, 100, { 100 }, { 1 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 10, 0.0001)
    health.flushOverallHealth() -- mirrors the next BodyDamage.calculateOverallHealth
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "expected no recursive extra-damage application")
    health.restore()
end)

test("DamageMultHook does nothing when mult is 1.0", function()
    local p, health = makeDamageMultPlayer(1.0, 100)
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "expected no extra loss when mult=1.0")
    health.restore()
end)

test("DamageMultHook resets without a trait marker and activates from a fresh baseline", function()
    local p, health = makeDamageMultPlayer(nil, 100)
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "missing marker must not apply damage")

    p:getModData()["UT_damageMult"] = 1.5
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "activation update must establish a baseline")
    health.setResolvedHealth(70)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 5, 0.0001)

    p:getModData()["UT_damageMult"] = nil
    Events.OnPlayerUpdate.fire(p)
    p:getModData()["UT_damageMult"] = 1.5
    health.setResolvedHealth(50)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "reactivation must not attribute inactive loss")
    health.restore()
end)

test("DamageMultHook resets its baseline after healing", function()
    local p, health = makeDamageMultPlayer(1.5, 70)
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(90)
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 5, 0.0001, "expected only later 10-point loss multiplied")
    health.restore()
end)

test("DamageMultHook caps extra damage at remaining health", function()
    local p, health = makeDamageMultPlayer(3.0, 10, { 10 }, { 1 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(4)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 4, 0.0001, "expected extra damage capped at remaining health")
    assert_close(health.partHealth(1), 0, 0.0001, "expected zero body-part health")
    health.restore()
end)

test("DamageMultHook initializes a replacement player without cross-attributing loss", function()
    local first, firstHealth = makeDamageMultPlayer(1.5, 100)
    local second, secondHealth = makeDamageMultPlayer(1.5, 35)
    Events.OnPlayerUpdate.fire(first)
    Events.OnPlayerUpdate.fire(second)
    assert_eq(#firstHealth.setCalls(), 0, "expected no loss on the first player")
    assert_eq(#secondHealth.setCalls(), 0, "expected replacement player to establish a baseline")
    secondHealth.restore()
    firstHealth.restore()
end)

test("DamageMultHook consumes exact weighted loss across depleted parts", function()
    local p, health = makeDamageMultPlayer(1.5, 90, { 0, 0, 100 }, { 0.05, 0.05, 0.9 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(70, { 0, 0, 77.7777777778 })
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 10, 0.0001)
    assert_eq(health.partHealth(1), 0, "depleted part must remain at zero")
    assert_eq(health.partHealth(2), 0, "second depleted part must remain at zero")
    assert(health.partHealth(3) >= 0, "remaining part must never become negative")
    health.restore()
end)

test("DamageMultHook applies all representable overkill without negative health", function()
    local p, health = makeDamageMultPlayer(4.0, 8, { 0, 2 }, { 1, 1 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(2)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.overallAppliedLoss(), 2, 0.0001)
    assert_eq(health.partHealth(2), 0)
    health.restore()
end)

test("DamageMultHook ignores zero loss, malformed bridges, and throwing setters", function()
    local p, health = makeDamageMultPlayer(1.5, 100, { 100, 100 }, { 0.05, 0.95 })
    Events.OnPlayerUpdate.fire(p)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "zero loss must not write")

    health.bodyParts.size = function() return math.huge end
    health.setResolvedHealth(80)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(#health.setCalls(), 0, "malformed list must fail closed")

    health.bodyParts.size = function() return 2 end
    health.parts[2].SetHealth = function() error("bridge failure") end
    health.setResolvedHealth(60)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.partHealth(1), 100, 0.0001, "earlier writes must roll back")

    health.parts[2].SetHealth = function() end
    health.parts[1].getHealth = function() error("getter failure") end
    health.setResolvedHealth(40)
    Events.OnPlayerUpdate.fire(p)
    assert_close(health.partHealth(1), 100, 0.0001, "throwing getter must fail closed")
    health.restore()
end)

test("DamageMultHook contains every throwing or malformed read bridge", function()
    local cases = {
        { "getModData", function(p) p.getModData = function() error("getModData") end end, true },
        { "getBodyDamage", function(p) p.getBodyDamage = function() error("getBodyDamage") end end, true },
        { "getOverallBodyHealth", function(_, h) h.bodyDamage.getOverallBodyHealth = function() error("overall") end end },
        { "getBodyParts", function(_, h) h.bodyDamage.getBodyParts = function() error("parts") end end },
        { "list size", function(_, h) h.bodyParts.size = function() error("size") end end },
        { "list get", function(_, h) h.bodyParts.get = function() error("get") end end },
        { "part getHealth", function(_, h) h.parts[1].getHealth = function() error("health") end end },
        { "part getType", function(_, h) h.parts[1].getType = function() error("type") end end },
    }

    for _, case in ipairs(cases) do
        local savedToIndex = BodyPartType.ToIndex
        local savedWeight = BodyPartType.getDamageModifyer
        local p, health = makeDamageMultPlayer(1.5, 100)
        if not case[3] then UTCore._damageMultUpdateHandler(p) end
        case[2](p, health)
        health.setResolvedHealth(80)
        local ok = pcall(UTCore._damageMultUpdateHandler, p)
        assert(ok, case[1] .. " failure must not escape")
        assert_eq(#health.setCalls(), 0, case[1] .. " failure must not write")
        BodyPartType.ToIndex = savedToIndex
        BodyPartType.getDamageModifyer = savedWeight
        health.restore()
    end
end)

test("DamageMultHook contains hostile static lookup and calls with exact bounds", function()
    local originalBodyPartType = BodyPartType
    local cases = {
        {
            name = "malformed ToIndex member",
            install = function()
                BodyPartType = {
                    ToIndex = "not-a-function",
                    getDamageModifyer = originalBodyPartType.getDamageModifyer,
                }
            end,
            expectedLookups = 0,
            expectedCalls = 0,
        },
        {
            name = "throwing ToIndex lookup",
            install = function(state)
                BodyPartType = setmetatable({}, {
                    __index = function(_, key)
                        state.lookups = state.lookups + 1
                        if key == "ToIndex" then error("ToIndex lookup") end
                        return originalBodyPartType[key]
                    end,
                })
            end,
            expectedLookups = 2,
            expectedCalls = 0,
        },
        {
            name = "malformed getDamageModifyer member",
            install = function()
                BodyPartType = {
                    ToIndex = originalBodyPartType.ToIndex,
                    getDamageModifyer = false,
                }
            end,
            expectedLookups = 0,
            expectedCalls = 0,
        },
        {
            name = "throwing getDamageModifyer lookup",
            install = function(state)
                BodyPartType = setmetatable({}, {
                    __index = function(_, key)
                        state.lookups = state.lookups + 1
                        if key == "getDamageModifyer" then error("modifier lookup") end
                        return originalBodyPartType[key]
                    end,
                })
            end,
            expectedLookups = 2,
            expectedCalls = 0,
        },
        {
            name = "throwing ToIndex call",
            install = function(state)
                BodyPartType = {
                    ToIndex = function()
                        state.calls = state.calls + 1
                        error("ToIndex call")
                    end,
                    getDamageModifyer = originalBodyPartType.getDamageModifyer,
                }
            end,
            expectedLookups = 0,
            expectedCalls = 1,
        },
        {
            name = "throwing getDamageModifyer call",
            install = function(state)
                BodyPartType = {
                    ToIndex = originalBodyPartType.ToIndex,
                    getDamageModifyer = function()
                        state.calls = state.calls + 1
                        error("modifier call")
                    end,
                }
            end,
            expectedLookups = 0,
            expectedCalls = 1,
        },
    }

    for _, case in ipairs(cases) do
        BodyPartType = originalBodyPartType
        local p, health = makeDamageMultPlayer(1.5, 100)
        UTCore._damageMultUpdateHandler(p)
        local state = { lookups = 0, calls = 0 }
        case.install(state)
        health.setResolvedHealth(80)
        local ok = pcall(UTCore._damageMultUpdateHandler, p)
        BodyPartType = originalBodyPartType
        assert(ok, case.name .. " must not escape")
        assert_eq(#health.setCalls(), 0, case.name .. " must not write")
        assert_eq(state.lookups, case.expectedLookups, case.name .. " lookup bound")
        assert_eq(state.calls, case.expectedCalls, case.name .. " call bound")
        health.restore()
    end
end)

test("DamageMultHook rolls back the setter that mutates then throws", function()
    local p, health = makeDamageMultPlayer(1.5, 100, { 1, 100 }, { 0.05, 0.95 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80, { 1, 84.1578947368 })

    local firstCalls = 0
    local secondCalls = 0
    local firstSet = health.parts[1].SetHealth
    health.parts[1].SetHealth = function(self, value)
        firstCalls = firstCalls + 1
        firstSet(self, value)
    end
    local secondSet = health.parts[2].SetHealth
    health.parts[2].SetHealth = function(self, value)
        secondCalls = secondCalls + 1
        secondSet(self, value)
        if secondCalls == 1 then error("post-mutation failure") end
    end

    local ok = pcall(Events.OnPlayerUpdate.fire, p)
    assert(ok, "post-mutation setter failure must not escape")
    assert_close(health.partHealth(1), 1, 0.0001, "prior entry must roll back")
    assert_close(health.partHealth(2), 84.1578947368, 0.0001, "throwing entry must also roll back")
    assert_eq(firstCalls, 2, "first setter must apply once and roll back once")
    assert_eq(secondCalls, 2, "throwing setter must apply once and roll back once")
    health.restore()
end)

test("DamageMultHook contains rollback failure and rebases from actual weighted state", function()
    local p, health = makeDamageMultPlayer(1.5, 100, { 1, 100 }, { 0.05, 0.95 })
    Events.OnPlayerUpdate.fire(p)
    health.setResolvedHealth(80, { 1, 84.1578947368 })

    local firstCalls = 0
    local secondCalls = 0
    local firstSet = health.parts[1].SetHealth
    health.parts[1].SetHealth = function(self, value)
        firstCalls = firstCalls + 1
        firstSet(self, value)
    end
    local secondSet = health.parts[2].SetHealth
    health.parts[2].SetHealth = function(self, value)
        secondCalls = secondCalls + 1
        if secondCalls == 1 then
            secondSet(self, value)
            error("post-mutation failure")
        end
        error("rollback failure")
    end

    local ok = pcall(Events.OnPlayerUpdate.fire, p)
    assert(ok, "rollback failure must not escape")
    assert_close(health.partHealth(1), 1, 0.0001, "successful rollback must restore prior entry")
    assert_close(health.partHealth(2), 73.6842105263, 0.0001,
        "failed rollback leaves only the contained write")
    assert_eq(firstCalls, 2, "first setter call bound")
    assert_eq(secondCalls, 2, "throwing setter call bound")

    health.flushOverallHealth()
    Events.OnPlayerUpdate.fire(p)
    assert_eq(firstCalls, 2, "rebased state must not recursively write the first part")
    assert_eq(secondCalls, 2, "rebased state must not recursively amplify the partial write")
    health.restore()
end)

test("DamageMultHook reload replaces behavior without adding a dispatcher", function()
    local coreCount = UTCore.getCoreHandlerCount()
    local weaponCount = Events.OnWeaponHitCharacter._handlerCount()
    dofile(base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
    assert_eq(UTCore.getCoreHandlerCount(), coreCount, "expected one stored core dispatcher")
    assert_eq(Events.OnWeaponHitCharacter._handlerCount(), weaponCount,
        "expected no damage-multiplier weapon listener after reload")
end)

test("DamageMultHook reload contains throwing event Remove bridges", function()
    local savedRegister = UTCore.registerCoreHandler
    local savedWeaponRemove = Events.OnWeaponHitCharacter.Remove
    local savedUpdateRemove = Events.OnPlayerUpdate.Remove

    UTCore._damageMultWeaponHitHandler = function() end
    UTCore._damageMultDirectHandler = function() end
    Events.OnWeaponHitCharacter.Remove = function() error("weapon remove") end
    Events.OnPlayerUpdate.Remove = function() error("update remove") end
    local okRemove = pcall(dofile, base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
    assert(okRemove, "throwing event Remove bridges must not escape")

    Events.OnWeaponHitCharacter.Remove = savedWeaponRemove
    Events.OnPlayerUpdate.Remove = savedUpdateRemove
    UTCore.registerCoreHandler = savedRegister
    dofile(base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
end)

test("DamageMultHook fails closed for hostile core registration with exact bounds", function()
    local originalRegister = UTCore.registerCoreHandler
    local originalMetatable = getmetatable(UTCore)
    local originalAdd = Events.OnPlayerUpdate.Add
    local cases = {
        {
            name = "missing registration",
            install = function() UTCore.registerCoreHandler = nil end,
            expectedLookups = 0,
            expectedCalls = 0,
            expectedSafe = false,
        },
        {
            name = "malformed registration",
            install = function() UTCore.registerCoreHandler = "not-a-function" end,
            expectedLookups = 0,
            expectedCalls = 0,
            expectedSafe = false,
        },
        {
            name = "throwing registration lookup",
            install = function(state)
                UTCore.registerCoreHandler = nil
                setmetatable(UTCore, {
                    __index = function(_, key)
                        if key == "registerCoreHandler" then
                            state.lookups = state.lookups + 1
                            error("registration lookup")
                        end
                        if originalMetatable and originalMetatable.__index then
                            if type(originalMetatable.__index) == "function" then
                                return originalMetatable.__index(UTCore, key)
                            end
                            return originalMetatable.__index[key]
                        end
                        return nil
                    end,
                })
            end,
            expectedLookups = 1,
            expectedCalls = 0,
            expectedSafe = false,
        },
        {
            name = "throwing registration call",
            install = function(state)
                UTCore.registerCoreHandler = function()
                    state.calls = state.calls + 1
                    error("registration call")
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = false,
        },
        {
            name = "unsafe matching row then throw",
            install = function(state)
                UTCore.registerCoreHandler = function(id)
                    state.calls = state.calls + 1
                    table.insert(UTCore._coreHandlers, {
                        id = id,
                        fn = function() error("unsafe") end,
                        throttle = 0,
                        priority = 0,
                    })
                    UTCore._coreHandlerCount = UTCore._coreHandlerCount + 1
                    error("unsafe row inserted")
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = false,
        },
        {
            name = "unsafe and intended rows then throw",
            install = function(state)
                UTCore.registerCoreHandler = function(id, fn)
                    state.calls = state.calls + 1
                    table.insert(UTCore._coreHandlers, {
                        id = id,
                        fn = function() error("unsafe") end,
                    })
                    table.insert(UTCore._coreHandlers, { id = id, fn = fn })
                    UTCore._coreHandlerCount = UTCore._coreHandlerCount + 2
                    error("mixed rows inserted")
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = false,
        },
        {
            name = "registration ignores key",
            install = function(state)
                UTCore.registerCoreHandler = function(_, fn)
                    state.calls = state.calls + 1
                    table.insert(UTCore._coreHandlers, {
                        id = "IgnoredDamageMultKey",
                        fn = fn,
                    })
                    UTCore._coreHandlerCount = UTCore._coreHandlerCount + 1
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = false,
        },
        {
            name = "partial table mutation without count",
            install = function(state)
                UTCore.registerCoreHandler = function(id)
                    state.calls = state.calls + 1
                    table.insert(UTCore._coreHandlers, {
                        id = id,
                        fn = function() error("unsafe") end,
                    })
                    error("count not updated")
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = false,
        },
        {
            name = "duplicate intended rows",
            install = function(state)
                UTCore.registerCoreHandler = function(id, fn)
                    state.calls = state.calls + 1
                    table.insert(UTCore._coreHandlers, { id = id, fn = fn })
                    table.insert(UTCore._coreHandlers, { id = id, fn = fn })
                    UTCore._coreHandlerCount = UTCore._coreHandlerCount + 2
                end
            end,
            expectedLookups = 0,
            expectedCalls = 1,
            expectedSafe = true,
        },
    }

    for _, case in ipairs(cases) do
        setmetatable(UTCore, originalMetatable)
        UTCore.registerCoreHandler = originalRegister
        originalRegister("DamageMultHook", UTCore._damageMultTickDispatcher, { priority = 0 })
        local originalCount = UTCore.getCoreHandlerCount()
        local state = { lookups = 0, calls = 0, adds = 0 }
        Events.OnPlayerUpdate.Add = function(...)
            state.adds = state.adds + 1
            return originalAdd(...)
        end
        case.install(state)
        local ok = pcall(dofile, base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
        assert(ok, case.name .. " must not escape")
        assert_eq(state.lookups, case.expectedLookups, case.name .. " lookup bound")
        assert_eq(state.calls, case.expectedCalls, case.name .. " call bound")
        assert_eq(state.adds, 0, case.name .. " must not install a direct fallback")
        local expectedCount = originalCount - (case.expectedSafe and 0 or 1)
        assert_eq(UTCore.getCoreHandlerCount(), expectedCount,
            case.name .. " must leave the exact total row count")
        assert_eq(#UTCore._coreHandlers, expectedCount,
            case.name .. " table and authoritative count must agree")
        local damageRows = 0
        for _, row in ipairs(UTCore._coreHandlers) do
            if row.id == "DamageMultHook" or row.fn == UTCore._damageMultTickDispatcher then
                damageRows = damageRows + 1
                assert_eq(row.id, "DamageMultHook",
                    case.name .. " matching row must retain the canonical key")
                assert_eq(row.fn, UTCore._damageMultTickDispatcher,
                    case.name .. " matching row must retain the exact safe dispatcher")
            end
        end
        assert_eq(damageRows, case.expectedSafe and 1 or 0,
            case.name .. " must leave exactly the expected safe registrations")
    end

    setmetatable(UTCore, originalMetatable)
    UTCore.registerCoreHandler = originalRegister
    Events.OnPlayerUpdate.Add = originalAdd
    dofile(base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
end)

-- ===== FractureHook tests =====
-- ZombRand always returns 0 in tests (set in mocks), so any chance > 0 succeeds.

test("FractureHook fractures eligible part on successful roll", function()
    setMockGameTime(100, 0)
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.5
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, p, nil, 20)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:getFractureTime(), 21, "expected fracture duration of 21")
    assert_eq(legPart:isFractured(), true, "expected Leg_L to be fractured on successful roll")
    assert(
        p:getModData()["UT_fractureCooldownUntil"] > 100,
        "expected elapsed-time cooldown set after fracture"
    )
end)

test("FractureHook does nothing when fractureMult is 1.0", function()
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.0
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, p, nil, 20)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:isFractured(), false, "expected no fracture when mult<=1.0")
end)

test("FractureHook cooldown expires from elapsed world time without extra hits", function()
    setMockGameTime(100, 0)
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.5
    p:getModData()["UT_fractureCooldown"] = 50 -- obsolete save value is discarded
    p:getModData()["UT_fractureCooldownUntil"] = 100 + (10 / 3600)
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, p, nil, 20)
    assert_eq(legPart:getFractureTime(), 0, "expected zero fracture duration before cooldown expiry")
    assert_eq(legPart:isFractured(), false, "expected no fracture before cooldown expiry")
    assert_eq(p:getModData()["UT_fractureCooldown"], nil, "expected legacy cooldown removed")

    setMockGameTime(100 + (11 / 3600), 0)
    Events.OnWeaponHitCharacter.fire(nil, p, nil, 20)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:getFractureTime(), 21, "expected fracture duration of 21 after cooldown expiry")
    assert_eq(legPart:isFractured(), true, "expected fracture after elapsed-time cooldown")
end)

test("FractureHook skips already-fractured parts", function()
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.5
    -- All eligible parts already fractured
    local legL = MockBodyPart(BodyPartType.Leg_L, false, false)
    local legR = MockBodyPart(BodyPartType.Leg_R, false, false)
    legL:setFractured(true)
    legR:setFractured(true)
    p:setBodyDamage(MockBodyDamage({ legL, legR }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, p, nil, 20)
    _G.getPlayer = function() return nil end
    -- No new fracture should be applied (all eligible parts already broken)
    assert_eq(p:getModData()["UT_fractureCooldownUntil"], nil,
        "expected no cooldown set when all parts already fractured")
end)

test("FractureHook reload retains one weapon-hit handler", function()
    local original = UTCore._fractureHookHandler
    local before = Events.OnWeaponHitCharacter._handlerCount()
    Events.OnWeaponHitCharacter.Remove(original)
    assert_eq(Events.OnWeaponHitCharacter._handlerCount(), before - 1,
        "expected exactly one registered occurrence of the stored fracture handler")
    Events.OnWeaponHitCharacter.Add(original)
    dofile(base .. "../media/lua/shared/UTCore/UTCore_FractureHook.lua")
    assert_eq(Events.OnWeaponHitCharacter._handlerCount(), before,
        "expected reload to replace rather than duplicate the fracture handler")
    assert_true(UTCore._fractureHookHandler ~= original,
        "expected reload to install the new function object")
end)

-- ===== NoiseHook tests =====

test("NoiseHook emits noise when sleeping with noiseMult > 1.0", function()
    local p = MockPlayer({})
    p:getModData()["UT_noiseMult"] = 2.0
    p:setSleeping(true)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    local calls = p:getNoiseCalls()
    assert_eq(#calls, 1, "expected one makeNoise call")
    assert_eq(calls[1], 5, "expected noise value 5 = floor(5 * (2.0-1.0))")
end)

test("NoiseHook skips noise when not sleeping", function()
    local p = MockPlayer({})
    p:getModData()["UT_noiseMult"] = 2.0
    p:setSleeping(false)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(#p:getNoiseCalls(), 0, "expected no noise when player is awake")
end)

test("NoiseHook skips when noiseMult is absent", function()
    local p = MockPlayer({})
    p:setSleeping(true)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(#p:getNoiseCalls(), 0, "expected no noise when UT_noiseMult not set")
end)

-- ===== SleepQualityHook tests =====

test("SleepQualityHook reduces fatigue while sleeping", function()
    local p = MockPlayer({})
    p:getModData()["UT_sleepQualMod"] = 0.5
    p:setAsleep(true)
    p:getStats():set(CharacterStat.FATIGUE, 0.5)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    -- expected: 0.5 - (0.5 * 0.001) = 0.4995
    local fatigue = p:getStats():get(CharacterStat.FATIGUE)
    assert(fatigue < 0.5, "expected fatigue to decrease while sleeping")
    assert(math.abs(fatigue - 0.4995) < 0.0001,
        "expected fatigue ~0.4995, got " .. tostring(fatigue))
end)

-- ===== Diagnostics Ring Buffer tests =====

test("diagLog adds entries to ring buffer", function()
    UTCore.diagResetRing()
    setMockTimestampMs(1000)
    UTCore.diagLog("TestSrc", "test_evt", "detail1")
    assert_eq(UTCore.diagRingCount(), 1)
    local entry = UTCore.diagRingGet(0)
    assert_eq(entry.src, "TestSrc")
    assert_eq(entry.evt, "test_evt")
    assert_eq(entry.dat, "detail1")
    assert_eq(entry.t, 1000)
end)

test("ring buffer wraps at RING_SIZE", function()
    UTCore.diagResetRing()
    -- Fill beyond 200 entries
    for i = 1, 210 do
        setMockTimestampMs(i * 10)
        UTCore.diagLog("wrap", "fill", "entry_" .. i)
    end
    -- Should cap at 200
    assert_eq(UTCore.diagRingCount(), 200)
    -- Newest entry should be #210
    local newest = UTCore.diagRingGet(0)
    assert_eq(newest.dat, "entry_210")
    -- Oldest should be #11 (first 10 overwritten)
    local oldest = UTCore.diagRingGet(199)
    assert_eq(oldest.dat, "entry_11")
end)

test("diagRingGet returns nil for out-of-range index", function()
    UTCore.diagResetRing()
    UTCore.diagLog("test", "one", "")
    assert_true(UTCore.diagRingGet(0) ~= nil, "age 0 should exist")
    assert_eq(UTCore.diagRingGet(1), nil)
    assert_eq(UTCore.diagRingGet(-1), nil)
end)

-- ===== Diagnostics Performance Profiler tests =====

test("perfEnter/perfExit tracks timing", function()
    UTCore.resetPerfStats()
    setMockTimestampMs(100)
    UTCore.perfEnter("TestHook")
    setMockTimestampMs(105)
    UTCore.perfExit("TestHook")
    local stats = UTCore.getPerfStats()
    assert_true(stats["TestHook"] ~= nil, "should have stats for TestHook")
    assert_eq(stats["TestHook"].count, 1)
    assert_eq(stats["TestHook"].totalMs, 5)
    assert_eq(stats["TestHook"].peakMs, 5)
end)

test("perfEnter/perfExit accumulates over multiple calls", function()
    UTCore.resetPerfStats()
    -- Call 1: 3ms
    setMockTimestampMs(200)
    UTCore.perfEnter("MultiHook")
    setMockTimestampMs(203)
    UTCore.perfExit("MultiHook")
    -- Call 2: 7ms
    setMockTimestampMs(210)
    UTCore.perfEnter("MultiHook")
    setMockTimestampMs(217)
    UTCore.perfExit("MultiHook")
    local stats = UTCore.getPerfStats()
    assert_eq(stats["MultiHook"].count, 2)
    assert_eq(stats["MultiHook"].totalMs, 10)
    assert_eq(stats["MultiHook"].peakMs, 7)
end)

test("perfExit without perfEnter is a no-op", function()
    UTCore.resetPerfStats()
    UTCore.perfExit("NeverStarted")
    local stats = UTCore.getPerfStats()
    assert_eq(stats["NeverStarted"], nil)
end)

test("profiledHandler wraps function with profiling", function()
    UTCore.resetPerfStats()
    local callCount = 0
    local wrapped = UTCore.profiledHandler("WrappedHook", function(player)
        callCount = callCount + 1
    end)
    setMockTimestampMs(300)
    wrapped("fake_player")
    assert_eq(callCount, 1)
    local stats = UTCore.getPerfStats()
    assert_true(stats["WrappedHook"] ~= nil, "should track wrapped hook")
    assert_eq(stats["WrappedHook"].count, 1)
end)

test("profiledHandler catches and logs errors", function()
    UTCore.resetPerfStats()
    UTCore.diagResetRing()
    local wrapped = UTCore.profiledHandler("ErrorHook", function()
        error("test explosion")
    end)
    setMockTimestampMs(400)
    -- Should NOT throw - error is caught
    wrapped("fake_player")
    local stats = UTCore.getPerfStats()
    assert_eq(stats["ErrorHook"].count, 1)
    -- Error should be logged to ring buffer
    local entry = UTCore.diagRingGet(0)
    assert_eq(entry.src, "PERF")
    assert_eq(entry.evt, "hook_error")
    assert_true(entry.dat:find("ErrorHook") ~= nil, "error should name the hook")
end)

test("profiledHandlerV passes variable args through", function()
    UTCore.resetPerfStats()
    local capturedArgs = {}
    local wrapped = UTCore.profiledHandlerV("VarArgsHook", function(a, b, c)
        capturedArgs = {a, b, c}
    end)
    setMockTimestampMs(500)
    wrapped("attacker", "weapon", "target")
    local stats = UTCore.getPerfStats()
    assert_eq(stats["VarArgsHook"].count, 1)
    assert_eq(capturedArgs[1], "attacker")
    assert_eq(capturedArgs[2], "weapon")
    assert_eq(capturedArgs[3], "target")
end)

test("profiledHandlerV catches errors without throwing", function()
    UTCore.resetPerfStats()
    UTCore.diagResetRing()
    local wrapped = UTCore.profiledHandlerV("VarErrorHook", function()
        error("varargs boom")
    end)
    setMockTimestampMs(600)
    wrapped("a", "b")
    local stats = UTCore.getPerfStats()
    assert_eq(stats["VarErrorHook"].count, 1)
    local entry = UTCore.diagRingGet(0)
    assert_eq(entry.src, "PERF")
    assert_true(entry.dat:find("VarErrorHook") ~= nil, "error should name the hook")
end)

test("per-tick aggregate tracks currentTickMs across hooks", function()
    UTCore.resetPerfStats()
    -- Simulate two hooks firing in the same tick
    setMockTimestampMs(1000)
    UTCore.perfEnter("HookA")
    setMockTimestampMs(1002)
    UTCore.perfExit("HookA")  -- 2ms

    setMockTimestampMs(1002)
    UTCore.perfEnter("HookB")
    setMockTimestampMs(1005)
    UTCore.perfExit("HookB")  -- 3ms

    local state = UTCore.getFrameBudgetState()
    assert_eq(state.currentTickMs, 5, "current tick should accumulate 2+3=5ms")
end)

test("frame budget detects heavy frames", function()
    UTCore.resetPerfStats()
    -- Simulate a tick with >50% of 16.67ms budget = >8.33ms
    setMockTimestampMs(2000)
    UTCore.perfEnter("HeavyHook")
    setMockTimestampMs(2010)
    UTCore.perfExit("HeavyHook")  -- 10ms = 60% of frame

    -- Trigger tick close-out via the diagnostics onPlayerUpdate
    -- (this is the internal handler, need to invoke via Events)
    -- Instead, directly verify the accumulated state before close-out
    local state = UTCore.getFrameBudgetState()
    assert_eq(state.currentTickMs, 10, "should show 10ms accumulated")
end)

test("SleepQualityHook skips when not sleeping", function()
    local p = MockPlayer({})
    p:getModData()["UT_sleepQualMod"] = 0.5
    p:setAsleep(false)
    p:getStats():set(CharacterStat.FATIGUE, 0.5)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.5, "expected fatigue unchanged when awake")
end)

test("SleepQualityHook clamps fatigue at 0", function()
    local p = MockPlayer({})
    p:getModData()["UT_sleepQualMod"] = 0.5
    p:setAsleep(true)
    p:getStats():set(CharacterStat.FATIGUE, 0.0)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.0, "expected fatigue not to go below 0")
end)

-- ===== WorkSpeedHook: transferSpeedMult branch =====

test("WorkSpeedHook applies transferSpeedMult to ISInventoryTransferAction", function()
    local p = MockPlayer({})
    p:getModData()["UT_transferSpeedMult"] = 0.6  -- 40% faster (delta = -0.4)
    local action = MockTimedAction(p, "ISInventoryTransferAction", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert(math.abs(result - 60) < 1, "expected ~60, got " .. tostring(result))
end)

test("WorkSpeedHook applies transferSpeedMult to ISReloadWeaponAction", function()
    local p = MockPlayer({})
    p:getModData()["UT_transferSpeedMult"] = 0.6
    local action = MockTimedAction(p, "ISReloadWeaponAction", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert(math.abs(result - 60) < 1, "expected ~60, got " .. tostring(result))
end)

test("WorkSpeedHook does not apply transferSpeedMult to ISCraftItem", function()
    local p = MockPlayer({})
    p:getModData()["UT_transferSpeedMult"] = 0.6
    local action = MockTimedAction(p, "ISCraftItem", 100)
    local result = UTCore.applyWorkDuration(action, 100)
    assert_eq(result, 100, "expected no transfer mod on a craft action")
end)

-- ===== FreezeLogger Tests =====

local function withFreezeLoggerSandbox(body)
    local originalPrint = _G.print
    local originalGetPlayer = _G.getPlayer
    UTCore._resetFreezeLogger()
    local ok, err = pcall(body)
    _G.print = originalPrint
    _G.getPlayer = originalGetPlayer
    UTCore._resetFreezeLogger()
    if not ok then error(err, 0) end
end

test("FreezeLogger: no freeze detected during normal movement", function()
    UTCore._resetFreezeLogger()
    local p = MockPlayer({}, { moving = true })
    -- Simulate moving player (position changes each tick)
    for i = 1, 10 do
        p:moveTo(i * 0.1, 0)
        UTCore._freezeLoggerOnPlayerUpdate(p)
    end
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 0, "should not count stuck ticks during movement")
end)

test("FreezeLogger: no freeze when player stops voluntarily", function()
    UTCore._resetFreezeLogger()
    local p = MockPlayer({}, { moving = true })
    -- Walk a bit
    p:moveTo(1.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    p:moveTo(2.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    -- Player releases movement keys (isMoving=false) and position stays same
    p._overrides = p._overrides or {}
    p.isMoving = function() return false end
    for _ = 1, 10 do
        UTCore._freezeLoggerOnPlayerUpdate(p)
    end
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 0,
        "voluntary stop (isMoving=false) must NOT count as freeze")
end)

test("FreezeLogger: detects freeze when isMoving=true but position stuck", function()
    UTCore._resetFreezeLogger()
    local p = MockPlayer({}, { moving = true })
    -- Move first so prevX/prevY are set
    p:moveTo(1.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    -- Now player is holding movement key (isMoving=true) but position doesn't change
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 1, "should count 1 stuck tick")
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 2, "should count 2 stuck ticks")
end)

test("FreezeLogger: resets on resumed movement", function()
    UTCore._resetFreezeLogger()
    local p = MockPlayer({}, { moving = true })
    p:moveTo(1.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    -- Stuck with isMoving=true
    UTCore._freezeLoggerOnPlayerUpdate(p)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 2, "stuck after 2 ticks")
    -- Move again
    p:moveTo(3.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 0, "should reset on movement")
end)

test("FreezeLogger: resets stuck count when player releases keys", function()
    UTCore._resetFreezeLogger()
    local p = MockPlayer({}, { moving = true })
    p:moveTo(1.0, 0)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    -- 2 stuck ticks with isMoving=true
    UTCore._freezeLoggerOnPlayerUpdate(p)
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 2, "stuck while pressing keys")
    -- Player releases keys
    p.isMoving = function() return false end
    UTCore._freezeLoggerOnPlayerUpdate(p)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 0, "should reset when keys released")
end)

test("FreezeLogger: distinct player lifecycle resets state and preserves stable identity", function()
    withFreezeLoggerSandbox(function()
        local messages = {}
        _G.print = function(message) messages[#messages + 1] = message end

        local playerA = MockPlayer({}, { moving = true })
        playerA:moveTo(7.0, 3.0)
        UTCore._freezeLoggerOnPlayerUpdate(playerA)
        for _ = 1, 4 do
            UTCore._freezeLoggerOnPlayerUpdate(playerA)
        end
        assert_eq(UTCore._getFreezeLoggerStuckCount(), 4, "player A should advance to four stuck ticks")

        local playerB = MockPlayer({}, { moving = true })
        playerB:moveTo(7.0, 3.0)
        UTCore._freezeLoggerOnPlayerUpdate(playerB)
        assert_eq(UTCore._getFreezeLoggerStuckCount(), 0,
            "first update for player B must reset player A's coordinates and counters")
        assert_eq(#messages, 0, "player B must not trigger a freeze log from player A's borrowed state")

        UTCore._freezeLoggerOnPlayerUpdate(playerB)
        assert_eq(UTCore._getFreezeLoggerStuckCount(), 1,
            "second update for the same player B object must advance its state")
        assert_eq(#messages, 0, "player B's first stuck tick must not emit a freeze log")
    end)
end)

test("FreezeLogger: skips nil player", function()
    UTCore._resetFreezeLogger()
    UTCore._freezeLoggerOnPlayerUpdate(nil)
    assert_eq(UTCore._getFreezeLoggerStuckCount(), 0, "nil player should not trigger")
end)

test("FreezeLogger: OnPlayerMove tracker sets flag", function()
    withFreezeLoggerSandbox(function()
        local player = MockPlayer({})
        UTCore._freezeLoggerOnPlayerMove(player)
        -- The flag is internal, so this verifies the movement event accepts its explicit player.
    end)
end)

local function withCoreHandlerRegistry(fn)
    local handlers = UTCore._coreHandlers
    local count = UTCore._coreHandlerCount
    local dirty = UTCore._coreHandlersDirty
    UTCore._coreHandlers = {}
    UTCore._coreHandlerCount = 0
    UTCore._coreHandlersDirty = true
    local ok, err = pcall(fn)
    UTCore._coreHandlers = handlers
    UTCore._coreHandlerCount = count
    UTCore._coreHandlersDirty = dirty
    if not ok then error(err, 0) end
end

test("registerCoreHandler initial insert creates one keyed entry", function()
    withCoreHandlerRegistry(function()
        local handler = function() end
        UTCore.registerCoreHandler("test.initial", handler)
        assert_eq(UTCore.getCoreHandlerCount(), 1)
        assert_eq(UTCore._coreHandlers[1].id, "test.initial")
        assert_eq(UTCore._coreHandlers[1].fn, handler)
    end)
end)

test("registerCoreHandler same ID replaces same and new closures", function()
    withCoreHandlerRegistry(function()
        local oldCalls, newCalls = 0, 0
        local oldHandler = function() oldCalls = oldCalls + 1 end
        local newHandler = function() newCalls = newCalls + 1 end
        UTCore.registerCoreHandler("test.replace", oldHandler)
        UTCore.registerCoreHandler("test.replace", oldHandler)
        assert_eq(UTCore.getCoreHandlerCount(), 1, "same closure must remain unique")
        UTCore.registerCoreHandler("test.replace", newHandler)
        assert_eq(UTCore.getCoreHandlerCount(), 1, "new closure must replace by ID")
        Events.OnPlayerUpdate.fire(MockPlayer({}))
        assert_eq(oldCalls, 0, "stale closure must not execute")
        assert_eq(newCalls, 1, "replacement closure should execute once")
    end)
end)

test("registerCoreHandler replaces options and reorders late priority", function()
    withCoreHandlerRegistry(function()
        local order = {}
        UTCore.registerCoreHandler("test.low", function() order[#order + 1] = "low" end, {
            throttle = 4,
            priority = 0,
        })
        UTCore.registerCoreHandler("test.low", function() order[#order + 1] = "low-new" end, {
            throttle = 0,
            priority = 1,
        })
        assert_eq(UTCore._coreHandlers[1].throttle, 0, "replacement throttle")
        assert_eq(UTCore._coreHandlers[1].priority, 1, "replacement priority")
        Events.OnPlayerUpdate.fire(MockPlayer({}))
        UTCore.registerCoreHandler("test.high", function() order[#order + 1] = "high" end, {
            priority = 100,
        })
        order = {}
        Events.OnPlayerUpdate.fire(MockPlayer({}))
        assert_eq(order[1], "high", "late high-priority handler must run first")
        assert_eq(order[2], "low-new", "replacement must remain registered")
    end)
end)

test("registerCoreHandler keeps distinct IDs sharing one function", function()
    withCoreHandlerRegistry(function()
        local calls = 0
        local shared = function() calls = calls + 1 end
        UTCore.registerCoreHandler("test.shared-a", shared)
        UTCore.registerCoreHandler("test.shared-b", shared)
        assert_eq(UTCore.getCoreHandlerCount(), 2)
        Events.OnPlayerUpdate.fire(MockPlayer({}))
        assert_eq(calls, 2, "distinct IDs should dispatch independently")
    end)
end)

test("registerCoreHandler collapses historical duplicate rows", function()
    withCoreHandlerRegistry(function()
        local replacement = function() end
        UTCore._coreHandlers = {
            { id = "test.duplicate", fn = function() end, throttle = 7, priority = -1 },
            { id = "test.distinct", fn = function() end, throttle = 0, priority = 0 },
            { id = "test.duplicate", fn = function() end, throttle = 9, priority = -2 },
        }
        UTCore._coreHandlerCount = 3
        UTCore.registerCoreHandler("test.duplicate", replacement, { throttle = 2, priority = 5 })
        assert_eq(UTCore.getCoreHandlerCount(), 2, "duplicates should collapse to one row")
        assert_eq(UTCore._coreHandlers[1].id, "test.duplicate")
        assert_eq(UTCore._coreHandlers[1].fn, replacement)
        assert_eq(UTCore._coreHandlers[1].throttle, 2)
        assert_eq(UTCore._coreHandlers[1].priority, 5)
        assert_eq(UTCore._coreHandlers[2].id, "test.distinct", "distinct row should remain")
    end)
end)

test("registerCoreHandler rejects invalid inputs before mutation", function()
    withCoreHandlerRegistry(function()
        local existing = function() end
        UTCore.registerCoreHandler("test.valid", existing)
        local originalRow = UTCore._coreHandlers[1]
        local invalid = {
            { nil, existing, nil },
            { "", existing, nil },
            { 12, existing, nil },
            { "test.invalid", nil, nil },
            { "test.invalid", "not-a-function", nil },
            { "test.invalid", existing, false },
            { "test.invalid", existing, { throttle = -1 } },
            { "test.invalid", existing, { throttle = 1.5 } },
            { "test.invalid", existing, { throttle = 0 / 0 } },
            { "test.invalid", existing, { throttle = math.huge } },
            { "test.invalid", existing, { priority = "high" } },
            { "test.invalid", existing, { priority = 0 / 0 } },
            { "test.invalid", existing, { priority = -math.huge } },
        }
        for i, args in ipairs(invalid) do
            local ok = pcall(UTCore.registerCoreHandler, args[1], args[2], args[3])
            assert_eq(ok, false, "invalid case " .. tostring(i) .. " should fail")
            assert_eq(UTCore.getCoreHandlerCount(), 1, "invalid input must not change count")
            assert_eq(UTCore._coreHandlers[1], originalRow, "invalid input must not replace registry row")
        end
    end)
end)

test("keyed core registration makes affected caller reloads idempotent", function()
    local count = UTCore.getCoreHandlerCount()
    dofile(base .. "../media/lua/shared/UTCore/UTCore_BleedHook.lua")
    dofile(base .. "../media/lua/shared/UTCore/UTCore_MeleeDelayHook.lua")
    dofile(base .. "../media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
    assert_eq(UTCore.getCoreHandlerCount(), count,
        "affected caller reloads must replace their keyed handlers")
end)

test("TickDispatch module reload keeps one central OnPlayerUpdate callback", function()
    local count = Events.OnPlayerUpdate._handlerCount()
    dofile(base .. "../media/lua/shared/UTCore/UTCore_TickDispatch.lua")
    assert_eq(Events.OnPlayerUpdate._handlerCount(), count,
        "remove-before-add must preserve one central callback")
end)

-- ===== PZ API Surface Tests =====
dofile(base .. "test_pz_api_surface.lua")

-- ===== Engine Contract Tests =====
-- These verify that the PZ Java engine source still matches the patterns
-- our SpeedHook depends on. Failures mean a PZ update may have changed
-- the movement pipeline and the SpeedHook needs re-validation.
dofile(base .. "test_engine_contracts.lua")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
