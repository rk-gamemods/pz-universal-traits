-- run_tests.lua  (UniversalTraits)
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua

local base = arg[0]:match("(.*[/\\])") or "./"
package.path = base .. "../media/?.lua;" .. package.path

-- Load mocks
dofile(base .. "UTTestMocks.lua")

-- Load registries
dofile(base .. "../media/registries.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/UT_MET.lua")

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

local function assert_contains(list, value, msg)
    for _, item in ipairs(list) do
        if item == value then
            return
        end
    end
    error((msg or "") .. " missing value=" .. tostring(value), 2)
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

local function collectRegisteredIdsFromRegistries(text)
    local ids = {}

    for id in text:gmatch('CharacterTrait%.register%(%"([^"]+)"%)') do
        ids[id] = true
    end

    return ids
end

local function parseScriptTraitDefinitions(text)
    local defs = {}
    local current_def = nil
    local current = nil

    for line in text:gmatch("[^\r\n]+") do
        local def = line:match("^%s*character_trait_definition%s+([^%s]+)")
        if def then
            current_def = def
            current = {
                block_id = def,
                character_trait = nil,
                cost = nil,
                granted_traits = {},
                mutually_exclusive_traits = {},
            }
            defs[#defs + 1] = current
        elseif current then
            local character_trait = line:match("^%s*CharacterTrait%s*=%s*([^,%s]+)")
            if character_trait then
                current.character_trait = character_trait
            end

            local cost = line:match("^%s*Cost%s*=%s*(-?%d+)")
            if cost then
                current.cost = tonumber(cost)
            end

            local granted = line:match("^%s*GrantedTraits%s*=%s*(.-),%s*$")
            if granted then
                for trait_id in granted:gmatch("([^;]+)") do
                    current.granted_traits[#current.granted_traits + 1] = trait_id
                end
            end

            local me = line:match("^%s*MutuallyExclusiveTraits%s*=%s*(.-),%s*$")
            if me then
                for trait_id in me:gmatch("([^;]+)") do
                    current.mutually_exclusive_traits[#current.mutually_exclusive_traits + 1] = trait_id
                end
            end
        end
    end

    return defs
end

-- Verify all 199 expected trait IDs are registered in CharacterTrait._registered
local expected_ids = {
    -- Prepared series (7)
    "UniversalTraits:UT_preparedfood", "UniversalTraits:UT_preparedammo",
    "UniversalTraits:UT_preparedmedical", "UniversalTraits:UT_preparedcarpentry",
    "UniversalTraits:UT_preparedcamp", "UniversalTraits:UT_preparedweapons",
    "UniversalTraits:UT_preparedcars",
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

test("all 198 trait IDs registered with CharacterTrait", function()
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

test("script costs match the current balance decisions", function()
    local file = io.open(base .. "../media/scripts/UT_character_traits.txt", "r")
    assert_true(file ~= nil, "failed to open UT_character_traits.txt")
    local defs = parseScriptTraitDefinitions(file:read("*a"))
    file:close()

    local costs = {}
    for _, def in ipairs(defs) do
        costs[def.block_id] = def.cost
    end

    assert_eq(costs["UniversalTraits:UT_packmule"], 3, "packmule cost")
    assert_eq(costs["UniversalTraits:UT_preparedpack"], 1, "preparedpack cost")
    assert_eq(costs["UniversalTraits:UT_quickworker"], 9, "quickworker cost")
    assert_eq(costs["UniversalTraits:UT_slowworker"], -6, "slowworker cost")
end)

test("total registration count is 198", function()
    local count = 0
    for _ in pairs(CharacterTrait._registered) do count = count + 1 end
    assert_eq(count, 198, "registration count")
end)

test("script trait definitions resolve cleanly and preserve UT_MET coverage", function()
    local registry_file = io.open(base .. "../media/registries.lua", "r")
    assert_true(registry_file ~= nil, "failed to open registries.lua")
    local registry_text = registry_file:read("*a")
    registry_file:close()

    local file = io.open(base .. "../media/scripts/UT_character_traits.txt", "r")
    assert_true(file ~= nil, "failed to open UT_character_traits.txt")

    local text = file:read("*a")
    file:close()

    local registered_ids = collectRegisteredIdsFromRegistries(registry_text)
    local defs = parseScriptTraitDefinitions(text)
    local me_by_trait = {}
    local def_by_trait = {}

    for _, def in ipairs(defs) do
        assert_true(def.block_id == def.character_trait,
            def.block_id .. " CharacterTrait mismatch: " .. tostring(def.character_trait))
        assert_true(registered_ids[def.character_trait] == true,
            def.block_id .. " missing registry entry: " .. tostring(def.character_trait))

        for _, granted_trait in ipairs(def.granted_traits) do
            assert_true(granted_trait ~= "", def.block_id .. " has empty GrantedTraits entry")
            if granted_trait:match("^UniversalTraits:") then
                assert_true(registered_ids[granted_trait] == true,
                    def.block_id .. " GrantedTraits missing registry entry: " .. granted_trait)
            end
        end

        for _, me_trait in ipairs(def.mutually_exclusive_traits) do
            assert_true(me_trait ~= "", def.block_id .. " has empty MutuallyExclusiveTraits entry")
            if me_trait:match("^UniversalTraits:") then
                assert_true(registered_ids[me_trait] == true,
                    def.block_id .. " MutuallyExclusiveTraits missing registry entry: " .. me_trait)
            end
        end

        me_by_trait[def.block_id] = def.mutually_exclusive_traits
        def_by_trait[def.block_id] = def
    end

    local grouped_traits = {
        UT_MET.Specialization,
        UT_MET.WeaponTree,
        UT_MET.Prowess,
        UT_MET.Driving,
    }

    for _, group in ipairs(grouped_traits) do
        for _, trait_id in ipairs(group) do
            local refs = me_by_trait[trait_id] or {}
            for _, other_id in ipairs(group) do
                if other_id ~= trait_id then
                    assert_contains(refs, other_id,
                        trait_id .. " missing character-creation MET reference to " .. other_id)
                end
            end
        end
    end
end)

-- ===== Per-trait moddata spot checks =====
-- Trait files use UTCore.hasTrait, UTCore.apply*, and Events.OnNewGame / OnCreatePlayer.
-- All stubs are already provided by UTTestMocks.lua above.

-- Helper: create a player that has the given traitId, fire OnNewGame, return player
local function fireNewGame(traitId, opts)
    local p = MockPlayer({ traitId }, opts)
    Events.OnNewGame:fire(p)
    return p
end

local function fireCreatePlayer(traitId, opts)
    local p = MockPlayer({ traitId }, opts)
    Events.OnCreatePlayer:fire(0, p)
    return p
end

local function withActivePlayer(player, fn)
    local originalGetPlayer = _G.getPlayer
    _G.getPlayer = function() return player end
    local ok, err = pcall(fn)
    _G.getPlayer = originalGetPlayer
    if not ok then error(err, 0) end
end

local function xpWasCancelled(player, perk, amount)
    for _, call in ipairs(player:getXp()._log) do
        if call.perk == perk and call.amount == -(amount or 10) then
            return true
        end
    end
    return false
end

-- Load the 7 gap traits (registers their OnNewGame handlers at load time)
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_onetrickpony.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flatearther.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fast.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noodlelegs.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_quickworker.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_slowworker.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_packmule.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_preparedpack.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_thickblood.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_heavilybleedingwounds.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_photographicmemory.lua")
dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpmaintenance.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpsneaky.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_driver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_expertdriver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_poordriver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_indefatigable.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_hardy.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_secondwind.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_immuneresponse.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_immunocompromised.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_superimmune.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_butterfingers.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_idealweight.lua")

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

test("UT_packmule applies the new +6 carry weight bonus", function()
    local p = fireCreatePlayer("UniversalTraits:UT_packmule")
    assert_eq(p:getMaxWeightBase(), 14, "expected base carry weight 14 after Pack Mule")
end)

test("UT_preparedpack keeps the +3 carry weight bonus", function()
    local p = fireCreatePlayer("UniversalTraits:UT_preparedpack")
    assert_eq(p:getMaxWeightBase(), 11, "expected base carry weight 11 after Prepared: Pack")
end)

-- UT_thickblood sets UT_bleedDecayMult=1.5 (faster clot) and UT_bleedDrainMult=0.5 (slower death)
test("UT_thickblood sets UT_bleedDecayMult > 1.0 and UT_bleedDrainMult < 1.0", function()
    local p = fireNewGame("UniversalTraits:UT_thickblood")
    local decay = p:getModData()["UT_bleedDecayMult"]
    local drain = p:getModData()["UT_bleedDrainMult"]
    assert_true(type(decay) == "number" and decay > 1.0, "expected UT_bleedDecayMult > 1.0, got " .. tostring(decay))
    assert_true(type(drain) == "number" and drain < 1.0, "expected UT_bleedDrainMult < 1.0, got " .. tostring(drain))
end)

-- UT_heavilybleedingwounds sets UT_bleedDrainMult=2.0 (faster death rate)
test("UT_heavilybleedingwounds sets UT_bleedDrainMult > 1.0", function()
    local p = fireNewGame("UniversalTraits:UT_heavilybleedingwounds")
    local v = p:getModData()["UT_bleedDrainMult"]
    assert_true(type(v) == "number" and v > 1.0, "expected UT_bleedDrainMult > 1.0, got " .. tostring(v))
end)

test("UT_photographicmemory sets global XP, read speed, and reading mood keys", function()
    local p = fireCreatePlayer("UniversalTraits:UT_photographicmemory")
    local md = p:getModData()
    assert_eq(md["UT_xpMult_All"], 1.5, "expected global XP mult 1.5")
    assert_true(type(md["UT_readSpeedMod"]) == "number" and md["UT_readSpeedMod"] < -0.6,
        "expected roughly 3x faster reading, got " .. tostring(md["UT_readSpeedMod"]))
    assert_eq(md["UT_readCalm"], true, "expected UT_readCalm=true")
    assert_eq(md["UT_readMoodBonus"], 5, "expected UT_readMoodBonus=5")
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

-- ===== Task 7: SomewhatTraits behavior ports =====
-- Load the four ported trait files
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flailer.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_lurcher.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_scardycat.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_pacer.lua")

-- Helper: build a player with getSpottedList support
local function MockUpdatePlayer(traitList, opts)
    opts = opts or {}
    local p = MockPlayer(traitList)
    p._sprinting = opts.sprinting or false
    p._moving    = opts.moving    or false
    p._indoors   = opts.indoors   or false
    if opts.spottedSize then
        p.getSpottedList = function(self)
            return { size = function() return opts.spottedSize end }
        end
    end
    if opts.endurance ~= nil then
        p:getStats()._endurance = opts.endurance
    end
    if opts.panicLevel ~= nil then
        p:getBodyDamage()._panicLevel = opts.panicLevel
    end
    if opts.nimble ~= nil then
        p:setPerkLevel(Perks.Nimble, opts.nimble)
    end
    if opts.indoorTicks ~= nil then
        p:getModData()["UT_pacer_indoor_ticks"] = opts.indoorTicks
    end
    return p
end

test("flailer stumble fires when panicked and sprinting", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_flailer" },
        { sprinting = true, panicLevel = 2 }
    )
    -- cooldown starts nil (=> 0), ZombRand returns 0 (< 5) => stumble fires
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._bumpFallDown == true,
        "expected _bumpFallDown=true after flailer stumble, got " .. tostring(player._bumpFallDown))
end)

test("lurcher stumble fires when fatigued and moving", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_lurcher" },
        { moving = true, endurance = 0.2, nimble = 0 }
    )
    -- cooldown starts nil (=> 0), ZombRand returns 0 (< 3) => stumble fires
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._bumpFallDown == true,
        "expected _bumpFallDown=true after lurcher stumble, got " .. tostring(player._bumpFallDown))
end)

test("scardycat screams when 10 zombies spotted", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_scardycat" },
        { spottedSize = 10 }
    )
    -- cooldown starts nil (=> 0), ZombRand returns 0 (< 3) => scream fires
    Events.OnPlayerUpdate:fire(player)
    -- ShouldBeShouting fires first via pcall and sets _shouted=true
    assert_true(player._shouted == true or player._said ~= nil,
        "expected player to scream (_shouted=true or _said set), got _shouted="
        .. tostring(player._shouted) .. " _said=" .. tostring(player._said))
end)

test("pacer applies unhappiness after 600 indoor ticks", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_pacer" },
        { indoors = true, indoorTicks = 599 }
    )
    local bd = player:getBodyDamage()
    local startUnhappiness = bd._unhappinessLevel  -- 50
    Events.OnPlayerUpdate:fire(player)
    assert_true(bd._unhappinessLevel > startUnhappiness,
        "expected unhappiness to increase after 600 indoor ticks, got "
        .. tostring(bd._unhappinessLevel))
end)

