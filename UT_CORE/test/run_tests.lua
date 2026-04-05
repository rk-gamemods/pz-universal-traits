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
dofile(base .. "../media/lua/shared/UTCore/UTCore_SpeedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_ReadingHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_BleedHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_MeleeDelayHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_PainHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_DamageMultHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_FractureHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_NoiseHook.lua")
dofile(base .. "../media/lua/shared/UTCore/UTCore_SleepQualityHook.lua")

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
local function assert_true(v, msg)
    if not v then error((msg or "expected true, got falsy"), 2) end
end
-- Export for dofile'd test modules
_G.test = test
_G.assert_eq = assert_eq
_G.assert_true = assert_true

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

test("getCharacterTraitId uses getName when available", function()
    local trait = {
        getName = function(self) return "UniversalTraits:UT_specmove" end
    }
    assert_eq(UTCore.getCharacterTraitId(trait), "UniversalTraits:UT_specmove")
end)

test("getTraitDefinitionId resolves through getType", function()
    local def = {
        getType = function(self)
            return {
                getName = function(innerSelf) return "UniversalTraits:UT_specaid" end
            }
        end
    }
    assert_eq(UTCore.getTraitDefinitionId(def), "UniversalTraits:UT_specaid")
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

-- SpeedHook: positive speedMod amplifies movement
test("SpeedHook positive speedMod amplifies movement", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    Events.OnPlayerMove.fire()   -- stores prevX/prevY
    player:moveTo(2, 0)
    Events.OnPlayerMove.fire()   -- should amplify: 0 + 2*1.5 = 3.0
    local result = player:getX()
    assert(math.abs(result - 3.0) < 0.01, "expected X ~3.0, got " .. tostring(result))
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: negative speedMod reduces movement
test("SpeedHook negative speedMod reduces movement", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = -0.3
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    Events.OnPlayerMove.fire()   -- stores prevX/prevY
    player:moveTo(2, 0)
    Events.OnPlayerMove.fire()   -- should reduce: 0 + 2*0.7 = 1.4
    local result = player:getX()
    assert(math.abs(result - 1.4) < 0.01, "expected X ~1.4, got " .. tostring(result))
    _G.getPlayer = function() return nil end
end)

-- SpeedHook: teleport guard skips adjustment when delta > 5
test("SpeedHook teleport guard skips adjustment when delta > 5", function()
    local player = MockPlayer({})
    player:getModData()["UT_speedMod"] = 0.5
    _G.getPlayer = function() return player end
    player:moveTo(0, 0)
    Events.OnPlayerMove.fire()   -- stores prevX/prevY
    player:moveTo(10, 0)
    Events.OnPlayerMove.fire()   -- delta=10 > 5, should skip
    local result = player:getX()
    assert(math.abs(result - 10.0) < 0.01, "expected X ~10.0 (no amplification), got " .. tostring(result))
    _G.getPlayer = function() return nil end
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

test("WorkSpeedHook clamps negative duration to 1", function()
    local p = MockPlayer({})
    local action = MockTimedAction(p, "ISCraftItem", -25)
    local result = UTCore.applyWorkDuration(action, -25)
    assert_eq(result, 1, "expected negative duration to clamp to 1")
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
    p:getStats():setPanic(20)
    p:getStats():setStress(15)
    p:setBodyDamage({
        _boredom = 30,
        _unhappy = 40,
        getBoredomLevel = function(self) return self._boredom end,
        setBoredomLevel = function(self, v) self._boredom = v end,
        getUnhappinessLevel = function(self) return self._unhappy end,
        setUnhappinessLevel = function(self, v) self._unhappy = v end,
    })

    UTCore.applyReadingMoodEffects(p, 1.0)

    assert_eq(p:getStats():getPanic(), 0)
    assert_eq(p:getStats():getStress(), 0)
    assert_eq(p:getBodyDamage():getBoredomLevel(), 25)
    assert_eq(p:getBodyDamage():getUnhappinessLevel(), 35)
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

-- MeleeDelayHook: 50% reduction for axe category with UT_axes trait
test("MeleeDelayHook reduces delay 50% for axe weapon with UT_axes", function()
    local weapon = MockWeapon("HandAxe", 20)
    local p = MockPlayer({"UniversalTraits:UT_axes"}, { primaryHandItem = weapon })
    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getModData()["_lastMeleeDelay"], 10, "expected delay set to 10 (50% of 20)")
end)

-- MeleeDelayHook: strength-scaled reduction for UT_heavyswing
test("MeleeDelayHook uses strength-scaled formula for UT_heavyswing", function()
    local weapon = MockWeapon("PickAxe", 20)
    local p = MockPlayer({"UniversalTraits:UT_heavyswing"}, {
        primaryHandItem = weapon,
        perkLevels = { Strength = 5 },
    })
    -- Perks global not defined in test env; getPerkLevel uses key "Strength"
    local _savedPerks = _G.Perks
    _G.Perks = { Strength = "Strength" }
    UTCore._meleeDelayOnPlayerUpdate(p)
    _G.Perks = _savedPerks
    -- newDelay = 20 - 20 * (5 * 0.1) = 20 - 10 = 10
    assert_eq(p:getModData()["_lastMeleeDelay"], 10, "expected delay 10 (strength-scaled)")
end)

-- MeleeDelayHook: no trait means setMeleeDelay is NOT called
test("MeleeDelayHook does not apply when no relevant trait is present", function()
    local weapon = MockWeapon("HandAxe", 20)
    local p = MockPlayer({}, { primaryHandItem = weapon })
    UTCore._meleeDelayOnPlayerUpdate(p)
    assert_eq(p:getModData()["_lastMeleeDelay"], nil, "expected setMeleeDelay not called")
end)

-- Vehicle trait helpers
test("Vehicle trait registration applies modifiers on vehicle enter", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
    }, 1)

    Events.OnVehicleEnter.fire(player, vehicle)

    assert_eq(vehicle:getMaxSpeed(), 150, "expected vehicle max speed multiplier on enter")
    assert_eq(vehicle:getBrakingForce(), 5, "expected braking force multiplier on enter")
end)

test("Vehicle trait helpers restore the baseline on vehicle exit", function()
    UTCore._vehicleTraitDefs = {}
    local vehicle = MockVehicle()
    local player = MockPlayer({"UniversalTraits:UT_testdriver"}, { vehicle = vehicle })
    UTCore.registerVehicleTrait("UniversalTraits:UT_testdriver", "UT_testdriverState", {
        maxSpeed = 1.5,
        brakingForce = 0.5,
        enginePower = 2.0,
        mass = 0.75,
    }, 1)

    Events.OnVehicleEnter.fire(player, vehicle)
    Events.OnVehicleExit.fire(player, vehicle)

    assert_eq(vehicle:getMaxSpeed(), 100, "expected max speed restored")
    assert_eq(vehicle:getBrakingForce(), 10, "expected braking restored")
    assert_eq(vehicle:getEnginePower(), 100, "expected engine power restored")
    assert_eq(vehicle:getMass(), 1000, "expected mass restored")
end)

-- ===== ZombieCollisionHook tests =====

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
    local p = MockPlayer()
    local z = MockZombie()
    local firedPlayer, firedZombie
    UTCore.registerZombieCollisionHandler("test_trait", function(player, zombie)
        firedPlayer = player
        firedZombie = zombie
    end)
    p:setBumpType("stagger")
    p:setBumpedChr(z)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(firedPlayer, p, "callback should receive the player")
    assert_eq(firedZombie, z, "callback should receive the zombie")
end)

