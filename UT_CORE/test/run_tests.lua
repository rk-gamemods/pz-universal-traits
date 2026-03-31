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
    _G.Perks = { Strength = "Strength" }
    UTCore._meleeDelayOnPlayerUpdate(p)
    _G.Perks = nil
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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