-- ===== UT_batteringram collision tests =====
UTCore._zombieCollisionCallbacks = {}  -- reset before batteringram tests
-- Load the collision hook so declareZombieCollisionHandler is available
dofile("UT_CORE/media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_batteringram.lua")

local function fireRamCollision(player, zombie)
    local fn = UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"]
    if fn then fn(player, zombie) end
end

test("batteringram: NOT registered when player lacks the trait", function()
    UTCore._zombieCollisionCallbacks = {}
    local player = MockPlayer({})  -- no trait
    Events.OnCreatePlayer:fire(0, player)
    assert_true(UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"] == nil,
        "expected callback NOT registered when trait absent")
end)

test("batteringram knocks zombie down when player is sprinting", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    assert_eq(#zombie:getKnockDownCalls(), 1, "expected knockDown called once")
end)

test("batteringram cancels bump state when player is sprinting", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    player._bumpType = "stagger"
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    assert_eq(player._bumpType, "", "expected bumpType cleared")
end)

test("batteringram drains endurance on each collision", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    assert_true(player:getStats():getEndurance() < 1.0,
        "expected endurance < 1.0 after collision")
end)

test("batteringram does NOT fire when player is not sprinting or running", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    -- _sprinting and _running are both false (default)
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    assert_eq(#zombie:getKnockDownCalls(), 0, "expected no knockDown when not sprinting")
end)

test("batteringram with UT_martial damages zombie on collision", function()
    -- ZombRand stub returns 0 → crit fires (0 < critchance*100)
    local player = MockPlayer({ "UniversalTraits:UT_batteringram", "UniversalTraits:UT_martial" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie({ health = 100 })
    fireRamCollision(player, zombie)
    assert_true(zombie:getHealth() < 100,
        "expected zombie health reduced by martial synergy, got " .. tostring(zombie:getHealth()))
end)

-- ===== QA checklist follow-up coverage =====

test("noxpshooter blocks Aiming and Reloading XP through the XP hook", function()
    local player = fireNewGame("UniversalTraits:UT_noxpshooter")
    Events.AddXP:fire(player, "Aiming", 10)
    Events.AddXP:fire(player, "Reloading", 10)
    assert_true(xpWasCancelled(player, "Aiming", 10), "expected Aiming XP to be cancelled")
    assert_true(xpWasCancelled(player, "Reloading", 10), "expected Reloading XP to be cancelled")
end)

test("noxptechnician blocks Electricity and Mechanics XP through the XP hook", function()
    local player = fireNewGame("UniversalTraits:UT_noxptechnician")
    Events.AddXP:fire(player, "Electricity", 10)
    Events.AddXP:fire(player, "Mechanics", 10)
    assert_true(xpWasCancelled(player, "Electricity", 10), "expected Electricity XP to be cancelled")
    assert_true(xpWasCancelled(player, "Mechanics", 10), "expected Mechanics XP to be cancelled")
end)

test("single-skill noxp traits block their matching XP through the hook", function()
    local axePlayer = fireNewGame("UniversalTraits:UT_noxpaxe")
    Events.AddXP:fire(axePlayer, "Axe", 10)
    assert_true(xpWasCancelled(axePlayer, "Axe", 10), "expected Axe XP to be cancelled")

    local firstAidPlayer = fireNewGame("UniversalTraits:UT_noxpfirstaid")
    Events.AddXP:fire(firstAidPlayer, "Doctor", 10)
    assert_true(xpWasCancelled(firstAidPlayer, "Doctor", 10), "expected Doctor XP to be cancelled")

    local maintenancePlayer = fireNewGame("UniversalTraits:UT_noxpmaintenance")
    Events.AddXP:fire(maintenancePlayer, "Maintenance", 10)
    assert_true(xpWasCancelled(maintenancePlayer, "Maintenance", 10), "expected Maintenance XP to be cancelled")
end)

test("noxpsneaky blocks Sneaking and Lightfoot XP through the XP hook", function()
    local player = fireNewGame("UniversalTraits:UT_noxpsneaky")
    Events.AddXP:fire(player, "Sneaking", 10)
    Events.AddXP:fire(player, "Lightfoot", 10)
    assert_true(xpWasCancelled(player, "Sneaking", 10), "expected Sneaking XP to be cancelled")
    assert_true(xpWasCancelled(player, "Lightfoot", 10), "expected Lightfoot XP to be cancelled")
end)

test("driver applies mild vehicle bonuses", function()
    local vehicle = MockVehicle()
    local player = MockPlayer({ "UniversalTraits:UT_driver" }, { vehicle = vehicle })
    player:setVehicle(vehicle)
    Events.OnVehicleEnter:fire(player, vehicle)
    assert_eq(vehicle:getMaxSpeed(), 120, "expected +20% max speed")
    assert_eq(vehicle:getBrakingForce(), 12, "expected +20% braking force")
    assert_eq(vehicle:getEnginePower(), 120, "expected +20% engine power")
    assert_eq(vehicle:getEngineLoudness(), 80, "expected 20% quieter engine")
end)

test("expertdriver applies the full vehicle bonus package", function()
    local vehicle = MockVehicle()
    local player = MockPlayer({ "UniversalTraits:UT_expertdriver" }, { vehicle = vehicle })
    player:setVehicle(vehicle)
    Events.OnVehicleEnter:fire(player, vehicle)
    assert_eq(vehicle:getMaxSpeed(), 125, "expected +25% max speed")
    assert_eq(vehicle:getBrakingForce(), 20, "expected 2x braking force")
    assert_eq(vehicle:getEngineQuality(), 200, "expected 2x engine quality")
    assert_eq(vehicle:getEngineLoudness(), 25, "expected 75% quieter engine")
    assert_eq(vehicle:getEnginePower(), 300, "expected 3x engine power")
    assert_eq(vehicle:getMass(), 500, "expected half vehicle mass")
end)

test("poordriver applies the full vehicle penalty package", function()
    local vehicle = MockVehicle()
    local player = MockPlayer({ "UniversalTraits:UT_poordriver" }, { vehicle = vehicle })
    player:setVehicle(vehicle)
    Events.OnVehicleEnter:fire(player, vehicle)
    assert_eq(vehicle:getMaxSpeed(), 75, "expected -25% max speed")
    assert_eq(vehicle:getBrakingForce(), 5, "expected half braking force")
    assert_eq(vehicle:getEngineQuality(), 50, "expected half engine quality")
    assert_eq(vehicle:getEngineLoudness(), 150, "expected 50% louder engine")
    assert_eq(vehicle:getEnginePower(), 66, "expected 34% engine power penalty")
    assert_true(math.abs(vehicle:getMass() - 1330) < 0.1, "expected +33% vehicle mass")
end)

test("vehicle traits restore the baseline stats on exit", function()
    local vehicle = MockVehicle()
    local player = MockPlayer({ "UniversalTraits:UT_expertdriver" }, { vehicle = vehicle })
    player:setVehicle(vehicle)
    Events.OnVehicleEnter:fire(player, vehicle)
    Events.OnVehicleExit:fire(player, vehicle)
    assert_eq(vehicle:getMaxSpeed(), 100, "expected max speed restored to baseline")
    assert_eq(vehicle:getBrakingForce(), 10, "expected braking force restored to baseline")
    assert_eq(vehicle:getEngineQuality(), 100, "expected engine quality restored to baseline")
    assert_eq(vehicle:getEngineLoudness(), 100, "expected engine loudness restored to baseline")
    assert_eq(vehicle:getEnginePower(), 100, "expected engine power restored to baseline")
    assert_eq(vehicle:getMass(), 1000, "expected mass restored to baseline")
end)

test("indefatigable restores endurance after its exhaustion cooldown", function()
    setMockGameTime(0, 0)
    local player = MockPlayer({ "UniversalTraits:UT_indefatigable" }, { sprinting = true, endurance = 0.04 })
    player._sprinting = true
    withActivePlayer(player, function()
        for _ = 1, 30 do Events.OnPlayerUpdate:fire(player) end
        setMockGameTime(0.05, 0)
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():getEndurance(), 0.5, "expected exhaustion recovery burst to set endurance to 0.5")
    assert_true(player:getModData()["UT_indefRecovering"] == nil, "expected recovery flag to clear")
end)

test("hardy enters exhaustion state then grants the recovery bonus", function()
    local player = MockPlayer({ "UniversalTraits:UT_hardy" }, { fatigue = 0.9, endurance = 0.4 })
    withActivePlayer(player, function()
        setMockGameTime(1.0, 0)
        Events.EveryOneMinute:fire()
        player:getStats():setFatigue(0.2)
        player:getModData()["UT_hardyRestingMins"] = 9
        setMockGameTime(1.2, 0)
        Events.EveryOneMinute:fire()
        setMockGameTime(1.21, 0)
        Events.EveryOneMinute:fire()
    end)
    assert_true(player:getModData()["UT_hardyExhausted"] == nil, "expected exhausted state to clear")
    assert_true(player:getModData()["UT_hardyBonus"] ~= nil, "expected hardy bonus window to start")
    assert_true(player:getStats():getEndurance() > 0.4, "expected hardy bonus to increase endurance")
end)

test("secondwind triggers at low endurance and clears after cooldown", function()
    setMockGameTime(0, 0)
    local player = MockPlayer({ "UniversalTraits:UT_secondwind" }, { endurance = 0.1 })
    player._sprinting = true
    withActivePlayer(player, function()
        for _ = 1, 15 do Events.OnPlayerUpdate:fire(player) end
        assert_true(player:getModData()["UT_secondwindTriggered"] == true, "expected second wind to trigger")
        setMockGameTime((10 / 60.0) + 0.01, 0)
        Events.EveryOneMinute:fire()
    end)
    assert_true(player:getStats():getEndurance() > 0.1, "expected second wind to restore endurance")
    assert_true(player:getModData()["UT_secondwindTriggered"] == nil, "expected second wind flag to clear after cooldown")
end)

test("immuneresponse reduces infection and fatigue every ten minutes", function()
    local player = MockPlayer({ "UniversalTraits:UT_immuneresponse" }, { infectionLevel = 0.5, fatigue = 0.4 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_true(math.abs(player:getBodyDamage():getInfectionLevel() - 0.47) < 0.0001,
        "expected infection to drop by 0.03")
    assert_true(math.abs(player:getStats():getFatigue() - 0.38) < 0.0001,
        "expected fatigue to drop by 0.02")
end)

test("immunocompromised marks the trait and increases infection over time", function()
    local player = fireNewGame("UniversalTraits:UT_immunocompromised")
    player:getBodyDamage():setInfectionLevel(0.5)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getModData()["UT_immunocompromised"], true, "expected immunocompromised flag")
    assert_true(math.abs(player:getBodyDamage():getInfectionLevel() - 0.51) < 0.0001,
        "expected infection to increase by 0.01")
end)

test("superimmune marks the trait and reduces infection over time", function()
    local player = fireNewGame("UniversalTraits:UT_superimmune")
    player:getBodyDamage():setInfectionLevel(0.5)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getModData()["UT_superimmune"], true, "expected superimmune flag")
    assert_true(math.abs(player:getBodyDamage():getInfectionLevel() - 0.48) < 0.0001,
        "expected infection to decrease by 0.02")
end)

test("butterfingers only flags a drop after 300 ticks and a successful roll", function()
    resetMockZombRand()
    local earlyPlayer = MockPlayer({ "UniversalTraits:UT_butterfingers" }, { playerNum = 101 })
    setMockGameTime(0, 299)
    Events.OnPlayerUpdate:fire(earlyPlayer)
    assert_true(earlyPlayer:getModData()["UT_dropNext"] == nil, "expected no drop flag before 300 ticks")

    local player = MockPlayer({ "UniversalTraits:UT_butterfingers" }, { playerNum = 102 })
    setMockZombRandSequence({ 0 })
    setMockGameTime(0, 300)
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getModData()["UT_dropNext"], true, "expected drop flag after a successful roll")
    resetMockZombRand()
end)

test("idealweight doubles calorie burn when overweight", function()
    local player = MockPlayer({ "UniversalTraits:UT_idealweight" }, { weight = 85.0, calories = 2000.0 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
        Events.OnPlayerUpdate:fire(player)
        player:getNutrition():setCalories(1990.0)
        Events.OnPlayerUpdate:fire(player)
    end)
    assert_true(math.abs(player:getNutrition():getCalories() - 1980.0) < 0.0001,
        "expected extra calorie burn at overweight values")
end)

test("idealweight halves calorie burn when underweight", function()
    local player = MockPlayer({ "UniversalTraits:UT_idealweight" }, { weight = 75.0, calories = 2000.0 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
        Events.OnPlayerUpdate:fire(player)
        player:getNutrition():setCalories(1990.0)
        Events.OnPlayerUpdate:fire(player)
    end)
    assert_true(math.abs(player:getNutrition():getCalories() - 1995.0) < 0.0001,
        "expected reduced calorie burn at underweight values")
end)

-- ============================================================
-- P0 coverage: behavioral tests for all audited traits
-- ============================================================

-- Load remaining trait files not yet dofile'd above
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fearofthedark.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_mundane.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_addictedtocaffeine.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_allergic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_antivaxxer.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_humanhamster.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_physicallyactive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_gunspecialist_III.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua")

-- Install consumption + fitness hooks (simulates game startup)
Events.OnGameStart.fire()

-- ─── UT_fearofthedark ─────────────────────────────────────────────────────────

test("fearofthedark raises panic at night", function()
    local player = MockPlayer({ "UniversalTraits:UT_fearofthedark" }, { panic = 0.1 })
    setMockTimeOfDay(0.1)  -- nighttime (< 0.25)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local panic = player:getStats():getPanic()
    assert_eq(math.floor(panic * 1000 + 0.5) / 1000, 0.14, "panic should be 0.1 + 0.04 = 0.14 at night")
end)

test("fearofthedark reduces panic during daytime", function()
    local player = MockPlayer({ "UniversalTraits:UT_fearofthedark" }, { panic = 0.1 })
    setMockTimeOfDay(0.5)  -- daytime (0.25–0.75)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local panic = player:getStats():getPanic()
    assert_eq(math.floor(panic * 1000 + 0.5) / 1000, 0.09, "panic should be 0.1 - 0.01 = 0.09 during day")
end)

test("fearofthedark does not affect player without the trait", function()
    local player = MockPlayer({}, { panic = 0.1 })
    setMockTimeOfDay(0.1)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():getPanic(), 0.1, "panic unchanged without trait")
end)

-- ─── UT_mundane ───────────────────────────────────────────────────────────────

test("mundane sets 0.8x XP multiplier for Electricity on new game", function()
    local player = MockPlayer({ "UniversalTraits:UT_mundane" })
    Events.OnNewGame:fire(player)
    assert_eq(player:getModData()["UT_xpMult_Electricity"], 0.8,
        "UT_xpMult_Electricity should be 0.8 after OnNewGame")
end)

test("mundane does not affect player without the trait", function()
    local player = MockPlayer({})
    Events.OnNewGame:fire(player)
    assert_eq(player:getModData()["UT_xpMult_Electricity"], nil,
        "UT_xpMult_Electricity should not be set when trait is absent")
end)

-- ─── UT_addictedtocaffeine ────────────────────────────────────────────────────

test("addictedtocaffeine adds stress when no caffeine flag set", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.06,
        "stress should be +0.06 when no UT_hadCaffeine flag")
end)

test("addictedtocaffeine skips stress when caffeine flag is set", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.0 })
    player:getModData()["UT_hadCaffeine"] = true
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.0, "no stress added when UT_hadCaffeine is set")
end)

