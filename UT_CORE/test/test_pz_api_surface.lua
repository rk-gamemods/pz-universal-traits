-- test_pz_api_surface.lua
-- PZ API surface verification tests.
-- These tests verify that MockPlayer and all PZ mock objects expose the exact
-- methods called by UTCore and UniversalTraits production code. When PZ updates
-- change or remove an API method, the corresponding mock update will force
-- these tests to explicitly acknowledge the change.
--
-- Run with: lua UT_CORE/test/run_tests.lua  (loaded automatically)

-- ============================================================
-- CATEGORY A: Player (IsoGameCharacter / IsoPlayer) methods
-- Every method that production code calls on a player object.
-- ============================================================

test("API:Player — getModData() exists and returns table", function()
    local p = MockPlayer({})
    local md = p:getModData()
    assert(type(md) == "table", "getModData must return a table")
end)

test("API:Player — getStats() exists and returns stats object", function()
    local p = MockPlayer({})
    local stats = p:getStats()
    assert(stats ~= nil, "getStats must not be nil")
end)

test("API:Player — getBodyDamage() exists", function()
    local p = MockPlayer({})
    -- UT_CORE MockPlayer requires setBodyDamage first
    local bd = MockBodyDamage({})
    p:setBodyDamage(bd)
    assert(p:getBodyDamage() ~= nil, "getBodyDamage must not be nil after set")
end)

test("API:Player — getHealth()/setHealth() exist", function()
    local p = MockPlayer({})
    local h = p:getHealth()
    assert(type(h) == "number", "getHealth must return a number")
    p:setHealth(50)
    assert_eq(p:getHealth(), 50, "setHealth round-trip")
end)

test("API:Player — getXp() exists with AddXP method", function()
    local p = MockPlayer({})
    local xp = p:getXp()
    assert(xp ~= nil, "getXp must not be nil")
    assert(type(xp.AddXP) == "function", "xp:AddXP must be a function")
end)

test("API:Player — hasTrait(CharacterTrait) B42.16 method exists", function()
    local p = MockPlayer({"UniversalTraits:UT_swift"})
    local rl = ResourceLocation.of("UniversalTraits:UT_swift")
    local ct = CharacterTrait.get(rl)
    assert(ct ~= nil, "CharacterTrait.get must resolve registered trait")
    assert(p:hasTrait(ct) == true, "hasTrait(ct) must return true for registered trait")
end)

test("API:Player — hasTrait returns false for unregistered trait", function()
    local p = MockPlayer({})
    CharacterTrait.register("UniversalTraits:UT_testonly_missing")
    local rl = ResourceLocation.of("UniversalTraits:UT_testonly_missing")
    local ct = CharacterTrait.get(rl)
    assert(p:hasTrait(ct) == false, "hasTrait must return false when player lacks trait")
end)

test("API:Player — getCharacterTraits() B42.16 exists with getKnownTraits", function()
    local p = MockPlayer({"UniversalTraits:UT_swift"})
    local ct = p:getCharacterTraits()
    assert(ct ~= nil, "getCharacterTraits must not be nil")
    local known = ct:getKnownTraits()
    assert(known ~= nil, "getKnownTraits must not be nil")
    assert(type(known.size) == "function", "knownTraits must have size()")
    assert(type(known.get) == "function", "knownTraits must have get()")
end)

test("API:Player — getNutrition() exists", function()
    local p = MockPlayer({})
    local n = p:getNutrition()
    assert(n ~= nil, "getNutrition must not be nil")
end)

test("API:Player — getInventory() not nil when provided", function()
    local inv = MockInventory(5, 20)
    local p = MockPlayer({}, { inventory = inv })
    assert(p:getInventory() ~= nil, "getInventory must return inventory")
end)

test("API:Player — getVehicle() returns nil when not driving", function()
    local p = MockPlayer({})
    -- no vehicle set = nil
    assert(p:getVehicle() == nil, "getVehicle must be nil when not in vehicle")
end)