test("ZombieCollisionHook does NOT re-fire on sustained bump", function()
    UTCore._zombieCollisionCallbacks = {}
    local p = MockPlayer()
    local z = MockZombie()
    local callCount = 0
    UTCore.registerZombieCollisionHandler("test_trait", function() callCount = callCount + 1 end)
    p:setBumpType("stagger")
    p:setBumpedChr(z)
    Events.OnPlayerUpdate.fire(p)   -- rising edge
    Events.OnPlayerUpdate.fire(p)   -- still bumped
    assert_eq(callCount, 1, "expected exactly 1 fire for a sustained bump")
end)

test("ZombieCollisionHook does NOT fire for non-zombie bumpedChr", function()
    UTCore._zombieCollisionCallbacks = {}
    local p = MockPlayer()
    local fired = false
    UTCore.registerZombieCollisionHandler("test_trait", function() fired = true end)
    local notZombie = { getName = function() return "survivor" end }  -- no isAlwaysKnockedDown
    p:setBumpType("stagger")
    p:setBumpedChr(notZombie)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(fired, false, "expected no callback for non-zombie bumpedChr")
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
    UTCore.declareZombieCollisionHandler("UniversalTraits:UT_test_notrait", function() end)
    local p = MockPlayer({})
    Events.OnCreatePlayer.fire(0, p)
    assert_eq(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_test_notrait"], nil,
        "expected no callback for player lacking the trait")
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

-- ===== PainHook tests =====

test("PainHook zeroes pain when UT_painImmune is true", function()
    local p = MockPlayer({})
    p:getStats():setPain(50)
    p:getModData()["UT_painImmune"] = true
    _G.getPlayer = function() return p end
    Events.OnPlayerUpdate.fire(p)
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():getPain(), 0, "expected pain cleared to 0")
end)