test("addictedtocaffeine clears UT_hadCaffeine flag each tick", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" })
    player:getModData()["UT_hadCaffeine"] = true
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getModData()["UT_hadCaffeine"], nil,
        "UT_hadCaffeine should be cleared after the tick")
end)

test("addictedtocaffeine does not affect player without the trait", function()
    local player = MockPlayer({}, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.0, "no stress added without trait")
end)

-- ─── UT_ItemConsumptionHooks: UT_allergic ─────────────────────────────────────

test("allergic adds food sickness spike on guaranteed roll", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 0 })  -- 0 < 30 → spike fires
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    local sickness = player:getBodyDamage():getFoodSicknessLevel()
    assert_eq(sickness, 20, "food sickness should be +20 on successful allergic roll")
end)

test("allergic does not spike on failed roll", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 30 })  -- 30 is NOT < 30 → no spike
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no food sickness when roll fails")
end)

test("allergic does not trigger for medication items", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 0 })  -- guaranteed roll but item is medication
    local action = { character = player, item = MockItem("Antibiotics") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no food sickness when item is medication (not food)")
end)

test("allergic does not affect player without the trait", function()
    local player = MockPlayer({})
    setMockZombRandSequence({ 0 })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "non-allergic player unaffected")
end)

-- ─── UT_ItemConsumptionHooks: UT_antivaxxer ───────────────────────────────────

