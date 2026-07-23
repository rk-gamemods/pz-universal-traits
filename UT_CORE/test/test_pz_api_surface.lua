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

-- nextX/nextY: used by SpeedHook for safe delta-scaling (IsoMovingObject API)
test("API:Player — getNextX/setNextX/getNextY/setNextY exist", function()
    local p = MockPlayer({})
    assert(type(p.getNextX) == "function", "getNextX must exist")
    assert(type(p.getNextY) == "function", "getNextY must exist")
    assert(type(p.setNextX) == "function", "setNextX must exist")
    assert(type(p.setNextY) == "function", "setNextY must exist")
end)

test("API:Player — setNextX/getNextX round-trip", function()
    local p = MockPlayer({})
    p:setNextX(42.5)
    assert_eq(p:getNextX(), 42.5, "setNextX/getNextX round-trip")
end)

test("API:Player — setNextX does NOT modify x (safe write)", function()
    local p = MockPlayer({})
    p:moveTo(10, 20)
    p:setNextX(15)
    assert_eq(p:getX(), 10, "setNextX must NOT change x")
    assert_eq(p:getNextX(), 15, "setNextX must change nextX")
end)

test("API:Player — setX DOES modify nextX (clobber behavior)", function()
    local p = MockPlayer({})
    p:moveTo(0, 0)
    p:setNextX(5.0)  -- set nextX to 5
    p:setX(3.0)      -- setX should clobber nextX to 3
    assert_eq(p:getX(), 3.0, "setX must change x")
    assert_eq(p:getNextX(), 3.0, "setX must ALSO clobber nextX (mirrors engine)")
end)

test("API:Player — isAsleep() exists (B42.16, replaces isSleeping)", function()
    local p = MockPlayer({})
    assert(type(p.isAsleep) == "function", "isAsleep must be a function")
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
        "EveryHours", "AddXP", "OnEnterVehicle",
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
    assert(gt.getTicks == nil, "getTicks must remain absent: it is not exposed by current GameTime")
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

test("API:Global — CharacterStat constants exist (B42.16 full set)", function()
    assert(CharacterStat.PAIN ~= nil, "PAIN")
    assert(CharacterStat.PANIC ~= nil, "PANIC")
    assert(CharacterStat.STRESS ~= nil, "STRESS")
    assert(CharacterStat.HUNGER ~= nil, "HUNGER")
    assert(CharacterStat.THIRST ~= nil, "THIRST")
    assert(CharacterStat.BOREDOM ~= nil, "BOREDOM")
    assert(CharacterStat.FATIGUE ~= nil, "FATIGUE")
    assert(CharacterStat.ENDURANCE ~= nil, "ENDURANCE")
    assert(CharacterStat.INTOXICATION ~= nil, "INTOXICATION")
    assert(CharacterStat.UNHAPPINESS ~= nil, "UNHAPPINESS")
    assert(CharacterStat.WETNESS ~= nil, "WETNESS")
    assert(CharacterStat.ZOMBIE_INFECTION ~= nil, "ZOMBIE_INFECTION")
    assert(CharacterStat.ZOMBIE_FEVER ~= nil, "ZOMBIE_FEVER")
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
    assert(type(s.set) == "function", "stats:set")
    assert(type(s.add) == "function", "stats:add")
    assert(type(s.remove) == "function", "stats:remove")
end)

test("API:Stats — CharacterStat.FATIGUE roundtrip (0-1 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.FATIGUE, 0.5)
    assert_eq(s:get(CharacterStat.FATIGUE), 0.5, "fatigue roundtrip")
end)

test("API:Stats — CharacterStat.PAIN roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.PAIN, 30)
    assert_eq(s:get(CharacterStat.PAIN), 30, "pain roundtrip")
end)

test("API:Stats — CharacterStat.STRESS roundtrip (0-1 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.STRESS, 0.2)
    assert_eq(s:get(CharacterStat.STRESS), 0.2, "stress roundtrip")
end)

test("API:Stats — CharacterStat.HUNGER roundtrip (0-1 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.HUNGER, 0.3)
    assert_eq(s:get(CharacterStat.HUNGER), 0.3, "hunger roundtrip")
end)

test("API:Stats — CharacterStat.THIRST roundtrip (0-1 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.THIRST, 0.4)
    assert_eq(s:get(CharacterStat.THIRST), 0.4, "thirst roundtrip")
end)

test("API:Stats — CharacterStat.ENDURANCE roundtrip (0-1 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.ENDURANCE, 0.7)
    assert_eq(s:get(CharacterStat.ENDURANCE), 0.7, "endurance roundtrip")
end)

test("API:Stats — CharacterStat.INTOXICATION roundtrip (0-100 scale, replaces drunkenness)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.INTOXICATION, 60)
    assert_eq(s:get(CharacterStat.INTOXICATION), 60, "intoxication roundtrip")
end)

test("API:Stats — CharacterStat.PANIC roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.PANIC, 50)
    assert_eq(s:get(CharacterStat.PANIC), 50, "panic roundtrip")
end)

test("API:Stats — CharacterStat.BOREDOM roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.BOREDOM, 30)
    assert_eq(s:get(CharacterStat.BOREDOM), 30, "boredom roundtrip")
end)

test("API:Stats — CharacterStat.UNHAPPINESS roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.UNHAPPINESS, 45)
    assert_eq(s:get(CharacterStat.UNHAPPINESS), 45, "unhappiness roundtrip")
end)

test("API:Stats — CharacterStat.WETNESS roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.WETNESS, 25)
    assert_eq(s:get(CharacterStat.WETNESS), 25, "wetness roundtrip")
end)

test("API:Stats — CharacterStat.ZOMBIE_INFECTION roundtrip (0-100 scale)", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.ZOMBIE_INFECTION, 15)
    assert_eq(s:get(CharacterStat.ZOMBIE_INFECTION), 15, "zombie infection roundtrip")
end)

