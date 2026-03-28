-- run_tests.lua  (UniversalTraits)
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua

local base = arg[0]:match("(.*[/\\])") or "./"
package.path = base .. "../media/?.lua;" .. package.path

-- Load mocks
dofile(base .. "UTTestMocks.lua")

-- Load registries
dofile(base .. "../media/registries.lua")

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
    if not v then error(msg or "expected true, got false", 2) end
end

-- registries.lua populates UTTraitsRegistries
test("UTTraitsRegistries table exists", function()
    assert_true(type(UTTraitsRegistries) == "table", "UTTraitsRegistries should be a table")
end)

test("UT_preparedfood registered", function()
    assert_eq(UTTraitsRegistries.UT_preparedfood, "UniversalTraits:UT_preparedfood")
end)

test("UT_swift registered", function()
    assert_eq(UTTraitsRegistries.UT_swift, "UniversalTraits:UT_swift")
end)

test("UT_martial registered", function()
    assert_eq(UTTraitsRegistries.UT_martial, "UniversalTraits:UT_martial")
end)

test("UT_terminator registered", function()
    assert_eq(UTTraitsRegistries.UT_terminator, "UniversalTraits:UT_terminator")
end)

test("UT_spears registered", function()
    assert_eq(UTTraitsRegistries.UT_spears, "UniversalTraits:UT_spears")
end)

test("UT_ingenuitive registered", function()
    assert_eq(UTTraitsRegistries.UT_ingenuitive, "UniversalTraits:UT_ingenuitive")
end)

test("UT_packmule registered", function()
    assert_eq(UTTraitsRegistries.UT_packmule, "UniversalTraits:UT_packmule")
end)

test("UT_staunch registered", function()
    assert_eq(UTTraitsRegistries.UT_staunch, "UniversalTraits:UT_staunch")
end)

-- Phase 2 spot-checks
test("UT_fast registered", function()
    assert_eq(UTTraitsRegistries.UT_fast, "UniversalTraits:UT_fast")
end)

test("UT_analgesia registered", function()
    assert_eq(UTTraitsRegistries.UT_analgesia, "UniversalTraits:UT_analgesia")
end)

test("UT_noxpshooter registered", function()
    assert_eq(UTTraitsRegistries.UT_noxpshooter, "UniversalTraits:UT_noxpshooter")
end)

test("UT_photographicmemory registered", function()
    assert_eq(UTTraitsRegistries.UT_photographicmemory, "UniversalTraits:UT_photographicmemory")
end)

test("UT_gourmand registered", function()
    assert_eq(UTTraitsRegistries.UT_gourmand, "UniversalTraits:UT_gourmand")
end)

-- Phase 3 spot-checks
test("UT_depressive registered", function()
    assert_eq(UTTraitsRegistries.UT_depressive, "UniversalTraits:UT_depressive")
end)

test("UT_alcoholic_II registered", function()
    assert_eq(UTTraitsRegistries.UT_alcoholic_II, "UniversalTraits:UT_alcoholic_II")
end)

test("UT_gunspecialist_II registered", function()
    assert_eq(UTTraitsRegistries.UT_gunspecialist_II, "UniversalTraits:UT_gunspecialist_II")
end)

test("UT_superimmune registered", function()
    assert_eq(UTTraitsRegistries.UT_superimmune, "UniversalTraits:UT_superimmune")
end)

test("UT_indefatigable registered", function()
    assert_eq(UTTraitsRegistries.UT_indefatigable, "UniversalTraits:UT_indefatigable")
end)