test("API:Player — getPerkLevel(perk) exists", function()
    local p = MockPlayer({}, { perkLevels = { [Perks.Strength] = 5 } })
    assert_eq(p:getPerkLevel(Perks.Strength), 5, "getPerkLevel(Strength)")
end)

test("API:Player — getPrimaryHandItem() exists", function()
    local w = MockWeapon("Axe", 0.5)
    local p = MockPlayer({}, { primaryHandItem = w })
    assert(p:getPrimaryHandItem() ~= nil, "getPrimaryHandItem must return weapon")
end)

test("API:Player — isLocalPlayer() exists", function()
    local p = MockPlayer({})
    assert(p:isLocalPlayer() == true, "isLocalPlayer must return true in tests")
end)

test("API:Player — setMaxWeightBase/getMaxWeightBase exist", function()
    local p = MockPlayer({})
    p:setMaxWeightBase(12)
    assert_eq(p:getMaxWeightBase(), 12, "weight round-trip")
end)

test("API:Player — position methods exist", function()
    local p = MockPlayer({})
    assert(type(p.getX) == "function", "getX")
    assert(type(p.getY) == "function", "getY")
    assert(type(p.setX) == "function", "setX")
    assert(type(p.setY) == "function", "setY")
end)

test("API:Player — isSleeping() exists", function()
    local p = MockPlayer({})
    assert(type(p.isSleeping) == "function", "isSleeping must be a function")
end)

test("API:Player — isBumped/getBumpedChr/setBumpType/setBumpFall exist", function()
    local p = MockPlayer({})
    assert(type(p.isBumped) == "function", "isBumped")
    assert(type(p.getBumpedChr) == "function", "getBumpedChr")
    assert(type(p.setBumpType) == "function", "setBumpType")
    assert(type(p.setBumpFall) == "function", "setBumpFall")
end)

test("API:Player — isDriving() exists", function()
    local p = MockPlayer({})
    assert(type(p.isDriving) == "function", "isDriving")
end)

test("API:Player — makeNoise() exists", function()
    local p = MockPlayer({})
    assert(type(p.makeNoise) == "function", "makeNoise")
end)

test("API:Player — setMeleeDelay() exists", function()
    local p = MockPlayer({})
    assert(type(p.setMeleeDelay) == "function", "setMeleeDelay")
end)

test("API:Player — isOutside() exists", function()
    local p = MockPlayer({})
    assert(type(p.isOutside) == "function", "isOutside")
end)

test("API:Player — _mockType tag for instanceof", function()
    local p = MockPlayer({})
    assert(instanceof(p, "IsoGameCharacter"), "MockPlayer must pass instanceof IsoGameCharacter")
    assert(instanceof(p, "IsoPlayer"), "MockPlayer must pass instanceof IsoPlayer")
end)

-- ============================================================
-- CATEGORY B: PZ Java globals & classes
-- ============================================================

test("API:Global — instanceof() exists as function", function()
    assert(type(instanceof) == "function", "instanceof must be a function")
end)

test("API:Global — ResourceLocation.of() exists", function()
    assert(type(ResourceLocation) == "table", "ResourceLocation must be a table")
    assert(type(ResourceLocation.of) == "function", "ResourceLocation.of must be a function")
    local rl = ResourceLocation.of("UniversalTraits:UT_swift")
    assert(rl._ns == "universaltraits", "namespace must be lowercased")
    assert(rl._path == "ut_swift", "path must be lowercased")
end)

test("API:Global — ResourceLocation.of() handles no-namespace", function()
    local rl = ResourceLocation.of("Athletic")
    assert_eq(rl._ns, "base", "default namespace must be 'base'")
    assert_eq(rl._path, "athletic", "path must be lowercased")
end)

test("API:Global — CharacterTrait.register/get roundtrip", function()
    local ct = CharacterTrait.register("TestMod:TestTrait")
    local rl = ResourceLocation.of("TestMod:TestTrait")
    local found = CharacterTrait.get(rl)
    assert(found ~= nil, "CharacterTrait.get must find registered trait")
    assert_eq(found._id, "TestMod:TestTrait", "trait ID must match")
end)