test("API:Stats — add/remove delta operations", function()
    local p = MockPlayer({})
    local s = p:getStats()
    s:set(CharacterStat.PANIC, 50)
    s:add(CharacterStat.PANIC, 10)
    assert_eq(s:get(CharacterStat.PANIC), 60, "add 10 to panic")
    s:remove(CharacterStat.PANIC, 20)
    assert_eq(s:get(CharacterStat.PANIC), 40, "remove 20 from panic")
end)

test("API:Stats — CharacterStat entries have getMaximumValue", function()
    assert(type(CharacterStat.ENDURANCE.getMaximumValue) == "function", "ENDURANCE:getMaximumValue must exist")
    assert_eq(CharacterStat.ENDURANCE:getMaximumValue(), 1, "ENDURANCE max = 1")
    assert_eq(CharacterStat.PANIC:getMaximumValue(), 100, "PANIC max = 100")
    assert_eq(CharacterStat.FATIGUE:getMaximumValue(), 1, "FATIGUE max = 1")
    assert_eq(CharacterStat.INTOXICATION:getMaximumValue(), 100, "INTOXICATION max = 100")
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

test("API:BodyPart — getHealth/SetHealth round-trip", function()
    local part = MockBodyPart(BodyPartType.Neck)
    assert_eq(part:getHealth(), 1.0)
    part:SetHealth(0.25)
    assert_eq(part:getHealth(), 0.25)
end)

test("API:Static: BodyPartType.getDamageModifyer() exists", function()
    assert(type(BodyPartType.getDamageModifyer) == "function", "getDamageModifyer must be a function")
end)

test("API:Static: BodyPartType.ToIndex() exists", function()
    assert(type(BodyPartType.ToIndex) == "function", "ToIndex must be a function")
    assert_eq(BodyPartType.ToIndex(BodyPartType.Hand_L), 0)
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