-- Verify all 199 expected trait IDs are registered in CharacterTrait._registered
local expected_ids = {
    -- Prepared series (8)
    "UniversalTraits:UT_preparedfood", "UniversalTraits:UT_preparedammo",
    "UniversalTraits:UT_preparedmedical", "UniversalTraits:UT_preparedcarpentry",
    "UniversalTraits:UT_preparedcamp", "UniversalTraits:UT_preparedweapons",
    "UniversalTraits:UT_preparedcars", "UniversalTraits:UT_preparedcartography",
    -- Movement & Stealth (12)
    "UniversalTraits:UT_swift", "UniversalTraits:UT_flexible",
    "UniversalTraits:UT_quiet", "UniversalTraits:UT_olympian",
    "UniversalTraits:UT_evasive", "UniversalTraits:UT_marathonrunner",
    "UniversalTraits:UT_strongnimble", "UniversalTraits:UT_taut",
    "UniversalTraits:UT_ninjaway", "UniversalTraits:UT_gymgoer",
    "UniversalTraits:UT_sprintdemon", "UniversalTraits:UT_trekker",
    -- Combat Melee (8)
    "UniversalTraits:UT_martial", "UniversalTraits:UT_bladetwirl",
    "UniversalTraits:UT_blunttwirl", "UniversalTraits:UT_tavernbrawler",
    "UniversalTraits:UT_grunt", "UniversalTraits:UT_actionhero",
    "UniversalTraits:UT_cruelty", "UniversalTraits:UT_sharpshooter",
    -- Prowess (4)
    "UniversalTraits:UT_problunt", "UniversalTraits:UT_problade",
    "UniversalTraits:UT_progun", "UniversalTraits:UT_prospear",
    -- Specialization (7)
    "UniversalTraits:UT_specweapons", "UniversalTraits:UT_speccrafting",
    "UniversalTraits:UT_specfood", "UniversalTraits:UT_specguns",
    "UniversalTraits:UT_specmove", "UniversalTraits:UT_specaid",
    "UniversalTraits:UT_terminator",
    -- Weapon Tree (17)
    "UniversalTraits:UT_heavyswing", "UniversalTraits:UT_twohanded",
    "UniversalTraits:UT_onehanded", "UniversalTraits:UT_axes",
    "UniversalTraits:UT_twohanded_axes", "UniversalTraits:UT_onehanded_axes",
    "UniversalTraits:UT_blunts", "UniversalTraits:UT_twohanded_blunts",
    "UniversalTraits:UT_onehanded_blunts", "UniversalTraits:UT_long_blunts",
    "UniversalTraits:UT_short_blunts", "UniversalTraits:UT_blades",
    "UniversalTraits:UT_twohanded_blades", "UniversalTraits:UT_onehanded_blades",
    "UniversalTraits:UT_long_blades", "UniversalTraits:UT_short_blades",
    "UniversalTraits:UT_spears",
    -- Crafting & Knowledge (19)
    "UniversalTraits:UT_ingenuitive", "UniversalTraits:UT_generator",
    "UniversalTraits:UT_tinkerer", "UniversalTraits:UT_scrapper",
    "UniversalTraits:UT_scrounger", "UniversalTraits:UT_natural",
    "UniversalTraits:UT_wildsman", "UniversalTraits:UT_mushroomer",
    "UniversalTraits:UT_antique", "UniversalTraits:UT_blissful",
    "UniversalTraits:UT_gordanite", "UniversalTraits:UT_graverobber",
    "UniversalTraits:UT_vagabond", "UniversalTraits:UT_crafty",
    "UniversalTraits:UT_paramedic", "UniversalTraits:UT_pitcrew",
    "UniversalTraits:UT_prodigy", "UniversalTraits:UT_driver",
    "UniversalTraits:UT_amateurelectrician",
    -- FillerTraits (4)
    "UniversalTraits:UT_trackman", "UniversalTraits:UT_cleaver",
    "UniversalTraits:UT_woodsplitter", "UniversalTraits:UT_improviser",
    -- Stat Modifiers (20)
    "UniversalTraits:UT_packmule", "UniversalTraits:UT_packmouse",
    "UniversalTraits:UT_gimp", "UniversalTraits:UT_anemic",
    "UniversalTraits:UT_badteeth", "UniversalTraits:UT_deprived",
    "UniversalTraits:UT_couchdweller", "UniversalTraits:UT_sloth",
    "UniversalTraits:UT_squirrel", "UniversalTraits:UT_antivaxxer",
    "UniversalTraits:UT_flimsy", "UniversalTraits:UT_sundayrunner",
    "UniversalTraits:UT_lesssweaty", "UniversalTraits:UT_highsweaty",
    "UniversalTraits:UT_cangrabmore", "UniversalTraits:UT_cangrabless",
    "UniversalTraits:UT_backpacker", "UniversalTraits:UT_topheavy",
    "UniversalTraits:UT_sore", "UniversalTraits:UT_staunch",
    -- Phase 2 — Spawn / Inventory (1)
    "UniversalTraits:UT_preparedpack",
    -- Phase 2 — Movement (5)
    "UniversalTraits:UT_fast", "UniversalTraits:UT_noodlelegs",
    "UniversalTraits:UT_pacer", "UniversalTraits:UT_lurcher",
    "UniversalTraits:UT_sorelegs",
    -- Phase 2 — Work Speed (3)
    "UniversalTraits:UT_quickworker", "UniversalTraits:UT_slowworker",
    "UniversalTraits:UT_slack",
    -- Phase 2 — Combat & Physical (7)
    "UniversalTraits:UT_batteringram", "UniversalTraits:UT_fitted",
    "UniversalTraits:UT_glassbody", "UniversalTraits:UT_brittle",
    "UniversalTraits:UT_flailer", "UniversalTraits:UT_fasthands",
    "UniversalTraits:UT_analgesia",
    -- Phase 2 — Bleeding (3)
    "UniversalTraits:UT_thickblood", "UniversalTraits:UT_heavilybleedingwounds",
    "UniversalTraits:UT_weaklybleedingwounds",
    -- Phase 2 — Sleep & Rest (3)
    "UniversalTraits:UT_restfulsleeper", "UniversalTraits:UT_quickrest",
    "UniversalTraits:UT_snorer",
    -- Phase 2 — Psychology & Modifiers (5)
    "UniversalTraits:UT_unwavering", "UniversalTraits:UT_idealweight",
    "UniversalTraits:UT_mundane", "UniversalTraits:UT_incomprehensive",
    "UniversalTraits:UT_photographicmemory",
    -- Phase 2 — XP Penalties (4)
    "UniversalTraits:UT_antigun", "UniversalTraits:UT_flatearther",
    "UniversalTraits:UT_luddite", "UniversalTraits:UT_onetrickpony",
    -- Phase 2 — No-XP Series (6)
    "UniversalTraits:UT_noxpshooter", "UniversalTraits:UT_noxptechnician",
    "UniversalTraits:UT_noxpaxe", "UniversalTraits:UT_noxpfirstaid",
    "UniversalTraits:UT_noxpmaintenance", "UniversalTraits:UT_noxpsneaky",
    -- Phase 2 — Timed / Circadian (2)
    "UniversalTraits:UT_owlperson", "UniversalTraits:UT_larkperson",
    -- Phase 2 — Vehicle (3)
    "UniversalTraits:UT_leadfoot", "UniversalTraits:UT_expertdriver",
    "UniversalTraits:UT_poordriver",
    -- Phase 2 — Item / Consumption (4)
    "UniversalTraits:UT_ironliver", "UniversalTraits:UT_durability",
    "UniversalTraits:UT_gourmand", "UniversalTraits:UT_ascetic",
    -- Phase 3a — Spawn-With-Condition (4)
    "UniversalTraits:UT_injured_I", "UniversalTraits:UT_injured_II",
    "UniversalTraits:UT_broke", "UniversalTraits:UT_burned",
    -- Phase 3b — Periodic-Check (25)
    "UniversalTraits:UT_depressive", "UniversalTraits:UT_paranoia",
    "UniversalTraits:UT_selfdestructive", "UniversalTraits:UT_melancholic",
    "UniversalTraits:UT_immuneresponse", "UniversalTraits:UT_ravenous",
    "UniversalTraits:UT_optimist", "UniversalTraits:UT_pessimist",
    "UniversalTraits:UT_mstoptimist", "UniversalTraits:UT_adaptivemetabolism",
    "UniversalTraits:UT_accmetabolism", "UniversalTraits:UT_albino",
    "UniversalTraits:UT_fibromyalgia", "UniversalTraits:UT_bigorexia",
    "UniversalTraits:UT_weathersensitive", "UniversalTraits:UT_panicattacks",
    "UniversalTraits:UT_fearofthedark", "UniversalTraits:UT_coldsensitive",
    "UniversalTraits:UT_heatsensitive", "UniversalTraits:UT_sedentary",
    "UniversalTraits:UT_alcoholic_I", "UniversalTraits:UT_alcoholic_II",
    "UniversalTraits:UT_alcoholic_III", "UniversalTraits:UT_addictedtocaffeine",
    "UniversalTraits:UT_immunocompromised",
    -- Phase 3c — Event-Driven (22)
    "UniversalTraits:UT_fearful", "UniversalTraits:UT_nervouswreck",
    "UniversalTraits:UT_scardycat", "UniversalTraits:UT_maniac",
    "UniversalTraits:UT_anorexy", "UniversalTraits:UT_pillsallergy",
    "UniversalTraits:UT_wildplantsallergy", "UniversalTraits:UT_allergic",
    "UniversalTraits:UT_competitiveeater", "UniversalTraits:UT_sensitivestomach",
    "UniversalTraits:UT_butterfingers", "UniversalTraits:UT_acrophobic",
    "UniversalTraits:UT_vehophobic", "UniversalTraits:UT_motionsickness",
    "UniversalTraits:UT_physicallyactive", "UniversalTraits:UT_humanhamster",
    "UniversalTraits:UT_superimmune", "UniversalTraits:UT_bouncer_I",
    "UniversalTraits:UT_bouncer_II", "UniversalTraits:UT_gunspecialist_I",
    "UniversalTraits:UT_gunspecialist_II", "UniversalTraits:UT_gunspecialist_III",
    -- Phase 3d — Complex State (3)
    "UniversalTraits:UT_indefatigable", "UniversalTraits:UT_hardy",
    "UniversalTraits:UT_secondwind",
}