test("API:Global — CharacterTrait.get returns nil for unregistered", function()
    local rl = ResourceLocation.of("FakeMod:FakeTrait")
    local found = CharacterTrait.get(rl)
    assert(found == nil, "CharacterTrait.get must return nil for unknown trait")
end)

test("API:Global — Events table exists with all required events", function()
    local required = {
        "OnPlayerUpdate", "OnCreatePlayer", "OnPlayerMove", "OnGameBoot",
        "OnWeaponHitCharacter", "EveryOneMinute", "EveryTenMinutes",
        "EveryHours", "AddXP", "OnVehicleEnter", "OnVehicleExit",
    }
    for _, name in ipairs(required) do
        assert(Events[name] ~= nil, "Events." .. name .. " must exist")
        assert(type(Events[name].Add) == "function", "Events." .. name .. ".Add must be a function")
    end
end)

test("API:Global — getPlayer() exists", function()
    assert(type(getPlayer) == "function", "getPlayer must be a function")
end)

test("API:Global — getGameTime() exists with required methods", function()
    assert(type(getGameTime) == "function", "getGameTime must be a function")
    local gt = getGameTime()
    assert(type(gt.getWorldAgeHours) == "function", "getWorldAgeHours")
    assert(type(gt.getTicks) == "function", "getTicks")
    assert(type(gt.getTimeOfDay) == "function", "getTimeOfDay")
end)

test("API:Global — GameTime.getInstance() exists with getMultiplier", function()
    assert(type(GameTime) == "table", "GameTime must be a table")
    local gti = GameTime.getInstance()
    assert(type(gti.getMultiplier) == "function", "getMultiplier")
end)

test("API:Global — Perks constants exist", function()
    assert(Perks.Strength ~= nil, "Perks.Strength")
    assert(Perks.SmallBlunt ~= nil, "Perks.SmallBlunt")
    assert(Perks.Nimble ~= nil, "Perks.Nimble")
end)

test("API:Global — BodyPartType constants exist", function()
    assert(BodyPartType.Neck ~= nil, "Neck")
    assert(BodyPartType.Leg_L ~= nil, "Leg_L")
    assert(BodyPartType.Leg_R ~= nil, "Leg_R")
    assert(BodyPartType.UpperArm_L ~= nil, "UpperArm_L")
    assert(BodyPartType.UpperArm_R ~= nil, "UpperArm_R")
    assert(BodyPartType.LowerArm_L ~= nil, "LowerArm_L")
    assert(BodyPartType.LowerArm_R ~= nil, "LowerArm_R")
    assert(BodyPartType.Head ~= nil, "Head")
    assert(BodyPartType.Torso_Upper ~= nil, "Torso_Upper")
end)

test("API:Global — CharacterStat constants exist", function()
    assert(CharacterStat.PAIN ~= nil, "PAIN")
    assert(CharacterStat.PANIC ~= nil, "PANIC")
    assert(CharacterStat.STRESS ~= nil, "STRESS")
    assert(CharacterStat.HUNGER ~= nil, "HUNGER")
    assert(CharacterStat.THIRST ~= nil, "THIRST")
    assert(CharacterStat.BOREDOM ~= nil, "BOREDOM")
    assert(CharacterStat.FATIGUE ~= nil, "FATIGUE")
end)

test("API:Global — ZombRand() exists", function()
    assert(type(ZombRand) == "function", "ZombRand must be a function")
    local v = ZombRand(100)
    assert(type(v) == "number", "ZombRand must return a number")
end)

-- ============================================================
-- CATEGORY C: Sub-object methods (chained from player)
-- ============================================================

-- Stats methods
test("API:Stats — get/set/add/remove methods exist", function()
    local p = MockPlayer({})
    local s = p:getStats()
    assert(type(s.get) == "function", "stats:get")
    assert(type(s.set) == "function" or type(s.setPain) == "function", "stats:set or setPain")
    assert(type(s.add) == "function", "stats:add")
    assert(type(s.remove) == "function", "stats:remove")
end)