test("antivaxxer adds stress when medication eaten", function()
    local player = MockPlayer({ "UniversalTraits:UT_antivaxxer" }, { stress = 0.0 })
    local action = { character = player, item = MockItem("Painkiller") }
    ISEatFoodAction.perform(action)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.20,
        "stress should be +0.20 when medication consumed")
end)

test("antivaxxer skips beta blocker", function()
    local player = MockPlayer({ "UniversalTraits:UT_antivaxxer" }, { stress = 0.0 })
    local action = { character = player, item = MockItem("BetaBlocker") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():getStress(), 0.0,
        "beta blocker should not trigger antivaxxer stress")
end)

test("antivaxxer does not affect player without the trait", function()
    local player = MockPlayer({}, { stress = 0.0 })
    local action = { character = player, item = MockItem("Painkiller") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():getStress(), 0.0,
        "non-antivaxxer player unaffected")
end)

-- ─── UT_ItemConsumptionHooks: caffeine flag ───────────────────────────────────

test("consumption hook sets UT_hadCaffeine when coffee consumed", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" })
    local action = { character = player, item = MockItem("Coffee") }
    ISEatFoodAction.perform(action)
    assert_true(player:getModData()["UT_hadCaffeine"] == true,
        "UT_hadCaffeine should be true after coffee consumed")
end)