test("all 199 trait IDs registered with CharacterTrait", function()
    local missing = {}
    for _, id in ipairs(expected_ids) do
        if not CharacterTrait._registered[id] then
            missing[#missing + 1] = id
        end
    end
    if #missing > 0 then
        error("Missing registrations: " .. table.concat(missing, ", "), 2)
    end
end)

test("total registration count is 199", function()
    local count = 0
    for _ in pairs(CharacterTrait._registered) do count = count + 1 end
    assert_eq(count, 199, "registration count")
end)

-- ===== Per-trait moddata spot checks =====
-- Trait files use UTCore.hasTrait, UTCore.apply*, and Events.OnNewGame.
-- All stubs are already provided by UTTestMocks.lua above.

-- Helper: create a player that has the given traitId, fire OnNewGame, return player
local function fireNewGame(traitId)
    local p = MockPlayer({ traitId })
    Events.OnNewGame:fire(p)
    return p
end

-- Load the 7 gap traits (registers their OnNewGame handlers at load time)
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_onetrickpony.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flatearther.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fast.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noodlelegs.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_quickworker.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_thickblood.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_heavilybleedingwounds.lua")

test("UT_onetrickpony sets UT_multiSkillPenalty=true", function()
    local p = fireNewGame("UniversalTraits:UT_onetrickpony")
    assert_eq(p:getModData()["UT_multiSkillPenalty"], true, "UT_onetrickpony")
end)

-- UT_flatearther writes UT_readSpeedMod = 0.3 (positive = slower reading)
test("UT_flatearther sets UT_readSpeedMod > 0", function()
    local p = fireNewGame("UniversalTraits:UT_flatearther")
    local v = p:getModData()["UT_readSpeedMod"]
    assert_true(type(v) == "number" and v > 0, "expected UT_readSpeedMod > 0, got " .. tostring(v))
end)

-- UT_fast calls UTCore.applySpeedModifier(player, 0.3) -> UT_speedMod = 0.3 (positive = faster)
test("UT_fast sets UT_speedMod > 0", function()
    local p = fireNewGame("UniversalTraits:UT_fast")
    local v = p:getModData()["UT_speedMod"]
    assert_true(type(v) == "number" and v > 0, "expected UT_speedMod > 0, got " .. tostring(v))
end)

-- UT_noodlelegs writes UT_speedMod = -0.2 directly into moddata (negative penalty)
test("UT_noodlelegs sets UT_speedMod < 0", function()
    local p = fireNewGame("UniversalTraits:UT_noodlelegs")
    local v = p:getModData()["UT_speedMod"]
    assert_true(type(v) == "number" and v < 0, "expected UT_speedMod < 0, got " .. tostring(v))
end)

-- UT_quickworker calls UTCore.applyWorkSpeed(player, -0.3) -> UT_workSpeedMod = -0.3 (negative = faster)
test("UT_quickworker sets UT_workSpeedMod < 0", function()
    local p = fireNewGame("UniversalTraits:UT_quickworker")
    local v = p:getModData()["UT_workSpeedMod"]
    assert_true(type(v) == "number" and v < 0, "expected UT_workSpeedMod < 0, got " .. tostring(v))
end)

-- UT_thickblood calls UTCore.applyBleedRate(player, 0.5) -> UT_bleedMult = 0.5 (reduced bleed)
test("UT_thickblood sets UT_bleedMult < 1.0", function()
    local p = fireNewGame("UniversalTraits:UT_thickblood")
    local v = p:getModData()["UT_bleedMult"]
    assert_true(type(v) == "number" and v < 1.0, "expected UT_bleedMult < 1.0, got " .. tostring(v))
end)

-- UT_heavilybleedingwounds calls UTCore.applyBleedRate(player, 2.0) -> UT_bleedMult = 2.0 (increased bleed)
test("UT_heavilybleedingwounds sets UT_bleedMult > 1.0", function()
    local p = fireNewGame("UniversalTraits:UT_heavilybleedingwounds")
    local v = p:getModData()["UT_bleedMult"]
    assert_true(type(v) == "number" and v > 1.0, "expected UT_bleedMult > 1.0, got " .. tostring(v))
end)

-- ===== UT_actionhero runtime damage tests =====
-- Load the trait file so its Events.OnWeaponHitCharacter.Add() fires.
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_actionhero.lua")

-- Helper: build a minimal weapon mock
local function MockWeapon(typeName)
    return { getType = function(self) return typeName end }
end

-- Helper: build a target mock with mutable health
local function MockTarget(startHealth)
    local hp = startHealth
    return {
        getHealth = function(self) return hp end,
        setHealth = function(self, v) hp = v end,
    }
end

-- Helper: build a spotted-list mock returning N enemies all at the given distance
local function MockSpottedList(count, dist)
    local enemies = {}
    for i = 1, count do
        enemies[i] = { _dist = dist }
    end
    return {
        size = function(self) return count end,
        get  = function(self, i) return enemies[i + 1] end,
    }
end

-- Helper: extend MockPlayer with the extra methods actionhero needs
local function MockActionPlayer(traitList, spottedList)
    local p = MockPlayer(traitList)
    p.getSpottedList = function(self) return spottedList end
    p.DistTo = function(self, enemy) return enemy._dist end
    return p
end

test("actionhero deals bonus damage when surrounded (5 enemies within 2 tiles)", function()
    local spotted  = MockSpottedList(5, 1)   -- 5 enemies at dist=1 (≤2)
    local player   = MockActionPlayer(
        { "UniversalTraits:UT_actionhero" },
        spotted
    )
    local weapon   = MockWeapon("Axe")
    local target   = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, weapon, target)

    assert_true(target:getHealth() < 100,
        "expected health < 100 after actionhero crit, got " .. tostring(target:getHealth()))
end)