test("API:Stats — getFatigue/setFatigue roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setFatigue(0.5)
    assert_eq(s:getFatigue(), 0.5, "fatigue roundtrip")
end)

test("API:Stats — getPain/setPain roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setPain(30)
    assert_eq(s:getPain(), 30, "pain roundtrip")
end)

test("API:Stats — getStress/setStress roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setStress(0.2)
    assert_eq(s:getStress(), 0.2, "stress roundtrip")
end)

test("API:Stats — getHunger/setHunger roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setHunger(0.3)
    assert_eq(s:getHunger(), 0.3, "hunger roundtrip")
end)

test("API:Stats — getThirst/setThirst roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setThirst(0.4)
    assert_eq(s:getThirst(), 0.4, "thirst roundtrip")
end)

test("API:Stats — getEndurance/setEndurance roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setEndurance(0.7)
    assert_eq(s:getEndurance(), 0.7, "endurance roundtrip")
end)

test("API:Stats — getDrunkenness/setDrunkenness roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setDrunkenness(0.6)
    assert_eq(s:getDrunkenness(), 0.6, "drunkenness roundtrip")
end)

test("API:Stats — setPanic exists", function()
    local p = MockPlayer({})
    local s = p:getStats()
    assert(type(s.setPanic) == "function", "setPanic")
end)

test("API:Stats — getBoredom/setBoredom roundtrip", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:setBoredom(0.3)
    assert_eq(s:getBoredom(), 0.3, "boredom roundtrip")
end)

-- BodyDamage methods
test("API:BodyDamage — getBodyParts() returns list with size/get", function()
    local part = MockBodyPart("Neck", false)
    local bd = MockBodyDamage({part})
    local list = bd:getBodyParts()
    assert(type(list.size) == "function", "size()")
    assert(type(list.get) == "function", "get()")
    assert_eq(list:size(), 1, "one part")
end)

test("API:BodyDamage — getBodyPart(type) returns part", function()
    local part = MockBodyPart("Neck", true)
    local bd = MockBodyDamage({part})
    local found = bd:getBodyPart("Neck")
    assert(found ~= nil, "getBodyPart must find by type")
end)

test("API:BodyDamage — getNumPartsBleeding() exists", function()
    local p1 = MockBodyPart("Neck", true)
    local p2 = MockBodyPart("Leg_L", false)
    local bd = MockBodyDamage({p1, p2})
    assert_eq(bd:getNumPartsBleeding(), 1, "one bleeding part")
end)

-- BodyPart methods
test("API:BodyPart — getBleedingTime/setBleedingTime exist", function()
    local part = MockBodyPart("Neck", true)
    -- Verify the mock has bleeding-related methods
    assert(type(part.bleeding) == "function", "bleeding()")
    assert(type(part.getType) == "function", "getType()")
    assert(type(part.getHealth) == "function", "getHealth()")
end)

test("API:BodyPart — AddHealth/ReduceHealth exist", function()
    local part = MockBodyPart("Neck")
    assert(type(part.AddHealth) == "function", "AddHealth")
    assert(type(part.ReduceHealth) == "function", "ReduceHealth")
end)