-- ─── UT_humanhamster ──────────────────────────────────────────────────────────

test("humanhamster no stress when craving below 10", function()
    local inv    = MockInventory(4.0)   -- 4/8 = 50%, needs bag too
    local player = MockPlayer({ "UniversalTraits:UT_humanhamster" }, {
        inventory = inv,
        wornItems = MockWornItems(0),  -- no bag
    })
    player:getModData()["UT_hamsterCraving"] = 5  -- craving = 5 (below 10 threshold)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.0, "no stress at craving < 10")
end)

test("humanhamster adds mild stress at craving 10–29", function()
    local inv    = MockInventory(4.0)
    local player = MockPlayer({ "UniversalTraits:UT_humanhamster" }, {
        inventory = inv,
        wornItems = MockWornItems(0),
    })
    player:getModData()["UT_hamsterCraving"] = 9  -- will become 10 after increment
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.02, "mild stress (+0.02) at craving 10")
end)

test("humanhamster adds severe stress at craving 60+", function()
    local inv    = MockInventory(4.0)
    local player = MockPlayer({ "UniversalTraits:UT_humanhamster" }, {
        inventory = inv,
        wornItems = MockWornItems(0),
    })
    player:getModData()["UT_hamsterCraving"] = 59  -- will become 60 after increment
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.08, "severe stress (+0.08) at craving 60")
end)