test("actionhero skipped when player has UT_mundane", function()
    local spotted = MockSpottedList(5, 1)
    local player  = MockActionPlayer(
        { "UniversalTraits:UT_actionhero", "UniversalTraits:UT_mundane" },
        spotted
    )
    local weapon  = MockWeapon("Axe")
    local target  = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, weapon, target)

    assert_eq(target:getHealth(), 100,
        "expected health unchanged when UT_mundane is active")
end)

-- ===== UT_bouncer_I stagger mechanic tests =====
-- Load the trait file so its Events.OnPlayerUpdate.Add() fires.
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_bouncer_I.lua")

-- Helper: build an enemy mock with mutable staggerBack flag
local function MockEnemy(dist)
    return {
        _dist        = dist,
        _staggerBack = false,
        setStaggerBack = function(self, v) self._staggerBack = v end,
    }
end

-- Helper: build a spotted-list mock from an explicit enemy array
local function MockSpottedListFromEnemies(enemies)
    return {
        size = function(self) return #enemies end,
        get  = function(self, i) return enemies[i + 1] end,
    }
end

-- Helper: extend MockPlayer with the methods bouncer needs
local function MockBouncerPlayer(traitList, spottedList)
    local p = MockPlayer(traitList)
    p.getSpottedList = function(self) return spottedList end
    p.DistTo = function(self, enemy) return enemy._dist end
    return p