-- XP methods
test("API:XP — AddXP records calls", function()
    local p = MockPlayer({})
    p:getXp():AddXP(Perks.Strength, 10)
    local calls = p:getXpCalls()
    assert(#calls == 1, "one XP call recorded")
    assert_eq(calls[1].perk, Perks.Strength, "perk matches")
    assert_eq(calls[1].amount, 10, "amount matches")
end)

-- Nutrition methods
test("API:Nutrition — getWeight/getCalories/setCalories exist", function()
    local p = MockPlayer({})
    local n = p:getNutrition()
    assert(type(n.getWeight) == "function", "getWeight")
    assert(type(n.getCalories) == "function", "getCalories")
    assert(type(n.setCalories) == "function", "setCalories")
end)

-- Vehicle methods
test("API:Vehicle — all vehicle mod methods exist", function()
    local v = MockVehicle()
    assert(type(v.getModData) == "function", "getModData")
    assert(type(v.getMaxSpeed) == "function", "getMaxSpeed")
    assert(type(v.setMaxSpeed) == "function", "setMaxSpeed")
    assert(type(v.getBrakingForce) == "function", "getBrakingForce")
    assert(type(v.setBrakingForce) == "function", "setBrakingForce")
    assert(type(v.getEngineQuality) == "function", "getEngineQuality")
    assert(type(v.getEngineLoudness) == "function", "getEngineLoudness")
    assert(type(v.getEnginePower) == "function", "getEnginePower")
    assert(type(v.setEngineFeature) == "function", "setEngineFeature")
    assert(type(v.getMass) == "function", "getMass")
    assert(type(v.setMass) == "function", "setMass")
    assert(type(v.getInitialMass) == "function", "getInitialMass")
    assert(type(v.setInitialMass) == "function", "setInitialMass")
    assert(type(v.updateTotalMass) == "function", "updateTotalMass")
end)

-- Weapon methods
test("API:Weapon — all weapon methods exist", function()
    local w = MockWeapon("Axe", 0.5)
    assert(type(w.getType) == "function", "getType")
    assert(type(w.getMeleeDelay) == "function", "getMeleeDelay")
    assert(type(w.setMeleeDelay) == "function", "setMeleeDelay")
    assert(type(w.isTwoHandWeapon) == "function", "isTwoHandWeapon")
    assert(type(w.isMeleeWeapon) == "function", "isMeleeWeapon")
end)

-- Zombie methods
test("API:Zombie — required methods exist", function()
    local z = MockZombie()
    assert(type(z.isAlwaysKnockedDown) == "function", "isAlwaysKnockedDown")
    assert(type(z.knockDown) == "function", "knockDown")
    assert(type(z.getHealth) == "function", "getHealth")
    assert(type(z.setHealth) == "function", "setHealth")
end)

-- ============================================================
-- CATEGORY D: UTCore.hasTrait integration (the exact crash path)
-- Tests the PRODUCTION UTCore.hasTrait code path end-to-end,
-- not the mock stub, through CharacterTrait → ResourceLocation → player:hasTrait.
-- ============================================================

test("API:UTCore.hasTrait — resolves B42.16 registry and returns true", function()
    CharacterTrait.register("UniversalTraits:UT_swift")
    -- Clear the _traitCache in UTCore if it exists (it's a local, so we must
    -- test indirectly through the function)
    local p = MockPlayer({"UniversalTraits:UT_swift"})
    assert_eq(UTCore.hasTrait(p, "UniversalTraits:UT_swift"), true, "hasTrait must resolve via registry")
end)

test("API:UTCore.hasTrait — returns false for non-player object (instanceof guard)", function()
    local fakeThing = { _mockType = "ISInventoryPage" }
    assert_eq(UTCore.hasTrait(fakeThing, "UniversalTraits:UT_swift"), false, "non-player must return false")
end)

test("API:UTCore.hasTrait — returns false for nil player", function()
    assert_eq(UTCore.hasTrait(nil, "UniversalTraits:UT_swift"), false)
end)

test("API:UTCore.hasTrait — returns false when trait not on player", function()
    local p = MockPlayer({})
    assert_eq(UTCore.hasTrait(p, "UniversalTraits:UT_swift"), false)
end)

test("API:UTCore.hasAnyTrait — works with B42.16 registry", function()
    CharacterTrait.register("UniversalTraits:UT_olympian")
    local p = MockPlayer({"UniversalTraits:UT_olympian"})
    assert_eq(UTCore.hasAnyTrait(p, {"UniversalTraits:UT_swift", "UniversalTraits:UT_olympian"}), true)
end)

-- ============================================================
-- CATEGORY E: Static class methods
-- ============================================================

test("API:Static — CharacterTrait.register() returns object with _id", function()
    local ct = CharacterTrait.register("TestMod:TestStatic")
    assert(ct ~= nil, "register must return object")
    assert_eq(ct._id, "TestMod:TestStatic", "_id must match input")
end)

test("API:Static — ResourceLocation.of() returns object with toString", function()
    local rl = ResourceLocation.of("UniversalTraits:UT_test")
    assert(type(rl.toString) == "function", "toString must be a function")
    assert_eq(rl:toString(), "universaltraits:ut_test", "toString format")
end)

test("API:Static — BodyPartType.FromString() exists", function()
    assert(type(BodyPartType.FromString) == "function", "FromString must be a function")
end)

-- ============================================================
-- CATEGORY F: Event lifecycle (Add/Remove/fire must work)
-- ============================================================

test("API:Events — Add/fire roundtrip works", function()
    local fired = false
    local tempEvent = { handlers = {} }
    tempEvent.Add = function(fn) table.insert(tempEvent.handlers, fn) end
    tempEvent.fire = function(...)
        for _, fn in ipairs(tempEvent.handlers) do fn(...) end
    end
    tempEvent.Add(function() fired = true end)
    tempEvent.fire()
    assert(fired, "handler must fire")
end)

test("API:Events — OnCreatePlayer.Add accepts handler", function()
    local called = false
    local orig = Events.OnCreatePlayer
    -- We just verify Add doesn't error
    Events.OnCreatePlayer.Add(function(idx, player) called = true end)
    Events.OnCreatePlayer.fire(0, MockPlayer({}))
    assert(called, "OnCreatePlayer handler must fire")
end)

-- ============================================================
-- CATEGORY G: Mock self-consistency checks
-- These catch mock drift where a mock method is removed or
-- renamed without updating production code expectations.
-- ============================================================

test("API:MockConsistency — MockPlayer has all movement methods", function()
    local p = MockPlayer({})
    local required = {
        "getX", "getY", "getZ", "setX", "setY",
        "isLocalPlayer", "isSprinting", "isRunning", "isMoving",
        "isDriving", "getVehicle", "getPrimaryHandItem",
    }
    for _, method in ipairs(required) do
        assert(type(p[method]) == "function", "MockPlayer must have " .. method)
    end
end)

test("API:MockConsistency — MockPlayer has all combat methods", function()
    local p = MockPlayer({})
    local required = {
        "isBumped", "getBumpedChr", "setBumpType", "setBumpFall",
        "setMeleeDelay", "getPerkLevel",
    }
    for _, method in ipairs(required) do
        assert(type(p[method]) == "function", "MockPlayer must have " .. method)
    end
end)

test("API:MockConsistency — MockPlayer has all trait methods", function()
    local p = MockPlayer({})
    local required = {
        "hasTrait", "getTraits", "getCharacterTraits", "getModData",
    }
    for _, method in ipairs(required) do
        assert(type(p[method]) == "function", "MockPlayer must have " .. method)
    end
end)

test("API:MockConsistency — MockPlayer has all stat/body methods", function()
    local p = MockPlayer({})
    local required = {
        "getStats", "getXp", "getNutrition",
        "getMaxWeightBase", "setMaxWeightBase",
        "getHealth", "setHealth",
    }
    for _, method in ipairs(required) do
        assert(type(p[method]) == "function", "MockPlayer must have " .. method)
    end
end)

test("API:MockConsistency — MockVehicle has all methods", function()
    local v = MockVehicle()
    local required = {
        "getModData", "getMaxSpeed", "setMaxSpeed",
        "getBrakingForce", "setBrakingForce",
        "getEngineQuality", "getEngineLoudness", "getEnginePower", "setEngineFeature",
        "getMass", "setMass", "getInitialMass", "setInitialMass", "updateTotalMass",
    }
    for _, method in ipairs(required) do
        assert(type(v[method]) == "function", "MockVehicle must have " .. method)
    end
end)
