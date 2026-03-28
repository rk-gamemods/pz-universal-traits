-- run_tests.lua  (UT_CORE)
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" test/run_tests.lua

local base = arg[0]:match("(.*[/\\])") or "./"
package.path = base .. "../media/lua/shared/?.lua;" .. package.path

-- Load mocks
dofile(base .. "UTCoreMocks.lua")

-- Load UTCore modules
dofile(base .. "../media/lua/shared/UTCore/UTCore_API.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_TraitChecks.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_Events.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_StatModifiers.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_SpawnEffects.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_XPHook.lua")

local passed, failed = 0, 0
local function test(name, fn)
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
    UTCore.applyCarryWeight(p, 4)
    assert_eq(p:getMaxWeightBase(), 12)
end)

-- applyBleedRate
test("applyBleedRate stores multiplier in moddata", function()
    local p = MockPlayer()
    UTCore.applyBleedRate(p, 1.5)
    assert_eq(p:getModData()["UT_bleedMult"], 1.5)
end)

-- applyXPMultiplier
test("applyXPMultiplier stores in moddata", function()
    local p = MockPlayer()
    UTCore.applyXPMultiplier(p, "Aiming", 2.0)
    assert_eq(p:getModData()["UT_xpMult_Aiming"], 2.0)
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
    assert_eq(p:getStats():getPanic(), 0.75)
end)

-- registerPeriodicHandler
test("registerPeriodicHandler stores handler", function()
    UTCore._periodicHandlers = {}
    UTCore.registerPeriodicHandler("test_trait", "EveryOneMinute", function(player) end)
    assert_eq(UTCore._periodicHandlers["test_trait"] ~= nil, true)
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

-- unregisterPeriodicHandler
test("unregisterPeriodicHandler removes handler", function()
    UTCore._periodicHandlers = {}
    UTCore.registerPeriodicHandler("test_trait2", "EveryTenMinutes", function(player) end)
    UTCore.unregisterPeriodicHandler("test_trait2")
    assert_eq(UTCore._periodicHandlers["test_trait2"], nil)
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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