end

test("bouncer stagger fires when >=3 close enemies and cooldown=0", function()
    local enemies = {
        MockEnemy(1.5), MockEnemy(1.5), MockEnemy(1.5), MockEnemy(1.5),
    }
    local spotted = MockSpottedListFromEnemies(enemies)
    local player  = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, spotted)
    -- Cooldown starts at 0 (nil → initialized to 0 in handler)

    Events.OnPlayerUpdate:fire(player)

    -- ZombRand is stubbed to always return 0, so 0 < 5 is true → stagger fires
    local staggered = false
    for _, e in ipairs(enemies) do
        if e._staggerBack then staggered = true end
    end
    assert_true(staggered, "expected at least one enemy to be staggered")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 60, "cooldown should be set to 60")
end)

test("bouncer stagger does NOT fire during cooldown", function()
    local enemies = {
        MockEnemy(1.5), MockEnemy(1.5), MockEnemy(1.5), MockEnemy(1.5),
    }
    local spotted = MockSpottedListFromEnemies(enemies)
    local player  = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, spotted)
    player:getModData()["UT_bouncer_cooldown"] = 30

    Events.OnPlayerUpdate:fire(player)

    local staggered = false
    for _, e in ipairs(enemies) do
        if e._staggerBack then staggered = true end
    end
    assert_true(not staggered, "expected no enemy to be staggered during cooldown")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 29, "cooldown should decrement to 29")