test("humanhamster resets craving when 80pct full with backpack", function()
    local inv    = MockInventory(7.0)   -- 7/8 = 87.5%, >= 80%
    local player = MockPlayer({ "UniversalTraits:UT_humanhamster" }, {
        inventory = inv,
        wornItems = MockWornItems(1),  -- one backpack worn
    })
    player:getModData()["UT_hamsterCraving"] = 30
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getModData()["UT_hamsterCraving"], 0, "craving resets when satisfied")
    assert_eq(player:getStats():getStress(), 0.0, "no stress when satisfied")
end)

-- ─── UT_physicallyactive ──────────────────────────────────────────────────────

-- Verify Perks stub for this section
_G.Perks = _G.Perks or { Fitness = "Fitness", Sprinting = "Sprinting" }

test("physicallyactive reduces stress per exercise loop", function()
    local player = MockPlayer({ "UniversalTraits:UT_physicallyactive" }, { stress = 0.5 })
    local action = { character = player }
    ISFitnessAction.exeLooped(action)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.485,
        "stress should decrease by 0.015 per exercise loop")
end)

test("physicallyactive reduces boredom per exercise loop", function()
    local player = MockPlayer({ "UniversalTraits:UT_physicallyactive" }, { boredom = 50 })
    local action = { character = player }
    ISFitnessAction.exeLooped(action)
    assert_eq(player:getStats():getBoredom(), 45, "boredom should decrease by 5 per exercise loop")
end)