test("PainHook does not touch pain when UT_painImmune is absent", function()
    local p = MockPlayer({})
    p:getStats():setPain(50)
    Events.OnPlayerUpdate.fire(p)
    assert_eq(p:getStats():getPain(), 50, "expected pain unchanged when trait not set")
end)

-- ===== DamageMultHook tests =====

test("DamageMultHook applies extra health loss on weapon hit", function()
    local p = MockPlayer({})
    p:setHealth(100)
    p:getModData()["UT_damageMult"] = 1.5
    _G.getPlayer = function() return p end
    Events.OnPlayerUpdate.fire(p)   -- store prevHealth = 100
    p:setHealth(80)                  -- simulate 20 damage taken
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    -- lost=20; extra = 20*(1.5-1.0)=10; final = 80-10 = 70
    assert(math.abs(p:getHealth() - 70) < 0.01,
        "expected health 70 (extra 10 from 1.5x mult), got " .. tostring(p:getHealth()))
end)

test("DamageMultHook does nothing when mult is 1.0", function()
    local p = MockPlayer({})
    p:setHealth(100)
    p:getModData()["UT_damageMult"] = 1.0
    _G.getPlayer = function() return p end
    Events.OnPlayerUpdate.fire(p)
    p:setHealth(80)
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    assert_eq(p:getHealth(), 80, "expected no extra loss when mult=1.0")
end)

test("DamageMultHook does not fire for a different target", function()
    local p = MockPlayer({})
    p:setHealth(100)
    p:getModData()["UT_damageMult"] = 2.0
    _G.getPlayer = function() return p end
    Events.OnPlayerUpdate.fire(p)
    p:setHealth(80)
    local otherTarget = MockPlayer({})
    Events.OnWeaponHitCharacter.fire(nil, nil, otherTarget)
    _G.getPlayer = function() return nil end
    assert_eq(p:getHealth(), 80, "expected no extra loss when target is another character")
end)

-- ===== FractureHook tests =====
-- ZombRand always returns 0 in tests (set in mocks), so any chance > 0 succeeds.

test("FractureHook fractures eligible part on successful roll", function()
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.5
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:isFractured(), true, "expected Leg_L to be fractured on successful roll")
    assert(p:getModData()["UT_fractureCooldown"] > 0, "expected cooldown set after fracture")
end)

test("FractureHook does nothing when fractureMult is 1.0", function()
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.0
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:isFractured(), false, "expected no fracture when mult<=1.0")
end)

test("FractureHook respects cooldown and decrements it", function()
    local p = MockPlayer({})
    p:getModData()["UT_fractureMult"] = 1.5
    p:getModData()["UT_fractureCooldown"] = 50
    local legPart = MockBodyPart(BodyPartType.Leg_L, false, false)
    p:setBodyDamage(MockBodyDamage({ legPart }))
    _G.getPlayer = function() return p end
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    assert_eq(legPart:isFractured(), false, "expected no fracture during cooldown")
    assert_eq(p:getModData()["UT_fractureCooldown"], 49, "expected cooldown decremented by 1")
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
    Events.OnWeaponHitCharacter.fire(nil, nil, p)
    _G.getPlayer = function() return nil end
    -- No new fracture should be applied (all eligible parts already broken)
    assert_eq(p:getModData()["UT_fractureCooldown"], nil,
        "expected no cooldown set when all parts already fractured")
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
    p:setSleeping(true)
    p:getStats():setFatigue(0.5)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    -- expected: 0.5 - (0.5 * 0.001) = 0.4995
    local fatigue = p:getStats():getFatigue()
    assert(fatigue < 0.5, "expected fatigue to decrease while sleeping")
    assert(math.abs(fatigue - 0.4995) < 0.0001,
        "expected fatigue ~0.4995, got " .. tostring(fatigue))
end)

test("SleepQualityHook skips when not sleeping", function()
    local p = MockPlayer({})
    p:getModData()["UT_sleepQualMod"] = 0.5
    p:setSleeping(false)
    p:getStats():setFatigue(0.5)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():getFatigue(), 0.5, "expected fatigue unchanged when awake")
end)

test("SleepQualityHook clamps fatigue at 0", function()
    local p = MockPlayer({})
    p:getModData()["UT_sleepQualMod"] = 0.5
    p:setSleeping(true)
    p:getStats():setFatigue(0.0)
    _G.getPlayer = function() return p end
    Events.EveryOneMinute.fire()
    _G.getPlayer = function() return nil end
    assert_eq(p:getStats():getFatigue(), 0.0, "expected fatigue not to go below 0")
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

-- ===== PZ API Surface Tests =====
dofile(base .. "test_pz_api_surface.lua")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