end)

-- ===== UT_vagabond loot mechanic tests =====
-- Load the trait file so handleContainerInspect is exposed as a global.
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_vagabond.lua")

local vagabondItems = {
    "Base.Tuna", "Base.BakedBeans", "Base.SoupCan",
    "Base.Socks", "Base.Tshirt",
    "Base.RoadMap1", "Base.RoadMap2",
    "Base.Screwdriver", "Base.WoodGlue",
}

test("vagabond loot: adds item from loot table to container on first inspect (guaranteed roll)", function()
    -- ZombRand is already stubbed to return 0:
    --   ZombRand(100) → 0 < 33, so roll succeeds
    --   ZombRand(9)   → 0 + 1 = 1, so picks vagabondItems[1] = "Base.Tuna"
    local player = MockPlayer({ "UniversalTraits:UT_vagabond" })

    local addedItem = nil
    local container = {
        getObject = function(self) return nil end,
        AddItem   = function(self, itemType) addedItem = itemType end,
    }

    UT_vagabond_handleContainerInspect(player, container)

    -- Verify an item was added and it belongs to the loot table
    assert_true(addedItem ~= nil, "expected AddItem to be called, but it was not")
    local valid = false
    for _, v in ipairs(vagabondItems) do
        if v == addedItem then valid = true; break end
    end
    assert_true(valid, "added item '" .. tostring(addedItem) .. "' is not in vagabondItems loot table")

    -- Verify container is marked as looted
    local lootedKey = "UT_vagabond_looted_" .. tostring(container)
    assert_true(player:getModData()[lootedKey] == true, "container should be marked as looted")
end)