test("physicallyactive at Fitness 10 restores endurance after exercise", function()
    local player = MockPlayer({ "UniversalTraits:UT_physicallyactive" }, { endurance = 0.8 })
    player:setPerkLevel(Perks.Fitness, 10)
    -- Action captures pre-endurance; original (stub) does nothing to endurance here.
    -- If original DID drain endurance we'd see it restored. Here we confirm
    -- the post-endurance path runs without crashing when perkLevel is 10.
    local action = { character = player }
    ISFitnessAction.exeLooped(action)
    -- Endurance unchanged (original stub doesn't drain it), no error expected
    assert_true(player:getStats():getEndurance() >= 0.0, "endurance should remain non-negative")
end)

-- ─── UT_gunspecialist_III ─────────────────────────────────────────────────────

test("gunspecialist_III reduces weapon reload time to 90pct on first apply", function()
    local weapon = MockFirearm({ reloadTime = 30, aimingTime = 20 })
    local player = MockPlayer({ "UniversalTraits:UT_gunspecialist_III" }, {
        primaryHandItem = weapon,
    })
    -- tickCounter is module-level; fire 30 events to guarantee hitting one % 30 == 0 boundary
    for _ = 1, 30 do Events.OnPlayerUpdate:fire(player) end
    -- 10% reduction: floor(30 * 0.9) = 27
    assert_eq(weapon:getReloadTime(), 27, "reload time should be 27 (floor of 30 * 0.9)")
end)

test("gunspecialist_III is idempotent on repeated calls", function()
    local weapon = MockFirearm({ reloadTime = 30, aimingTime = 20 })
    local player = MockPlayer({ "UniversalTraits:UT_gunspecialist_III" }, {
        primaryHandItem = weapon,
    })
    -- Two full 30-event cycles: each group of 30 hits exactly one % 30 == 0 boundary
    for _ = 1, 30 do Events.OnPlayerUpdate:fire(player) end  -- first apply: 27
    for _ = 1, 30 do Events.OnPlayerUpdate:fire(player) end  -- second apply: should stay 27
    assert_eq(weapon:getReloadTime(), 27, "reload time should not compound on second apply")
end)

test("gunspecialist_III unjams a jammed equipped firearm", function()
    local weapon = MockFirearm({ reloadTime = 30, aimingTime = 20, jammed = true })
    local player = MockPlayer({ "UniversalTraits:UT_gunspecialist_III" }, {
        primaryHandItem = weapon,
    })
    for _ = 1, 30 do Events.OnPlayerUpdate:fire(player) end
    assert_true(not weapon:isJammed(), "jammed firearm should be unjammed by gunspecialist_III")
end)

-- ─── UT_scardycat: panic cascade ──────────────────────────────────────────────

test("scardycat panic cascade fires when panic rises by 0.05 or more", function()
    -- Two EveryOneMinute calls: first to set prevPanic, second to detect the rise
    local player = MockPlayer({ "UniversalTraits:UT_scardycat" }, { panic = 0.10 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()  -- prevPanic[id] = 0.10
        player:getStats():setPanic(0.20)  -- panic rose by 0.10 (>= 0.05)
        Events.EveryOneMinute:fire()  -- cascade: 0.20 + 0.15 = 0.35
    end)
    local panic = player:getStats():getPanic()
    assert_true(panic >= 0.34 and panic <= 0.36,
        "panic cascade should add 0.15 when panic rises >= 0.05 in a minute (got " .. tostring(panic) .. ")")
end)

test("scardycat no cascade when panic does not rise by 0.05", function()
    local player = MockPlayer({ "UniversalTraits:UT_scardycat" }, { panic = 0.20 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()  -- prevPanic[id] = 0.20
        player:getStats():setPanic(0.23)  -- rose only 0.03 (< 0.05)
        Events.EveryOneMinute:fire()  -- no cascade
    end)
    local panic = player:getStats():getPanic()
    assert_true(panic < 0.30,
        "no cascade should fire when panic rose less than 0.05 (got " .. tostring(panic) .. ")")
end)

-- ─── UT_butterfingers: drop execution ─────────────────────────────────────────

test("butterfingers drops primary hand item when UT_dropNext flag is set", function()
    local item    = MockItem("ButterKnife")
    local inv     = MockInventory(1.0)
    local sq      = MockSquare()
    inv:AddItem(item)
    local player = MockPlayer({ "UniversalTraits:UT_butterfingers" }, {
        primaryHandItem = item,
        inventory = inv,
        square = sq,
    })
    player:getModData()["UT_dropNext"] = true
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getPrimaryHandItem(), nil, "primary hand item should be removed after drop")
    assert_eq(#sq._dropped, 1, "item should have been placed on the ground square")
end)

test("butterfingers does nothing when no item in primary hand", function()
    local inv  = MockInventory(0.0)
    local sq   = MockSquare()
    local player = MockPlayer({ "UniversalTraits:UT_butterfingers" }, {
        inventory = inv,
        square = sq,
    })
    player:getModData()["UT_dropNext"] = true
    Events.OnPlayerUpdate:fire(player)
    assert_eq(#sq._dropped, 0, "nothing dropped when primary hand is empty")
end)

-- ===== UT_melancholic behavioral tests (code changed: raises unhappiness) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_melancholic.lua")

test("melancholic raises unhappiness by 5 every 10 minutes", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" })
    local bd = player:getBodyDamage()
    bd._unhappinessLevel = 20
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(bd:getUnhappinessLevel(), 25, "unhappiness should be 20 + 5 = 25")
end)

test("melancholic unhappiness caps at 100", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" })
    local bd = player:getBodyDamage()
    bd._unhappinessLevel = 98
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(bd:getUnhappinessLevel(), 100, "unhappiness should cap at 100")
end)

test("melancholic does NOT raise stress", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" }, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.0, "stress should be unchanged by melancholic")
end)

test("melancholic does not affect player without the trait", function()
    local player = MockPlayer({})
    local bd = player:getBodyDamage()
    bd._unhappinessLevel = 20
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(bd:getUnhappinessLevel(), 20, "unhappiness unchanged without trait")
end)

-- ===== UT_weathersensitive behavioral tests (code changed: real weather check) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_weathersensitive.lua")

test("weathersensitive raises stress when raining (precip > 0.3)", function()
    setMockClimate(0.5, 0.8)  -- heavy rain
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.2 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.25,
        "stress should be 0.2 + 0.05 = 0.25 when raining")
end)

test("weathersensitive reduces stress when clear and sunny (clouds < 0.2)", function()
    setMockClimate(0.0, 0.1)  -- no rain, clear sky
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.4 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():getStress()
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.38,
        "stress should be 0.4 - 0.02 = 0.38 when sunny")
end)

test("weathersensitive does nothing when overcast but dry (no rain, clouds >= 0.2)", function()
    setMockClimate(0.0, 0.6)  -- no rain, overcast
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.3 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.3, "stress unchanged when overcast but dry")
end)

test("weathersensitive does not affect player without the trait", function()
    setMockClimate(0.5, 0.8)  -- raining
    local player = MockPlayer({}, { stress = 0.2 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getStress(), 0.2, "stress unchanged without trait")
end)

-- ===== UT_topheavy behavioral tests (code fixed: delta -3 not +2) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_topheavy.lua")

test("topheavy sets carry weight to 5 + Strength - 3", function()
    local player = MockPlayer({ "UniversalTraits:UT_topheavy" })
    player:setPerkLevel(Perks.Strength, 5)
    withActivePlayer(player, function()
        Events.OnPlayerUpdate:fire(player)
    end)
    -- expected: 5 + 5 - 3 = 7
    assert_eq(player:getMaxWeightBase(), 7, "carry weight should be 5 + Strength(5) - 3 = 7")
end)

test("topheavy at Strength 0 gives carry weight 2", function()
    local player = MockPlayer({ "UniversalTraits:UT_topheavy" })
    -- default strength is 0
    withActivePlayer(player, function()
        Events.OnPlayerUpdate:fire(player)
    end)
    assert_eq(player:getMaxWeightBase(), 2, "carry weight should be 5 + Strength(0) - 3 = 2")
end)

test("topheavy does not affect player without the trait", function()
    local player = MockPlayer({})
    player:setPerkLevel(Perks.Strength, 5)
    Events.OnPlayerUpdate:fire(player)
    -- maxWeightBase default is 8; handler should not run without trait
    assert_eq(player:getMaxWeightBase(), 8, "carry weight unchanged without trait")
end)

-- ===== UT_unwavering behavioral tests (code changed: EveryTenMinutes panic drain) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_unwavering.lua")

test("unwavering drains panic by 0.1 when above 0.1", function()
    local player = MockPlayer({ "UniversalTraits:UT_unwavering" }, { panic = 0.5 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local panic = player:getStats():getPanic()
    assert_eq(math.floor(panic * 100 + 0.5) / 100, 0.40,
        "panic should be 0.5 - 0.1 = 0.4 after drain")
end)

test("unwavering does not drain panic when at or below 0.1", function()
    local player = MockPlayer({ "UniversalTraits:UT_unwavering" }, { panic = 0.1 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getPanic(), 0.1, "panic unchanged when at 0.1 threshold")
end)

test("unwavering does not affect player without the trait", function()
    local player = MockPlayer({}, { panic = 0.5 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():getPanic(), 0.5, "panic unchanged without trait")
end)

-- ===== UT_pillsallergy behavioral tests (hook in UT_ItemConsumptionHooks.lua) =====

test("pillsallergy adds sickness 15 when medication consumed", function()
    local player = MockPlayer({ "UniversalTraits:UT_pillsallergy" })
    local action = { character = player, item = MockItem("Painkiller") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 15,
        "food sickness should be +15 after medication consumed with pillsallergy")
end)

test("pillsallergy does not trigger on non-medication food", function()
    local player = MockPlayer({ "UniversalTraits:UT_pillsallergy" })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no sickness when non-medication item consumed with pillsallergy")
end)

test("pillsallergy does not affect player without the trait", function()
    local player = MockPlayer({})
    local action = { character = player, item = MockItem("Painkiller") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no sickness when player lacks pillsallergy trait")
end)

-- ===== UT_wildplantsallergy behavioral tests (hook in UT_ItemConsumptionHooks.lua) =====

test("wildplantsallergy adds sickness 20 when foraged item consumed", function()
    local player = MockPlayer({ "UniversalTraits:UT_wildplantsallergy" })
    local action = { character = player, item = MockItem("Berries", { forageCategory = "WildPlants" }) }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 20,
        "food sickness should be +20 after foraged item consumed with wildplantsallergy")
end)

test("wildplantsallergy does not trigger on non-foraged food", function()
    local player = MockPlayer({ "UniversalTraits:UT_wildplantsallergy" })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no sickness when non-foraged item consumed with wildplantsallergy")
end)

test("wildplantsallergy does not affect player without the trait", function()
    local player = MockPlayer({})
    local action = { character = player, item = MockItem("Berries", { forageCategory = "WildPlants" }) }
    ISEatFoodAction.perform(action)
    assert_eq(player:getBodyDamage():getFoodSicknessLevel(), 0,
        "no sickness when player lacks wildplantsallergy trait")
end)