test("vagabond loot: skips already-looted container", function()
    local player = MockPlayer({ "UniversalTraits:UT_vagabond" })
    local callCount = 0
    local container = {
        getObject = function(self) return nil end,
        AddItem   = function(self, itemType) callCount = callCount + 1 end,
    }
    -- Pre-mark this container as looted
    local lootedKey = "UT_vagabond_looted_" .. tostring(container)
    player:getModData()[lootedKey] = true

    UT_vagabond_handleContainerInspect(player, container)

    assert_eq(callCount, 0, "AddItem should not be called for an already-looted container")
end)

test("vagabond loot: skips player without vagabond trait", function()
    local player = MockPlayer({})  -- no traits
    local callCount = 0
    local container = {
        getObject = function(self) return nil end,
        AddItem   = function(self, itemType) callCount = callCount + 1 end,
    }

    UT_vagabond_handleContainerInspect(player, container)

    assert_eq(callCount, 0, "AddItem should not be called when player lacks vagabond trait")
end)

test("vagabond loot: container NOT marked as looted when roll fails", function()
    -- Stub ZombRand to return 50 so ZombRand(100) = 50 >= 33 (roll fails)
    local _origZombRand = _G.ZombRand
    _G.ZombRand = function(n) return 50 end

    local player = MockPlayer({ "UniversalTraits:UT_vagabond" })
    local callCount = 0
    local container = {
        getObject = function(self) return nil end,
        AddItem   = function(self, itemType) callCount = callCount + 1 end,
    }

    UT_vagabond_handleContainerInspect(player, container)

    -- Restore ZombRand
    _G.ZombRand = _origZombRand

    assert_eq(callCount, 0, "AddItem should NOT be called when roll fails")
    local lootedKey = "UT_vagabond_looted_" .. tostring(container)
    assert_true(player:getModData()[lootedKey] == nil,
        "container should NOT be marked as looted when roll fails")
end)

-- ===== UT_martial barehands damage tests =====
-- Load the trait file so its Events.OnWeaponHitCharacter.Add() fires.
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_martial.lua")

test("martial deals bonus damage with bare hands (guaranteed crit)", function()
    -- SmallBlunt level=5 → critchance = (5+5)*0.01 = 0.10 → 10%
    -- ZombRand always returns 0 → 0 < 10 → crit fires
    local player = MockPlayer({ "UniversalTraits:UT_martial" })
    player:setPerkLevel(Perks.SmallBlunt, 5)
    -- endurance starts at 1.0 in MockPlayer (no penalty)

    local weapon = MockWeapon("BareHands")
    local target = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, weapon, target)

    assert_true(target:getHealth() < 100,
        "expected health < 100 after martial crit, got " .. tostring(target:getHealth()))
end)

test("martial skips when weapon is not BareHands", function()
    local player = MockPlayer({ "UniversalTraits:UT_martial" })
    player:setPerkLevel(Perks.SmallBlunt, 5)

    local weapon = MockWeapon("Axe")
    local target = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, weapon, target)

    assert_eq(target:getHealth(), 100,
        "expected health unchanged when weapon is not BareHands")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
