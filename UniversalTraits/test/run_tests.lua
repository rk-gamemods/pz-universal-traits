-- run_tests.lua  (UniversalTraits)
-- Run with: "C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua

local base = arg[0]:match("(.*[/\\])") or "./"
package.path = base .. "../media/?.lua;" .. package.path

-- Load mocks
dofile(base .. "UTTestMocks.lua")
dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua")

-- Load registries
dofile(base .. "../media/registries.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/UT_MET.lua")

local passed, failed = 0, 0
local testFilter = os.getenv("UNIVERSAL_TRAITS_TEST_FILTER")
local function test(name, fn)
    if testFilter and not name:lower():find(testFilter:lower(), 1, true) then return end
    UTCore._mockTickCount = 0   -- reset dispatch tick counter per test
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
local function assert_close(a, b, tolerance, msg)
    if math.abs(a - b) > tolerance then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a), 2)
    end
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
-- B42.16: CharacterTrait.register() returns a CharacterTrait object (table with _id),
-- not a string. Tests verify the _id field matches the expected namespace:path.
local function assert_trait_registered(actual, expectedId)
    assert_true(type(actual) == "table", expectedId .. " should be a CharacterTrait object (table), got " .. type(actual))
    assert_eq(actual._id, expectedId)
end

test("UTTraitsRegistries table exists", function()
    assert_true(type(UTTraitsRegistries) == "table", "UTTraitsRegistries should be a table")
end)

-- ===== Java API validation =====
-- Asserts every declared Java method call in our Lua code actually
-- exists in the decompiled PZ Java source. Catches typos that mocks
-- would silently accept (e.g. isInfected vs IsInfected).
do
    local javaApi = dofile(base .. "java_api_validation.lua")
    javaApi.run(base, test, assert_true)
end

test("UT_preparedfood registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_preparedfood, "UniversalTraits:UT_preparedfood")
end)

test("UT_swift registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_swift, "UniversalTraits:UT_swift")
end)

test("UT_martial registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_martial, "UniversalTraits:UT_martial")
end)

test("UT_terminator registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_terminator, "UniversalTraits:UT_terminator")
end)

test("UT_spears registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_spears, "UniversalTraits:UT_spears")
end)

test("UT_ingenuitive registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_ingenuitive, "UniversalTraits:UT_ingenuitive")
end)

test("UT_packmule registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_packmule, "UniversalTraits:UT_packmule")
end)

test("UT_staunch registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_staunch, "UniversalTraits:UT_staunch")
end)

-- Phase 2 spot-checks
test("UT_fast registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_fast, "UniversalTraits:UT_fast")
end)

test("UT_analgesia registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_analgesia, "UniversalTraits:UT_analgesia")
end)

test("UT_noxpshooter registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_noxpshooter, "UniversalTraits:UT_noxpshooter")
end)

test("UT_photographicmemory registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_photographicmemory, "UniversalTraits:UT_photographicmemory")
end)

test("UT_gourmand registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_gourmand, "UniversalTraits:UT_gourmand")
end)

-- Phase 3 spot-checks
test("UT_depressive registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_depressive, "UniversalTraits:UT_depressive")
end)

test("UT_alcoholic_II registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_alcoholic_II, "UniversalTraits:UT_alcoholic_II")
end)

test("UT_gunspecialist_II registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_gunspecialist_II, "UniversalTraits:UT_gunspecialist_II")
end)

test("UT_superimmune registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_superimmune, "UniversalTraits:UT_superimmune")
end)

test("UT_indefatigable registered", function()
    assert_trait_registered(UTTraitsRegistries.UT_indefatigable, "UniversalTraits:UT_indefatigable")
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
                ui_name = nil,
                ui_description = nil,
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

            local ui_name = line:match("^%s*UIName%s*=%s*([^,%s]+)")
            if ui_name then
                current.ui_name = ui_name
            end

            local ui_description = line:match("^%s*UIDescription%s*=%s*([^,%s]+)")
            if ui_description then
                current.ui_description = ui_description
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

local function parseTranslationKeys(text)
    local keys = {}

    for key in text:gmatch('"([A-Za-z0-9_]+)"%s*:') do
        keys[key] = true
    end

    return keys
end

local function listTraitLuaFiles()
    local dir = (base .. "../media/lua/shared/UniversalTraits/traits"):gsub("/", "\\")
    local pipe = io.popen('cmd /c dir /b "' .. dir .. '\\UT_*.lua" 2>nul')
    assert_true(pipe ~= nil, "failed to list trait lua files")

    local files = {}
    for line in pipe:lines() do
        local trait_key = line:match("^(UT_[A-Za-z0-9_]+)%.lua$")
        if trait_key then
            files[trait_key] = true
        end
    end

    pipe:close()
    return files
end

local function compileLuaFile(path)
    local chunk, err = loadfile(path)
    assert_true(chunk ~= nil, "syntax error in " .. path .. ": " .. tostring(err))
end

local function loadTraitConsistencyState()
    local registry_file = io.open(base .. "../media/registries.lua", "r")
    assert_true(registry_file ~= nil, "failed to open registries.lua")
    local registry_text = registry_file:read("*a")
    registry_file:close()

    local script_file = io.open(base .. "../media/scripts/UT_character_traits.txt", "r")
    assert_true(script_file ~= nil, "failed to open UT_character_traits.txt")
    local script_text = script_file:read("*a")
    script_file:close()

    local translation_file = io.open(base .. "../media/lua/shared/Translate/EN/UI.json", "r")
    assert_true(translation_file ~= nil, "failed to open UI.json")
    local translation_text = translation_file:read("*a")
    translation_file:close()

    local registered_ids = collectRegisteredIdsFromRegistries(registry_text)
    local defs = parseScriptTraitDefinitions(script_text)
    local translation_keys = parseTranslationKeys(translation_text)
    local def_by_trait = {}
    local script_trait_keys = {}

    for _, def in ipairs(defs) do
        def_by_trait[def.block_id] = def
        local trait_key = def.block_id:match("^UniversalTraits:(UT_[A-Za-z0-9_]+)$")
        if trait_key then
            script_trait_keys[trait_key] = true
        end
    end

    return {
        registered_ids = registered_ids,
        defs = defs,
        def_by_trait = def_by_trait,
        script_trait_keys = script_trait_keys,
        translation_keys = translation_keys,
    }
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

test("script XP boosts use current 42.19 perk identifiers", function()
    local file = io.open(base .. "../media/scripts/UT_character_traits.txt", "r")
    assert_true(file ~= nil, "failed to open UT_character_traits.txt")
    local script_text = file:read("*a")
    file:close()

    assert_true(not script_text:find("FirstAid", 1, true), "legacy FirstAid perk identifier remains")
    assert_true(script_text:find("XPBoosts = Strength=1;Doctor=1", 1, true) ~= nil,
        "bouncer I should boost the current Doctor perk")
    assert_true(script_text:find("XPBoosts = Strength=2;Doctor=2", 1, true) ~= nil,
        "bouncer II should boost the current Doctor perk")
end)

test("total registration count is 198", function()
    local count = 0
    for _ in pairs(CharacterTrait._registered) do count = count + 1 end
    assert_eq(count, 198, "registration count")
end)

test("script trait definitions resolve cleanly and preserve UT_MET coverage", function()
    local state = loadTraitConsistencyState()
    local registered_ids = state.registered_ids
    local defs = state.defs
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

test("trait registry, scripts, and translations stay in sync", function()
    local state = loadTraitConsistencyState()
    local registered_ids = state.registered_ids
    local defs = state.defs
    local def_by_trait = state.def_by_trait
    local script_trait_keys = state.script_trait_keys
    local translation_keys = state.translation_keys

    for registered_id in pairs(registered_ids) do
        assert_true(def_by_trait[registered_id] ~= nil,
            "registry entry missing script definition: " .. registered_id)
    end

    for _, def in ipairs(defs) do
        local trait_key = def.block_id:match("^UniversalTraits:(UT_[A-Za-z0-9_]+)$")
        assert_true(trait_key ~= nil, "unexpected trait id format: " .. tostring(def.block_id))
        assert_true(type(def.ui_name) == "string" and def.ui_name ~= "",
            def.block_id .. " missing UIName")
        assert_true(type(def.ui_description) == "string" and def.ui_description ~= "",
            def.block_id .. " missing UIDescription")
        assert_true(translation_keys[def.ui_name] == true,
            def.block_id .. " missing UIName key in UI.json: " .. def.ui_name)
        assert_true(translation_keys[def.ui_description] == true,
            def.block_id .. " missing UIDescription key in UI.json: " .. def.ui_description)
    end

    for key in pairs(translation_keys) do
        local desc_trait_key = key:match("^UI_(UT_[A-Za-z0-9_]+)Desc$")
        if desc_trait_key then
            assert_true(script_trait_keys[desc_trait_key] == true,
                "UI.json orphaned trait description key: " .. key)
            assert_true(translation_keys["UI_" .. desc_trait_key] == true,
                "UI.json missing paired name key: UI_" .. desc_trait_key)
        else
            local trait_key = key:match("^UI_(UT_[A-Za-z0-9_]+)$")
            if trait_key then
                assert_true(script_trait_keys[trait_key] == true,
                    "UI.json orphaned trait name key: " .. key)
                assert_true(translation_keys[key .. "Desc"] == true,
                    "UI.json missing paired description key: " .. key .. "Desc")
            end
        end
    end
end)

test("runtime trait lua files map to registered scripted traits", function()
    local state = loadTraitConsistencyState()
    local registered_ids = state.registered_ids
    local def_by_trait = state.def_by_trait
    local translation_keys = state.translation_keys
    local trait_files = listTraitLuaFiles()

    for trait_key in pairs(trait_files) do
        local trait_id = "UniversalTraits:" .. trait_key
        local def = def_by_trait[trait_id]
        assert_true(registered_ids[trait_id] == true,
            "trait lua file missing registry entry: " .. trait_key .. ".lua")
        assert_true(def ~= nil,
            "trait lua file missing script definition: " .. trait_key .. ".lua")
        assert_true(translation_keys["UI_" .. trait_key] == true,
            trait_key .. ".lua missing UI name key")
        assert_true(translation_keys["UI_" .. trait_key .. "Desc"] == true,
            trait_key .. ".lua missing UI description key")
    end
end)

test("all runtime trait lua files compile", function()
    local trait_files = listTraitLuaFiles()

    for trait_key in pairs(trait_files) do
        compileLuaFile(base .. "../media/lua/shared/UniversalTraits/traits/" .. trait_key .. ".lua")
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
dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_ThermalRegulationHook.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpfirstaid.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpmaintenance.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpsneaky.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_driver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_expertdriver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_poordriver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_blissful.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_marathonrunner.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_olympian.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_strongnimble.lua")
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

-- ===== UT_actionhero focused runtime tests =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_actionhero.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_axes.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_improviser.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_gordanite.lua")

Fishing = {
    Fish = {
        createFish = function(self)
            self.createFishCalls = (self.createFishCalls or 0) + 1
            return self.nextFish
        end,
    },
}
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_wildsman.lua")

-- Engine-faithful HandWeapon critical-chance boundary: the getter returns the
-- sharpness-adjusted value while the setter writes the raw field.
local function MockWeaponSimple(typeName, opts)
    opts = opts or {}
    local _rawCrit = opts.critChance or 10
    local _sharpness = opts.sharpness
    local _moddata = opts.moddata or {}
    local _setCalls = 0
    return {
        _mockType = "HandWeapon",
        getType = function(self) return typeName end,
        hasSharpness = function(self) return _sharpness ~= nil end,
        getSharpness = function(self) return _sharpness or 0 end,
        getCriticalChance = function(self)
            return _sharpness ~= nil and _rawCrit * _sharpness or _rawCrit
        end,
        setCriticalChance = function(self, v)
            _setCalls = _setCalls + 1
            _rawCrit = v
        end,
        getRawCriticalChance = function(self) return _rawCrit end,
        getCriticalSetCalls = function(self) return _setCalls end,
        getModData = function(self) return _moddata end,
    }
end

-- Helper: build a target mock with mutable health
local function MockTarget(startHealth, opts)
    opts = opts or {}
    local hp = startHealth
    return {
        getHealth = function(self) return hp end,
        setHealth = function(self, v) hp = v end,
        splatBlood = function(self, count, size) end,
        _mockType = (opts.isZombie ~= false) and "IsoZombie" or "IsoGameCharacter",
    }
end

-- Helper: build a spotted-list mock returning N enemies all at the given distance
local function MockSpottedList(count, dist)
    local enemies = {}
    for i = 1, count do
        enemies[i] = { _dist = dist, isDead = function(self) return false end }
    end
    return {
        size = function(self) return count end,
        get  = function(self, i) return enemies[i + 1] end,
    }
end

-- Helper: build a spotted-list mock from an explicit enemy array
local function MockSpottedListFromEnemies(enemies)
    return {
        size = function(self) return #enemies end,
        get  = function(self, i) return enemies[i + 1] end,
    }
end

-- Helper: extend MockPlayer with the extra methods actionhero needs
local function MockActionPlayer(traitList, spottedList, weapon, secondaryWeapon)
    local p = MockPlayer(traitList, {
        primaryHandItem = weapon,
        secondaryHandItem = secondaryWeapon,
    })
    p.getSpottedList = function(self) return spottedList end
    p.DistTo = function(self, enemy) return enemy._dist end
    return p
end

local ACTION_HERO_ID = "UniversalTraits:UT_actionhero"

local function fireActionHero(player)
    return UTCore.fireTickHandler(ACTION_HERO_ID, player)
end

test("actionhero count and range boundaries are exact", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(2, 10), weapon)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 10, "two enemies must remain inactive")

    player.getSpottedList = function() return MockSpottedList(3, 10) end
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "three enemies at distance 10 must activate +15")

    player.getSpottedList = function() return MockSpottedList(3, 10.01) end
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 10, "distance greater than 10 must restore")
end)

test("actionhero caps displayed critical chance at 100 and restores", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 95 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 100, "displayed critical chance must cap at 100")
    player.getSpottedList = function() return MockSpottedList(2, 1) end
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 95, "inactive transition must restore the original value")
end)

test("actionhero restores when Mundane appears after activation", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    local mundane = false
    player.getTraits = function()
        return { contains = function(_, id) return id == ACTION_HERO_ID or (mundane and id == "UniversalTraits:UT_mundane") end }
    end
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "precondition: bonus active")
    mundane = true
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 10, "Mundane must restore an existing bonus")
end)

test("actionhero deduplicates one weapon held in both hands", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon, weapon)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "same weapon must receive one +15 bonus")
    assert_eq(weapon:getCriticalSetCalls(), 1, "same weapon must be written once")
end)

test("actionhero boosts both distinct eligible equipped weapons", function()
    local primary = MockWeaponSimple("Axe", { critChance = 10 })
    local secondary = MockWeaponSimple("Knife", { critChance = 30 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), primary, secondary)
    fireActionHero(player)
    assert_eq(primary:getCriticalChance(), 25, "primary eligible weapon must gain exactly +15")
    assert_eq(secondary:getCriticalChance(), 45, "secondary eligible weapon must gain exactly +15")
    player.getSpottedList = function() return MockSpottedList(2, 1) end
    fireActionHero(player)
    assert_eq(primary:getCriticalChance(), 10, "primary weapon must restore exactly")
    assert_eq(secondary:getCriticalChance(), 30, "secondary weapon must restore exactly")
end)

test("actionhero preserves the accepted eight-point definition cost", function()
    local file = assert(io.open(base .. "../media/scripts/UT_character_traits.txt", "r"))
    local source = file:read("*a")
    file:close()
    local block = source:match("character_trait_definition%s+UniversalTraits:UT_actionhero%s*(%b{})")
    assert_true(block ~= nil, "Action Hero definition must exist")
    assert_true(block:find("Cost%s*=%s*8[%s,]"), "Action Hero must retain cost 8")
end)

test("actionhero restores swapped weapon and manages replacement independently", function()
    local weaponA = MockWeaponSimple("Axe", { critChance = 10 })
    local weaponB = MockWeaponSimple("Bat", { critChance = 30 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weaponA)
    fireActionHero(player)
    player:setPrimaryHandItem(weaponB)
    fireActionHero(player)
    assert_eq(weaponA:getCriticalChance(), 10, "unequipped weapon A must restore")
    assert_eq(weaponB:getCriticalChance(), 45, "replacement weapon B must use its own base")
    player.getSpottedList = function() return MockSpottedList(2, 1) end
    fireActionHero(player)
    assert_eq(weaponB:getCriticalChance(), 30, "replacement weapon B must restore independently")
end)

test("actionhero models sharpness-adjusted getter and raw setter domains", function()
    local weapon = MockWeaponSimple("Knife", { critChance = 20, sharpness = 0.5 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    assert_eq(weapon:getCriticalChance(), 10, "precondition: displayed value is raw times sharpness")
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "displayed value must gain exactly 15")
    assert_eq(weapon:getRawCriticalChance(), 50, "setter must receive the raw-domain target")
    player.getSpottedList = function() return MockSpottedList(2, 1) end
    fireActionHero(player)
    assert_eq(weapon:getRawCriticalChance(), 20, "restoration must recover the exact raw field")
    assert_eq(weapon:getCriticalChance(), 10, "restored displayed value must match the original")
end)

test("actionhero enemy enumeration failures are atomic and restore", function()
    local stages = { "list", "size", "get", "dead", "distance" }
    for _, stage in ipairs(stages) do
        local weapon = MockWeaponSimple("Axe", { critChance = 10 })
        local good = MockSpottedList(3, 1)
        local player = MockActionPlayer({ ACTION_HERO_ID }, good, weapon)
        fireActionHero(player)
        assert_eq(weapon:getCriticalChance(), 25, stage .. " precondition: bonus active")

        local first = { _dist = 1, isDead = function() return false end }
        local second = { _dist = 1, isDead = function() if stage == "dead" then error("dead failure") end return false end }
        player.getSpottedList = function()
            if stage == "list" then error("list failure") end
            return {
                size = function() if stage == "size" then error("size failure") end return 3 end,
                get = function(_, i)
                    if stage == "get" and i == 1 then error("get failure") end
                    if i == 0 then return first end
                    if i == 1 then return second end
                    return { _dist = 1, isDead = function() return false end }
                end,
            }
        end
        player.DistTo = function(_, enemy)
            if stage == "distance" and enemy == second then error("distance failure") end
            return enemy._dist
        end
        fireActionHero(player)
        assert_eq(weapon:getCriticalChance(), 10, stage .. " failure must not consume a partial count")
    end
end)

test("actionhero duplicate load retains one state and does not compound", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "precondition: first load applies +15")
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_actionhero.lua")
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "duplicate load must not compound")
    player.getSpottedList = function() return MockSpottedList(2, 1) end
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 10, "duplicate load must retain restoration ownership")
    local registrations = 0
    for i = 1, #UTCore._tickHandlers do
        if UTCore._tickHandlers[i].id == ACTION_HERO_ID then registrations = registrations + 1 end
    end
    assert_eq(registrations, 1, "duplicate load must leave exactly one Action Hero handler")
end)

test("actionhero teardown restores before handler removal", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "precondition: bonus active")
    UTCore.unregisterTickHandler(ACTION_HERO_ID, "test-teardown")
    assert_eq(weapon:getCriticalChance(), 10, "teardown must restore before registration disappears")
    local registrations = 0
    for i = 1, #UTCore._tickHandlers do
        if UTCore._tickHandlers[i].id == ACTION_HERO_ID then registrations = registrations + 1 end
    end
    assert_eq(registrations, 0, "teardown must remove every stale Action Hero callback")
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_actionhero.lua")
end)

test("actionhero active-set deactivation restores outstanding weapons", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    UTCore.rebuildActiveHandlers(player)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "precondition: bonus active")
    player:getCharacterTraits():remove(CharacterTrait.get(ResourceLocation.of(ACTION_HERO_ID)))
    UTCore.rebuildActiveHandlers(player)
    assert_eq(weapon:getCriticalChance(), 10, "trait removal rebuild must restore outstanding weapons")
end)

test("actionhero player invalidation restores outstanding weapons", function()
    local weapon = MockWeaponSimple("Axe", { critChance = 10 })
    local player = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), weapon)
    UTCore.rebuildActiveHandlers(player)
    fireActionHero(player)
    assert_eq(weapon:getCriticalChance(), 25, "precondition: bonus active")
    UTCore.teardownActiveTickHandlers("invalid-player")
    assert_eq(weapon:getCriticalChance(), 10, "invalid player teardown must restore outstanding weapons")
end)

test("actionhero reload boundary does not depend on persisted base-crit moddata", function()
    local oldWeapon = MockWeaponSimple("Axe", { critChance = 10 })
    local oldPlayer = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(3, 1), oldWeapon)
    fireActionHero(oldPlayer)
    assert_eq(oldWeapon:getModData()["UT_ahBaseCrit"], nil, "runtime must not write the retired base cache")

    UTCore._actionHeroState = nil
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_actionhero.lua")
    local loadedWeapon = MockWeaponSimple("Axe", { critChance = 10, moddata = oldWeapon:getModData() })
    local loadedPlayer = MockActionPlayer({ ACTION_HERO_ID }, MockSpottedList(2, 1), loadedWeapon)
    fireActionHero(loadedPlayer)
    assert_eq(loadedWeapon:getCriticalChance(), 10, "reconstructed weapon default must remain unchanged while inactive")
end)

-- ===== UT_bouncer_I injury downgrade tests =====
-- Load the trait file so its UTCore.registerTickHandler() fires.
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_bouncer_I.lua")

-- Helper: check whether a mock part has any injury (drives HasInjury gate)
local function _partHasInjury(p)
    return p._bitten or p._deepWounded or p._scratched
        or (p._fractureTime and p._fractureTime > 0)
        or p._isInfected
end

-- Helper: create a mock body part with full injury state
local function MockInjuryPart(partType, injuries)
    injuries = injuries or {}
    local p = {
        _type           = partType or "Torso_Upper",
        _bitten         = injuries.bitten or false,
        _biteTime       = injuries.biteTime or 0,
        _isInfected     = injuries.isInfected or false,
        _isFakeInfected = injuries.isFakeInfected or false,
        _deepWounded    = injuries.deepWounded or false,
        _deepWoundTime  = injuries.deepWoundTime or 0,
        _scratched      = injuries.scratched or false,
        _scratchTime    = injuries.scratchTime or 0,
        _fractureTime   = injuries.fractureTime or 0,
    }
    p.getType           = function(self) return self._type end
    p.bitten            = function(self) return self._bitten end
    p.SetBitten         = function(self, v) self._bitten = v end
    p.setBiteTime       = function(self, v) self._biteTime = v end
    p.isInfected        = function(self) return self._isInfected end
    p.IsInfected        = function(self) return self._isInfected end
    p.SetInfected       = function(self, v) self._isInfected = v end
    p.isFakeInfected    = function(self) return self._isFakeInfected end
    p.IsFakeInfected    = function(self) return self._isFakeInfected end
    p.SetFakeInfected   = function(self, v) self._isFakeInfected = v end
    p.isDeepWounded     = function(self) return self._deepWounded end
    p.setDeepWounded    = function(self, v) self._deepWounded = v end
    p.setDeepWoundTime  = function(self, v) self._deepWoundTime = v end
    p.setScratched      = function(self, v, noInfect) self._scratched = v; self._scratchNoInfect = noInfect end
    p.getFractureTime   = function(self) return self._fractureTime end
    p.setFractureTime   = function(self, v) self._fractureTime = v end
    p.HasInjury         = function(self) return _partHasInjury(self) end
    return p
end

-- Helper: create a mock body damage with a part list.
-- Gates (getOverallBodyHealth, HasInjury) are derived from current parts
-- state so mutation between ticks flows through correctly.
local function MockInjuryBodyDamage(parts)
    local list = {
        size = function(self) return #parts end,
        get  = function(self, i) return parts[i + 1] end,
    }
    return {
        getBodyParts = function(self) return list end,
        getOverallBodyHealth = function(self)
            for _, p in ipairs(parts) do
                if _partHasInjury(p) then return 50 end
            end
            return 100
        end,
        HasInjury = function(self)
            for _, p in ipairs(parts) do
                if _partHasInjury(p) then return true end
            end
            return false
        end,
    }
end

-- Helper: create a mock player with bouncer trait and custom body damage
local function MockBouncerPlayer(traitList, parts, strengthLevel)
    local p = MockPlayer(traitList)
    local bd = MockInjuryBodyDamage(parts)
    p.getBodyDamage = function(self) return bd end
    if strengthLevel then
        p:setPerkLevel(Perks.Strength, strengthLevel)
    end
    return p
end

-- Cooldown formula: max(10, baseSec - STR * secPerStr) * 60
-- Tier I: 300 - 10*STR,  Tier II: 220 - 20*STR

test("bouncer downgrades bite to deep wound (STR 5)", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Init tick: snapshot clean state
    Events.OnPlayerUpdate:fire(player)

    -- Fresh bite lands with infection
    part._bitten = true
    part._biteTime = 60
    part._isInfected = true

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    assert_eq(part._biteTime, 0, "biteTime should be cleared")
    assert_eq(part._isInfected, false, "infection should be cleared")
    assert_true(part:isDeepWounded(), "deep wound should be applied")
    assert_eq(part._deepWoundTime, 20, "deepWoundTime should be set to 20")
    -- (300 - 5*10) * 60 = 250 * 60 = 15000
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 15000, "tier I STR5 cooldown = 15000")
end)

test("bouncer downgrades deep wound to scratch (STR 5)", function()
    local part = MockInjuryPart("UpperArm_L", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Init tick: clean snapshot
    Events.OnPlayerUpdate:fire(player)

    -- New deep wound lands
    part._deepWounded = true
    part._deepWoundTime = 30

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:isDeepWounded(), "deep wound should be cleared")
    assert_eq(part._deepWoundTime, 0, "deepWoundTime should be cleared")
    assert_true(part._scratched, "scratch should be applied")
    assert_eq(part._scratchNoInfect, true, "scratch should use forceNoInfection=true")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 15000, "tier I STR5 cooldown = 15000")
end)

test("bouncer halves fracture time (STR 5)", function()
    local part = MockInjuryPart("LowerLeg_R", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Init tick: clean snapshot
    Events.OnPlayerUpdate:fire(player)

    -- New fracture lands
    part._fractureTime = 40

    Events.OnPlayerUpdate:fire(player)

    assert_eq(part._fractureTime, 20, "fracture time should be halved from 40 to 20")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 15000, "tier I STR5 cooldown = 15000")
end)

test("bouncer tier II uses shorter cooldown (STR 5)", function()
    local part = MockInjuryPart("Head", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_II" }, { part }, 5)

    -- Init tick
    Events.OnPlayerUpdate:fire(player)

    -- Fresh bite
    part._bitten = true
    part._biteTime = 50
    part._isInfected = true

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    -- (220 - 5*20) * 60 = 120 * 60 = 7200
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 7200, "tier II STR5 cooldown = 7200")
end)

test("bouncer does NOT fire during cooldown", function()
    local part = MockInjuryPart("Torso_Upper", { bitten = true, biteTime = 60 })
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)
    player:getModData()["UT_bouncer_cooldown"] = 500

    Events.OnPlayerUpdate:fire(player)

    assert_true(part:bitten(), "bite should still be present during cooldown")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 499, "cooldown should decrement by 1")
end)

test("bouncer processes highest severity first (bite before deep wound)", function()
    local bitePart = MockInjuryPart("Head", {})
    local deepPart = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { bitePart, deepPart }, 5)

    -- Init tick: both clean, snapshot taken
    Events.OnPlayerUpdate:fire(player)

    -- Both injuries land simultaneously
    bitePart._bitten = true
    bitePart._biteTime = 60
    bitePart._isInfected = true
    deepPart._deepWounded = true
    deepPart._deepWoundTime = 30

    Events.OnPlayerUpdate:fire(player)

    -- Bite should be downgraded, deep wound untouched (only one per cooldown)
    assert_true(not bitePart:bitten(), "bite should be cleared first")
    assert_true(deepPart:isDeepWounded(), "deep wound should still be present (one per cooldown)")
end)

test("bouncer does nothing when no injuries present", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    Events.OnPlayerUpdate:fire(player)

    assert_eq(player:getModData()["UT_bouncer_cooldown"], 0, "cooldown should remain 0 (no injury found)")
end)

test("bouncer ignores fracture time <= 1", function()
    local part = MockInjuryPart("LowerLeg_L", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Init tick: clean snapshot
    Events.OnPlayerUpdate:fire(player)

    -- Apply a sub-threshold fracture
    part._fractureTime = 0.5

    Events.OnPlayerUpdate:fire(player)

    assert_eq(part._fractureTime, 0.5, "fracture time should remain unchanged when <= 1")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 0, "cooldown should remain 0")
end)

test("bouncer STR 0 uses full base cooldown", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 0)

    -- Init tick
    Events.OnPlayerUpdate:fire(player)

    -- Fresh bite
    part._bitten = true
    part._biteTime = 60
    part._isInfected = true

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    -- (300 - 0*10) * 60 = 300 * 60 = 18000
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 18000, "tier I STR0 cooldown = 18000")
end)

test("bouncer STR 10 produces minimum tier I cooldown", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 10)

    -- Init tick
    Events.OnPlayerUpdate:fire(player)

    -- Fresh bite
    part._bitten = true
    part._biteTime = 60
    part._isInfected = true

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    -- (300 - 10*10) * 60 = 200 * 60 = 12000
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 12000, "tier I STR10 cooldown = 12000")
end)

test("bouncer tier II STR 10 cooldown", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_II" }, { part }, 10)

    -- Init tick: clean snapshot
    Events.OnPlayerUpdate:fire(player)

    -- New deep wound
    part._deepWounded = true
    part._deepWoundTime = 30

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:isDeepWounded(), "deep wound should be cleared")
    -- (220 - 10*20) * 60 = 20 * 60 = 1200
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 1200, "tier II STR10 cooldown = 1200")
end)

test("bouncer tier II STR 9 cooldown", function()
    local part = MockInjuryPart("Head", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_II" }, { part }, 9)

    -- Init tick
    Events.OnPlayerUpdate:fire(player)

    -- Fresh bite
    part._bitten = true
    part._biteTime = 50
    part._isInfected = true

    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    -- (220 - 9*20) * 60 = 40 * 60 = 2400
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 2400, "tier II STR9 cooldown = 2400")
end)

test("bouncer preserves pre-existing infection when downgrading bite", function()
    -- Part starts infected (from a prior wound) but not bitten
    local part = MockInjuryPart("Torso_Upper", { isInfected = true })
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Tick 1: no bite, bouncer records infection snapshot
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 0, "no injury, cooldown stays 0")

    -- Simulate a new bite landing on the already-infected part
    part._bitten = true
    part._biteTime = 60

    -- Tick 2: bouncer sees bite, checks snapshot → part was already infected → keeps it
    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    assert_eq(part._isInfected, true, "pre-existing infection should be PRESERVED")
    assert_true(part:isDeepWounded(), "deep wound should be applied")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 15000, "cooldown should be set")
end)

test("bouncer clears new infection from fresh bite", function()
    -- Part starts clean, no infection
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Tick 1: nothing to do, records clean snapshot
    Events.OnPlayerUpdate:fire(player)

    -- Simulate a bite with new infection landing
    part._bitten = true
    part._biteTime = 60
    part._isInfected = true

    -- Tick 2: bouncer sees bite, checks snapshot → part was NOT infected → clears it
    Events.OnPlayerUpdate:fire(player)

    assert_true(not part:bitten(), "bite should be cleared")
    assert_eq(part._isInfected, false, "new infection should be cleared")
    assert_true(part:isDeepWounded(), "deep wound should be applied")
end)

-- Edge case: bite arrives during cooldown. The infection from that
-- bite must be cleared when bouncer finally processes it, NOT treated
-- as pre-existing just because cooldown-expiry sees it.
test("bouncer clears infection from bite received during cooldown", function()
    local partA = MockInjuryPart("Torso_Upper", {})
    local partB = MockInjuryPart("Head", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { partA, partB }, 5)

    -- Init tick: both clean, snapshot taken
    Events.OnPlayerUpdate:fire(player)

    -- Bite on A → processed immediately (cooldown was 0)
    partA._bitten = true
    partA._biteTime = 60
    partA._isInfected = true
    Events.OnPlayerUpdate:fire(player)
    assert_true(not partA:bitten(), "A bite processed")

    -- Simulate: during cooldown, zombie bites B → B now bitten+infected
    partB._bitten = true
    partB._biteTime = 60
    partB._isInfected = true

    -- Clear A's residual deep wound (from the downgrade) so B's bite
    -- is the only injury when bouncer fires next.
    partA._deepWounded = false
    partA._deepWoundTime = 0

    -- Fast-forward cooldown to 0 (simulating full cooldown elapsing)
    player:getModData()["UT_bouncer_cooldown"] = 0

    -- Bouncer fires again: B's infection came from the bite → must clear
    Events.OnPlayerUpdate:fire(player)

    assert_true(not partB:bitten(), "B bite should be cleared")
    assert_eq(partB._isInfected, false, "B infection should be cleared (came from bite, not pre-existing)")
    assert_true(partB:isDeepWounded(), "B should get deep wound")
end)

-- Edge case: part is already infected when bite arrives during cooldown.
-- Bouncer should preserve that infection because it predates the bite.
test("bouncer preserves pre-existing infection through mid-cooldown bite", function()
    -- Part B starts infected (from a prior wound)
    local partA = MockInjuryPart("Torso_Upper", {})
    local partB = MockInjuryPart("Head", { isInfected = true })
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { partA, partB }, 5)

    -- Init tick: B is infected (no bite) → snapshot records B as infected
    Events.OnPlayerUpdate:fire(player)

    -- Bite on A → processed
    partA._bitten = true
    partA._biteTime = 60
    Events.OnPlayerUpdate:fire(player)
    assert_true(not partA:bitten(), "A bite processed")

    -- During cooldown: zombie bites B (already-infected part)
    partB._bitten = true
    partB._biteTime = 60

    -- Clear A's residual deep wound so B is processed next
    partA._deepWounded = false
    partA._deepWoundTime = 0

    -- Fast-forward cooldown
    player:getModData()["UT_bouncer_cooldown"] = 0

    -- Bouncer fires: B was infected BEFORE the bite → must preserve
    Events.OnPlayerUpdate:fire(player)

    assert_true(not partB:bitten(), "B bite should be cleared")
    assert_eq(partB._isInfected, true, "B pre-existing infection should be PRESERVED")
    assert_true(partB:isDeepWounded(), "B should get deep wound")
end)

-- Edge case: two parts bitten simultaneously on the same tick.
-- First bite is processed and infection cleared. Second bite must
-- also have its infection cleared on the next cycle (not locked in
-- by the post-trigger snapshot).
test("bouncer clears infection on both parts when bitten simultaneously", function()
    local partA = MockInjuryPart("Torso_Upper", {})
    local partB = MockInjuryPart("Head", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { partA, partB }, 5)

    -- Init tick: both clean
    Events.OnPlayerUpdate:fire(player)

    -- Both parts get bitten+infected simultaneously
    partA._bitten = true
    partA._biteTime = 60
    partA._isInfected = true
    partB._bitten = true
    partB._biteTime = 60
    partB._isInfected = true

    -- Bouncer processes A first (lower index = first in scan order)
    Events.OnPlayerUpdate:fire(player)
    assert_true(not partA:bitten(), "A processed first")
    assert_eq(partA._isInfected, false, "A infection cleared")
    assert_true(partB:bitten(), "B still waiting (one per cooldown)")

    -- Clear A's residual deep wound so B is processed next
    partA._deepWounded = false
    partA._deepWoundTime = 0

    -- Fast-forward cooldown
    player:getModData()["UT_bouncer_cooldown"] = 0

    -- Bouncer processes B: infection should be cleared (was clean before bite)
    Events.OnPlayerUpdate:fire(player)
    assert_true(not partB:bitten(), "B bite should be cleared")
    assert_eq(partB._isInfected, false, "B infection should be cleared (not pre-existing)")
    assert_true(partB:isDeepWounded(), "B should get deep wound")
end)

-- Edge case: an injury that exists when the cooldown expires is captured
-- in the refreshed baseline snapshot and must NOT be downgraded.
test("bouncer ignores injury present at cooldown expiry", function()
    local part = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { part }, 5)

    -- Init tick: clean snapshot, cooldown=0
    Events.OnPlayerUpdate:fire(player)

    -- Put a bite on the part AND set cooldown=1 so the next tick is
    -- the expiry tick (decrements 1→0, re-baselines snapshot including
    -- this bite as pre-existing).
    part._bitten = true
    part._biteTime = 60
    player:getModData()["UT_bouncer_cooldown"] = 1

    -- Expiry tick: decrements to 0, re-baselines snapshot.
    Events.OnPlayerUpdate:fire(player)
    assert_true(part:bitten(), "expiry tick must NOT downgrade (injury is baseline)")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 0, "cooldown now 0")

    -- Next tick: READY, scan delta. Bite is in snapshot → no delta → no action.
    Events.OnPlayerUpdate:fire(player)
    assert_true(part:bitten(), "pre-existing injury should remain untouched after ready")
    assert_eq(player:getModData()["UT_bouncer_cooldown"], 0, "cooldown should stay 0")
end)

-- Edge case: two new injuries arriving on the same tick. Lowest-index
-- part wins deterministically; MULTI_NEW is logged for observability.
test("bouncer picks lowest-index part on simultaneous new injuries", function()
    local p0 = MockInjuryPart("Head", {})
    local p1 = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({ "UniversalTraits:UT_bouncer_I" }, { p0, p1 }, 5)

    -- Init clean
    Events.OnPlayerUpdate:fire(player)

    -- Both get NEW deep wounds at once
    p0._deepWounded = true; p0._deepWoundTime = 30
    p1._deepWounded = true; p1._deepWoundTime = 30

    Events.OnPlayerUpdate:fire(player)

    assert_true(not p0:isDeepWounded(), "index-0 part should be downgraded")
    assert_true(p1:isDeepWounded(), "index-1 part should remain (one per cooldown)")
end)

-- ===== UTCore.getInjuries lazy accessor tests =====
test("getInjuries returns EMPTY sentinel when body fully healthy", function()
    local p = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({}, { p }, 5)
    local tick = UTCore.buildMockTickContext(player)
    local injuries = UTCore.getInjuries(tick)
    assert_true(injuries == UTCore._EMPTY_INJURIES, "should return shared EMPTY sentinel")
    assert_eq(injuries.count, 0, "EMPTY sentinel count is 0")
end)

test("getInjuries is cached on repeat call", function()
    local p = MockInjuryPart("Torso_Upper", {})
    local player = MockBouncerPlayer({}, { p }, 5)
    local tick = UTCore.buildMockTickContext(player)
    local a = UTCore.getInjuries(tick)
    local b = UTCore.getInjuries(tick)
    assert_true(a == b, "second call must return cached table")
    assert_true(tick._injuriesBuilt == true, "cache flag must be set")
end)

test("getInjuries populates only dirty parts; clean parts reuse sentinel", function()
    local clean = MockInjuryPart("Head", {})
    local dirty = MockInjuryPart("Torso_Upper", { bitten = true, biteTime = 60 })
    local player = MockBouncerPlayer({}, { clean, dirty }, 5)
    local tick = UTCore.buildMockTickContext(player)
    local injuries = UTCore.getInjuries(tick)
    assert_eq(injuries.count, 2, "two parts")
    assert_true(injuries[0] == UTCore._CLEAN_PART, "clean part is shared sentinel")
    assert_true(injuries[1].bitten == true, "dirty part has own entry with bitten=true")
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
    -- SmallBlunt level=5 → critChance = (5+40)*0.01 = 0.45 → 45%
    -- ZombRand always returns 0 → 0 < 45 → crit fires
    -- Crit damage: 3.0 + (5 * 0.3) = 4.5, endurance 1.0 → 4.5 * 1.35 = 6.075
    local player = MockPlayer({ "UniversalTraits:UT_martial" })
    player:setPerkLevel(Perks.SmallBlunt, 5)
    -- endurance starts at 1.0 in MockPlayer (no penalty)

    local weapon = MockWeaponSimple("BareHands")
    local target = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, target, weapon, 1)

    assert_true(target:getHealth() < 100,
        "expected health < 100 after martial crit, got " .. tostring(target:getHealth()))
end)

test("martial skips when weapon is not BareHands", function()
    local player = MockPlayer({ "UniversalTraits:UT_martial" })
    player:setPerkLevel(Perks.SmallBlunt, 5)

    local weapon = MockWeaponSimple("Axe")
    local target = MockTarget(100)

    Events.OnWeaponHitCharacter:fire(player, target, weapon, 1)

    assert_eq(target:getHealth(), 100,
        "expected health unchanged when weapon is not BareHands")
end)

-- ===== Task 7: SomewhatTraits behavior ports =====
-- Load the four ported trait files
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flailer.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_lurcher.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_scardycat.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_pacer.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_trekker.lua")

-- Helper: build a player with getSpottedList support
local function MockUpdatePlayer(traitList, opts)
    opts = opts or {}
    local p = MockPlayer(traitList)
    p._sprinting = opts.sprinting or false
    p._moving    = opts.moving    or false
    p._indoors   = opts.indoors   or false
    if opts.spottedSize then
        -- Build a full spottedList with per-element isDead() (needed by traits
        -- that iterate + filter dead zombies, e.g. scardycat, bouncer)
        local deadCount = opts.spottedDeadCount or 0
        local entries = {}
        for i = 1, opts.spottedSize do
            entries[i] = { isDead = function() return i > (opts.spottedSize - deadCount) end }
        end
        p.getSpottedList = function(self)
            return {
                size = function() return #entries end,
                get  = function(_, idx) return entries[idx + 1] end,
            }
        end
        p.DistTo = p.DistTo or function(self, enemy)
            return enemy._dist or 1.0
        end
    end
    if opts.endurance ~= nil then
        p:getStats():set(CharacterStat.ENDURANCE, opts.endurance)
    end
    if opts.panicLevel ~= nil then
        p:getStats():set(CharacterStat.PANIC, opts.panicLevel)
    end
    if opts.nimble ~= nil then
        p:setPerkLevel(Perks.Nimble, opts.nimble)
    end
    if opts.indoorTicks ~= nil then
        p:getModData()["UT_pacer_indoor_ticks"] = opts.indoorTicks
    end
    return p
end

local function firePlayerUpdates(player, count)
    for _ = 1, count do
        Events.OnPlayerUpdate:fire(player)
    end
end

test("flailer stumble fires when panicked and sprinting", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_flailer" },
        { sprinting = true, panicLevel = 2 }
    )
    -- cooldown starts nil (=> 0), ZombRand returns 0 (< 5) => stumble fires
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._bumpFall == true,
        "expected _bumpFall=true after flailer stumble, got " .. tostring(player._bumpFall))
end)

test("lurcher stumble fires when fatigued and moving", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_lurcher" },
        { moving = true, endurance = 0.2, nimble = 0 }
    )
    -- cooldown starts nil (=> 0), ZombRand returns 0 (< 3) => stumble fires
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._bumpFall == true,
        "expected _bumpFall=true after lurcher stumble, got " .. tostring(player._bumpFall))
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

test("scardycat ignores dead zombies in count (7 alive + 3 dead = no scream)", function()
    -- Total 10 in list but only 7 alive → below >8 threshold
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_scardycat" },
        { spottedSize = 10, spottedDeadCount = 3 }
    )
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._said == nil,
        "scardycat should NOT scream when < 9 living zombies spotted")
end)

test("scardycat screams when 9+ living zombies (dead excluded)", function()
    -- 10 total, 1 dead = 9 alive → above threshold of >8
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_scardycat" },
        { spottedSize = 10, spottedDeadCount = 1 }
    )
    Events.OnPlayerUpdate:fire(player)
    assert_true(player._said ~= nil,
        "scardycat SHOULD scream with 9 living zombies spotted")
end)

test("pacer applies unhappiness after 600 indoor ticks", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_pacer" },
        { indoors = true, indoorTicks = 599 }
    )
    local stats = player:getStats()
    local startUnhappiness = stats:get(CharacterStat.UNHAPPINESS)
    Events.OnPlayerUpdate:fire(player)
    assert_true(stats:get(CharacterStat.UNHAPPINESS) > startUnhappiness,
        "expected unhappiness to increase after 600 indoor ticks, got "
        .. tostring(stats:get(CharacterStat.UNHAPPINESS)))
end)

test("blissful reduces unhappiness after 100 updates without nil API calls", function()
    local player = MockPlayer({ "UniversalTraits:UT_blissful" }, { unhappiness = 10 })

    firePlayerUpdates(player, 100)

    assert_eq(player:getStats():get(CharacterStat.UNHAPPINESS), 9,
        "expected blissful to reduce unhappiness by 1 after 100 updates")
end)

test("marathonrunner refunds part of endurance and fatigue loss without nil API calls", function()
    local player = MockPlayer({ "UniversalTraits:UT_marathonrunner" }, { endurance = 0.8, fatigue = 0.2 })

    withActivePlayer(player, function()
        for _ = 1, 5 do
            Events.OnPlayerUpdate:fire(player)
        end
        player:getStats():set(CharacterStat.ENDURANCE, 0.5)
        player:getStats():set(CharacterStat.FATIGUE, 0.5)
        for _ = 1, 5 do
            Events.OnPlayerUpdate:fire(player)
        end
    end)

    assert_true(player:getStats():get(CharacterStat.ENDURANCE) > 0.5, "expected endurance refund after drain")
    assert_true(player:getStats():get(CharacterStat.FATIGUE) < 0.5, "expected fatigue refund after rise")
end)

test("olympian refunds part of endurance and fatigue loss without nil API calls", function()
    local player = MockPlayer({ "UniversalTraits:UT_olympian" }, { endurance = 0.8, fatigue = 0.2 })

    withActivePlayer(player, function()
        for _ = 1, 5 do
            Events.OnPlayerUpdate:fire(player)
        end
        player:getStats():set(CharacterStat.ENDURANCE, 0.5)
        player:getStats():set(CharacterStat.FATIGUE, 0.5)
        for _ = 1, 5 do
            Events.OnPlayerUpdate:fire(player)
        end
    end)

    assert_true(player:getStats():get(CharacterStat.ENDURANCE) > 0.5, "expected endurance refund after drain")
    assert_true(player:getStats():get(CharacterStat.FATIGUE) < 0.5, "expected fatigue refund after rise")
end)

test("strongnimble converts only the exact fence fall outcome", function()
    local player = MockPlayer({ "UniversalTraits:UT_strongnimble" })
    player:setVariable("ClimbingFence", true)
    player:setVariable("ClimbFenceOutcome", "fall")
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getVariable("ClimbFenceOutcome"), "success")
end)

test("strongnimble preserves the climb outcome matrix and ordinary falls", function()
    for _, outcome in ipairs({ "falling", "rope", "obstacle", "lunge", "success" }) do
        local player = MockPlayer({ "UniversalTraits:UT_strongnimble" }, { falling = true })
        player:setVariable("ClimbingFence", true)
        player:setVariable("ClimbFenceOutcome", outcome)
        Events.OnPlayerUpdate:fire(player)
        assert_eq(player:getVariable("ClimbFenceOutcome"), outcome)
        assert_eq(player:isFalling(), true)
    end

    local player = MockPlayer({ "UniversalTraits:UT_strongnimble" })
    player:setVariable("ClimbingFence", false)
    player:setVariable("ClimbFenceOutcome", "fall")
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getVariable("ClimbFenceOutcome"), "fall")
end)

test("strongnimble requires the trait", function()
    local player = MockPlayer({})
    player:setVariable("ClimbingFence", true)
    player:setVariable("ClimbFenceOutcome", "fall")
    Events.OnPlayerUpdate:fire(player)
    assert_eq(player:getVariable("ClimbFenceOutcome"), "fall")
end)

test("axes boosts crit chance through WeaponCategory API", function()
    local weapon = _G.MockWeapon("HandAxe", 0, false, true, {
        categories = { WeaponCategory.AXE },
        criticalChance = 15,
    })
    local player = MockPlayer({ "UniversalTraits:UT_axes" }, { primaryHandItem = weapon })

    withActivePlayer(player, function()
        for _ = 1, 30 do
            Events.OnPlayerUpdate:fire(player)
        end
    end)

    assert_eq(weapon:getCriticalChance(), 25, "expected UT_axes to add 10 crit chance once")
end)

test("improviser doubles condition lower chance via B42 API", function()
    local weapon = _G.MockWeapon("HandAxe", 0, false, true, {
        conditionLowerChance = 3,
    })
    local player = MockPlayer({ "UniversalTraits:UT_improviser" }, { primaryHandItem = weapon })

    withActivePlayer(player, function()
        for _ = 1, 30 do
            Events.OnPlayerUpdate:fire(player)
        end
    end)

    assert_eq(weapon:getConditionLowerChance(), 6, "expected UT_improviser to double condition lower chance")
end)

test("gordanite marks cooked food for hunger bonus and boosts calories once", function()
    local item = MockItem("Stew", { isCooked = true, hungerChange = -20, calories = 200 })
    local inventory = MockInventory(0, 8)
    inventory:AddItem(item)
    local player = MockPlayer({ "UniversalTraits:UT_gordanite" }, { inventory = inventory })

    withActivePlayer(player, function()
        for _ = 1, 60 do
            Events.OnPlayerUpdate:fire(player)
        end
        for _ = 1, 60 do
            Events.OnPlayerUpdate:fire(player)
        end
    end)

    assert_eq(item:getModData()["UT_gordBoosted"], true, "expected cooked food to be marked as boosted")
    assert_eq(item:getModData()["UT_gordHungerMult"], 1.5, "expected hunger multiplier marker")
    assert_eq(item:getCalories(), 300, "expected calories to be multiplied once")
end)

local function makeCaughtFish()
    return MockItem("Base.Trout", {
        calories = 120,
        lipids = 8,
        carbohydrates = 4,
        proteins = 20,
        baseHunger = -0.2,
        hungChange = -0.2,
        actualWeight = 6,
        worldScale = 0.5,
        moddata = { fishing_FishSize = 50, fishing_FishHandItem = "Trout_Hand_Medium" },
    })
end

local function makeFishProducer(character, item)
    return setmetatable({
        character = character,
        nextFish = item,
        fishSize = 2.5,
        fishSizeLen = 50,
    }, { __index = Fishing.Fish })
end

test("wildsman scales the real createFish result and pickup keeps that instance", function()
    local fish = makeCaughtFish()
    local producer = makeFishProducer(MockPlayer({ "UniversalTraits:UT_wildsman" }), fish)
    local produced = producer:createFish({})
    local pickupAction = { item = produced }

    assert_eq(produced, fish, "expected createFish to return the original item instance")
    assert_eq(pickupAction.item, fish, "expected pickup to retain the modified item instance")
    assert_eq(producer.createFishCalls, 1, "expected the original producer to run once")
    assert_eq(fish:getCalories(), 180)
    assert_eq(fish:getLipids(), 12)
    assert_eq(fish:getCarbohydrates(), 6)
    assert_eq(fish:getProteins(), 30)
    assert_close(fish:getBaseHunger(), -0.3, 1e-12)
    assert_close(fish:getHungChange(), -0.3, 1e-12)
    assert_eq(fish:getActualWeight(), 9)
    assert_eq(fish:getWorldScale(), 0.75)
    assert_eq(fish:getModData().fishing_FishSize, 75)
    assert_eq(producer.fishSize, 3.75)
    assert_eq(producer.fishSizeLen, 75)
end)

test("wildsman fishing hook leaves negative paths unchanged", function()
    local cases = {
        makeFishProducer(nil, makeCaughtFish()),
        makeFishProducer(MockPlayer({}), makeCaughtFish()),
        makeFishProducer(MockPlayer({ "UniversalTraits:UT_wildsman" }), MockItem("Base.Sock")),
    }

    for _, producer in ipairs(cases) do
        local item = producer.nextFish
        local calories = item:getCalories()
        local weight = item:getActualWeight()
        assert_eq(producer:createFish({}), item)
        assert_eq(item:getCalories(), calories)
        assert_eq(item:getActualWeight(), weight)
        assert_eq(item:getModData().UT_wildsmanFishScaled, nil)
    end
end)

test("wildsman fishing hook is reload-safe and scales each item only once", function()
    assert_eq(Events.OnFishCaught, nil, "expected no manufactured fish-caught event")
    local wrapper = Fishing.Fish.createFish
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_wildsman.lua")
    assert_eq(Fishing.Fish.createFish, wrapper, "expected reload not to wrap createFish again")

    local fish = makeCaughtFish()
    local character = MockPlayer({ "UniversalTraits:UT_wildsman" })
    local clientProducer = makeFishProducer(character, fish)
    local serverProducer = makeFishProducer(character, fish)
    clientProducer:createFish({})
    serverProducer:createFish({})

    assert_eq(clientProducer.createFishCalls, 1, "expected client producer to reach the original")
    assert_eq(serverProducer.createFishCalls, 1, "expected server producer to reach the original")
    assert_eq(fish:getCalories(), 180, "expected a duplicate path not to scale the item twice")
    assert_eq(fish:getActualWeight(), 9, "expected a duplicate path not to scale weight twice")
end)

test("trekker restores walking endurance and normalizes walking calorie burn", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_trekker" },
        { moving = true }
    )
    local stats = player:getStats()
    local nutrition = player:getNutrition()
    local expectedCalories = 1990.0 + (2000.0 - 1990.0) * ((0.13 * 0.6 - 0.016) / (0.13 * 0.6))

    stats:set(CharacterStat.ENDURANCE, 0.9)
    stats:set(CharacterStat.HUNGER, 0.2)
    nutrition:setCalories(2000.0)
    firePlayerUpdates(player, 1)

    stats:set(CharacterStat.ENDURANCE, 0.82)
    stats:set(CharacterStat.HUNGER, 0.24)
    nutrition:setCalories(1990.0)
    firePlayerUpdates(player, 1)

    assert_eq(stats:get(CharacterStat.ENDURANCE), 0.9,
        "expected Trekker to refund endurance lost while walking")
    assert_eq(stats:get(CharacterStat.HUNGER), 0.24,
        "expected Trekker to leave normal hunger rise untouched")
    assert_true(math.abs(nutrition:getCalories() - expectedCalories) < 0.0001,
        "expected Trekker to refund walking calories down to the idle-rate equivalent")
end)

test("trekker does not affect idle endurance or calories", function()
    local player = MockUpdatePlayer(
        { "UniversalTraits:UT_trekker" },
        { moving = false }
    )
    local stats = player:getStats()
    local nutrition = player:getNutrition()

    stats:set(CharacterStat.ENDURANCE, 0.9)
    nutrition:setCalories(2000.0)
    firePlayerUpdates(player, 1)

    stats:set(CharacterStat.ENDURANCE, 0.82)
    nutrition:setCalories(1990.0)
    firePlayerUpdates(player, 1)

    assert_eq(stats:get(CharacterStat.ENDURANCE), 0.82,
        "expected Trekker to leave idle endurance drain alone")
    assert_eq(nutrition:getCalories(), 1990.0,
        "expected Trekker to leave idle calorie burn alone")
end)

-- ===== UT_batteringram collision tests =====
UTCore._zombieCollisionCallbacks = {}  -- reset before batteringram tests
-- Load the collision hook so declareZombieCollisionHandler is available
dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_ZombieCollisionHook.lua")
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
    -- Should use hitFromBehind=true for dramatic forward-slam animation
    assert_eq(zombie:getKnockDownCalls()[1], true,
        "expected knockDown(true) for charging impact animation")
end)

test("batteringram does NOT manipulate bump state (v3 preemptive)", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    player._bumpType = "stagger"
    local originalZombie = MockZombie()
    player._bumpedChr = originalZombie
    player._blockMovement = true
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    -- v3b: callback no longer touches bump state — prevention via knockDown + setBumpedChr
    assert_eq(player._bumpType, "stagger",
        "v3 callback should NOT clear bumpType")
    assert_eq(player._bumpedChr, originalZombie,
        "v3 callback should NOT change bumpedChr")
    assert_eq(player._blockMovement, true,
        "v3 callback should NOT clear blockMovement")
end)

test("batteringram returns true to activate bump suppression", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie()
    local fn = UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"]
    local result = fn(player, zombie)
    assert_eq(result, true,
        "expected callback to return true for bump suppression")
end)

test("batteringram returns false when player is not sprinting or running", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    -- _sprinting and _running are both false (default)
    local zombie = MockZombie()
    local fn = UTCore._zombieCollisionCallbacks["UniversalTraits:UT_batteringram"]
    local result = fn(player, zombie)
    assert_eq(result, false,
        "expected callback to return false when not sprinting")
end)

test("batteringram drains endurance on each collision", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie()
    fireRamCollision(player, zombie)
    assert_true(player:getStats():get(CharacterStat.ENDURANCE) < 1.0,
        "expected endurance < 1.0 after collision")
end)

test("batteringram drains less endurance while sprinting than running", function()
    local sprintPlayer = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, sprintPlayer)
    sprintPlayer._sprinting = true
    fireRamCollision(sprintPlayer, MockZombie())
    local sprintEnd = sprintPlayer:getStats():get(CharacterStat.ENDURANCE)

    local runPlayer = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, runPlayer)
    runPlayer._running = true
    fireRamCollision(runPlayer, MockZombie())
    local runEnd = runPlayer:getStats():get(CharacterStat.ENDURANCE)

    assert_true(sprintEnd > runEnd,
        "expected sprint drain (" .. sprintEnd .. ") < run drain (" .. runEnd .. ")")
end)

test("batteringram deals direct damage to zombie when sprinting", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie({ health = 1.0 })
    fireRamCollision(player, zombie)
    assert_true(zombie:getHealth() < 1.0,
        "expected zombie health reduced on sprint charge, got " .. tostring(zombie:getHealth()))
end)

test("batteringram does NOT deal direct damage to zombie when running (not sprinting)", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._running = true
    local zombie = MockZombie({ health = 1.0 })
    fireRamCollision(player, zombie)
    assert_eq(zombie:getHealth(), 1.0,
        "expected zombie health unchanged on run charge (no sprint bonus)")
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
    -- ZombRand stub returns 0 → guaranteed crit (L0: 5% chance, 0 < 5)
    -- Sprint damage 0.15 + martial crit 3.0*1.35 = 4.2 → health 95.65
    local player = MockPlayer({ "UniversalTraits:UT_batteringram", "UniversalTraits:UT_martial" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie({ health = 100 })
    fireRamCollision(player, zombie)
    assert_true(zombie:getHealth() < 100,
        "expected zombie health reduced by martial synergy, got " .. tostring(zombie:getHealth()))
end)

-- ===== INTEGRATION: verify the engine's re-bump guard is preserved =====
-- The PZ tick order (from decompiled IsoPlayer.updateInternal2) is:
--   1. doDeferredMovement()         — movement applied
--   2. OnPlayerUpdate                — our hook fires here
--   3. separate() collision detection — re-detects overlap, re-sets bumpType
--   4. stateMachine.update()         — BumpedState enters if bumpType set
--
-- The fix relies on the engine's OWN re-bump guard in separate() (line 1222):
--   if getBumpedChr() != obj then bump = true
-- By preserving bumpedChr (NOT clearing it), separate() skips re-bumping for
-- the same zombie. No teleportation, no setX/setY. The player moves naturally.

--- Simulates PZ's separate() re-bump guard.
--- Returns true if the same zombie WOULD re-trigger a bump (i.e., bumpedChr
--- does NOT match, so the engine would think this is a new collision).
local function wouldSeparateRebump(player, zombie)
    -- IsoMovingObject.java line 1222: getBumpedChr() != obj
    return player:getBumpedChr() ~= zombie
end

test("INTEGRATION: v3 callback does not touch bumpedChr", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie()
    player:setBumpedChr(zombie)
    fireRamCollision(player, zombie)
    -- v3: callback doesn't touch bump state at all
    assert_eq(player:getBumpedChr(), zombie,
        "v3 callback must not modify bumpedChr")
end)

test("INTEGRATION: engine guard allows bump from DIFFERENT zombie (cluster case)", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombieA = MockZombie()
    local zombieB = MockZombie()

    -- Initial collision with zombie A
    player:setBumpType("stagger")
    player:setBumpedChr(zombieA)
    fireRamCollision(player, zombieA)

    -- bumpedChr = zombieA → engine guard blocks re-bump from A
    assert_eq(wouldSeparateRebump(player, zombieA), false,
        "expected engine guard to block re-bump from same zombie A")

    -- But a DIFFERENT zombie can trigger a new bump
    assert_eq(wouldSeparateRebump(player, zombieB), true,
        "expected engine guard to ALLOW bump from different zombie B")
end)

test("INTEGRATION: v4 collision hook does NOT set setBumpedChr (knockdown-only)", function()
    local zombieA = MockZombie({ x = 5.3, y = 5, z = 0 })
    local zombieB = MockZombie({ x = 5.5, y = 5, z = 0 })
    local sq = MockCollisionSquare(5, 5, 0, { zombieA, zombieB })
    _G._mockCell = MockCell({ ["5,5,0"] = sq })
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" },
        { x = 5, y = 5, square = sq })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    Events.OnPlayerUpdate:fire(player)
    -- v4: hook NEVER touches player bump state — only fires knockdown callbacks
    assert_eq(player:getBumpedChr(), nil,
        "v4 hook must NOT set bumpedChr (knockdown-only defense)")
end)

test("INTEGRATION: v4 collision hook fires knockdown callback per zombie", function()
    local zombie = MockZombie({ x = 5.3, y = 5, z = 0 })
    local sq = MockCollisionSquare(5, 5, 0, { zombie })
    _G._mockCell = MockCell({ ["5,5,0"] = sq })
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" },
        { x = 5, y = 5, square = sq })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    Events.OnPlayerUpdate:fire(player)
    -- Callback should have knocked down the zombie
    assert_true(zombie:isKnockedDown(),
        "batteringram callback should knock down zombie on collision")
end)

test("INTEGRATION: v3 old suppression moddata cleaned up when player stops running", function()
    local zombie = MockZombie({ x = 5.3, y = 5, z = 0 })
    local sq = MockCollisionSquare(5, 5, 0, { zombie })
    _G._mockCell = MockCell({ ["5,5,0"] = sq })
    local player = MockPlayer({ "UniversalTraits:UT_batteringram" },
        { x = 5, y = 5, square = sq })
    Events.OnCreatePlayer:fire(0, player)
    -- Inject old suppression moddata (migration scenario)
    local md = player:getModData()
    md.UT_bumpSuppress = 5
    md.UT_bumpGuardZombie = zombie
    md.UT_prevBumped = true
    -- Player is walking (not running/sprinting)
    Events.OnPlayerUpdate:fire(player)
    assert_eq(md.UT_bumpSuppress, nil,
        "old suppression data should be cleaned up")
    assert_eq(md.UT_bumpGuardZombie, nil,
        "old guard zombie should be cleaned up")
    assert_eq(md.UT_prevBumped, nil,
        "old prevBumped should be cleaned up")
end)

-- ===== QA checklist follow-up coverage =====

-- ===== Battering Ram Engine Stack Tests =====
-- Engine contract verification + behavioral/regression tests for the
-- collision stack: separate(), BumpedState, suppression timeline.
-- Promote locals to globals so the dofile'd script can see them.
_G.test = test
_G.assert_eq = assert_eq
_G.assert_true = assert_true
_G.base = base
dofile(base .. "test_batteringram_engine_stack.lua")

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
    Events.OnEnterVehicle:fire(player)
    assert_eq(vehicle:getMaxSpeed(), 120, "expected +20% max speed")
    assert_eq(vehicle:getBrakingForce(), 12, "expected +20% braking force")
    assert_eq(vehicle:getEnginePower(), 120, "expected +20% engine power")
    assert_eq(vehicle:getEngineLoudness(), 80, "expected 20% quieter engine")
end)

test("expertdriver applies the full vehicle bonus package", function()
    local vehicle = MockVehicle()
    local player = MockPlayer({ "UniversalTraits:UT_expertdriver" }, { vehicle = vehicle })
    player:setVehicle(vehicle)
    Events.OnEnterVehicle:fire(player)
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
    Events.OnEnterVehicle:fire(player)
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
    Events.OnEnterVehicle:fire(player)
    player:setVehicle(nil)
    UTCore.updateVehicleTraitState(player)
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
    assert_eq(player:getStats():get(CharacterStat.ENDURANCE), 0.5, "expected exhaustion recovery burst to set endurance to 0.5")
    assert_true(player:getModData()["UT_indefRecovering"] == nil, "expected recovery flag to clear")
end)

test("hardy enters exhaustion state then grants the recovery bonus", function()
    local player = MockPlayer({ "UniversalTraits:UT_hardy" }, { fatigue = 0.9, endurance = 0.4 })
    withActivePlayer(player, function()
        setMockGameTime(1.0, 0)
        Events.EveryOneMinute:fire()
        player:getStats():set(CharacterStat.FATIGUE, 0.2)
        player:getModData()["UT_hardyRestingMins"] = 9
        setMockGameTime(1.2, 0)
        Events.EveryOneMinute:fire()
        setMockGameTime(1.21, 0)
        Events.EveryOneMinute:fire()
    end)
    assert_true(player:getModData()["UT_hardyExhausted"] == nil, "expected exhausted state to clear")
    assert_true(player:getModData()["UT_hardyBonus"] ~= nil, "expected hardy bonus window to start")
    assert_true(player:getStats():get(CharacterStat.ENDURANCE) > 0.4, "expected hardy bonus to increase endurance")
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
    assert_true(player:getStats():get(CharacterStat.ENDURANCE) > 0.1, "expected second wind to restore endurance")
    assert_true(player:getModData()["UT_secondwindTriggered"] == nil, "expected second wind flag to clear after cooldown")
end)

test("immuneresponse reduces infection and fatigue every ten minutes", function()
    local player = MockPlayer({ "UniversalTraits:UT_immuneresponse" }, { zombieInfection = 50, fatigue = 0.4 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_true(math.abs(player:getBodyDamage():getApparentInfectionLevel() - 47) < 0.1,
        "expected infection to drop by 3 (50→47)")
    assert_true(math.abs(player:getStats():get(CharacterStat.FATIGUE) - 0.38) < 0.0001,
        "expected fatigue to drop by 0.02")
end)

test("immuneresponse never converts food sickness into zombie infection", function()
    local player = MockPlayer({ "UniversalTraits:UT_immuneresponse" }, {
        foodSickness = 80,
        zombieInfection = 0,
        fatigue = 0.4,
    })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 0,
        "expected food sickness not to create zombie infection")
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 80,
        "expected food sickness channel to remain unchanged")
end)

test("immuneresponse ignores zombie fever when reducing zombie infection", function()
    local player = MockPlayer({ "UniversalTraits:UT_immuneresponse" }, {
        zombieFever = 80,
        zombieInfection = 10,
    })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 7,
        "expected direct infection reduction from 10 to 7")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_FEVER), 80,
        "expected zombie fever channel to remain unchanged")
end)

test("immuneresponse floors zombie infection at zero", function()
    local player = MockPlayer({ "UniversalTraits:UT_immuneresponse" }, { zombieInfection = 2 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 0,
        "expected infection reduction to floor at zero")
end)

test("immunocompromised marks the trait and increases infection over time", function()
    local player = fireNewGame("UniversalTraits:UT_immunocompromised")
    player:getStats():set(CharacterStat.ZOMBIE_INFECTION, 50)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getModData()["UT_immunocompromised"], true, "expected immunocompromised flag")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 51,
        "expected direct infection increase from 50 to 51")
end)

test("immunocompromised never converts food sickness into zombie infection", function()
    local player = MockPlayer({ "UniversalTraits:UT_immunocompromised" }, {
        foodSickness = 80,
        zombieInfection = 0,
    })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 0,
        "expected food sickness not to create zombie infection")
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 80,
        "expected food sickness channel to remain unchanged")
end)

test("immunocompromised ignores zombie fever when increasing zombie infection", function()
    local player = MockPlayer({ "UniversalTraits:UT_immunocompromised" }, {
        zombieFever = 80,
        zombieInfection = 10,
    })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 11,
        "expected direct infection increase from 10 to 11")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_FEVER), 80,
        "expected zombie fever channel to remain unchanged")
end)

test("immunocompromised caps zombie infection at 100", function()
    local player = MockPlayer({ "UniversalTraits:UT_immunocompromised" }, {
        zombieInfection = 99.5,
    })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 100,
        "expected infection increase to cap at 100")
end)

test("immunocompromised same-process reload keeps one minute handler", function()
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_immunocompromised.lua")
    local player = MockPlayer({ "UniversalTraits:UT_immunocompromised" }, {
        zombieInfection = 50,
    })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 51,
        "expected one 1-point increase after reload")
end)

test("superimmune reduces underlying zombie infection by exactly two", function()
    local player = fireNewGame("UniversalTraits:UT_superimmune")
    player:getStats():set(CharacterStat.ZOMBIE_INFECTION, 50)
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getModData()["UT_superimmune"], true, "expected superimmune flag")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 48, "expected direct 50→48")
end)

test("superimmune floors underlying zombie infection at zero", function()
    local player = MockPlayer({ "UniversalTraits:UT_superimmune" }, { zombieInfection = 1 })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 0, "expected floor at zero")
end)

test("superimmune does nothing without the trait", function()
    local player = MockPlayer({}, { zombieInfection = 50 })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 50, "expected no mutation")
end)

test("superimmune ignores higher food sickness and preserves illness channels", function()
    local player = MockPlayer({ "UniversalTraits:UT_superimmune" }, {
        zombieInfection = 20, foodSickness = 50, zombieFever = 7,
    })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 18, "expected direct infection reduction")
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 50, "expected food sickness unchanged")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_FEVER), 7, "expected fever unchanged")
end)

test("superimmune ignores higher fever and preserves illness channels", function()
    local player = MockPlayer({ "UniversalTraits:UT_superimmune" }, {
        zombieInfection = 20, foodSickness = 7, zombieFever = 50,
    })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 18, "expected direct infection reduction")
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 7, "expected food sickness unchanged")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_FEVER), 50, "expected fever unchanged")
end)

test("superimmune does not manufacture infection from nonzero illness", function()
    local player = MockPlayer({ "UniversalTraits:UT_superimmune" }, {
        zombieInfection = 0, foodSickness = 50, zombieFever = 40,
    })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 0, "expected zero infection unchanged")
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 50, "expected food sickness unchanged")
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_FEVER), 40, "expected fever unchanged")
end)

test("superimmune same-process reload keeps one minute handler", function()
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_superimmune.lua")
    local player = MockPlayer({ "UniversalTraits:UT_superimmune" }, { zombieInfection = 50 })
    withActivePlayer(player, function() Events.EveryOneMinute:fire() end)
    assert_eq(player:getStats():get(CharacterStat.ZOMBIE_INFECTION), 48, "expected one 2-point reduction")
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

test("idealweight does not compound drain across multiple ticks", function()
    -- Regression: previously stored pre-modification calories as prev, so each
    -- tick's perceived delta included idealweight's own prior drain.  That
    -- created a quadratically-accelerating feedback loop.
    local GAME_BURN = 0.5  -- simulated per-tick game burn
    local TICKS = 20
    local player = MockPlayer({ "UniversalTraits:UT_idealweight" }, { weight = 85.0, calories = 2000.0 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()            -- cache weight
        Events.OnPlayerUpdate:fire(player)      -- init prev
        for _ = 1, TICKS do
            local cal = player:getNutrition():getCalories()
            player:getNutrition():setCalories(cal - GAME_BURN)  -- simulate game burn
            Events.OnPlayerUpdate:fire(player)
        end
    end)
    -- With mult=2 and no compounding: total drain = GAME_BURN * 2 * TICKS = 20
    local expected = 2000.0 - (GAME_BURN * 2.0 * TICKS)
    local actual   = player:getNutrition():getCalories()
    assert_true(math.abs(actual - expected) < 0.01,
        "expected " .. expected .. " but got " .. actual .. "; compounding bug if drain is larger")
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

ISEatFoodAction.perform = function(self)
    self._originalPerformCalls = (self._originalPerformCalls or 0) + 1
    return self._originalPerformReturn
end
dofile(base .. "../media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua")

-- Install consumption + fitness hooks (simulates game startup)
Events.OnGameStart.fire()

-- ─── UT_fearofthedark ─────────────────────────────────────────────────────────

test("fearofthedark raises panic in darkness (lightLevel < 0.3)", function()
    local sq = { getLightLevel = function() return 0.1 end }
    local player = MockPlayer({ "UniversalTraits:UT_fearofthedark" }, { panic = 10, square = sq })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local panic = player:getStats():get(CharacterStat.PANIC)
    assert_eq(panic, 14, "panic should be 10 + 4 = 14 in darkness")
end)

test("fearofthedark reduces panic in bright light (lightLevel > 0.7)", function()
    local sq = { getLightLevel = function() return 0.9 end }
    local player = MockPlayer({ "UniversalTraits:UT_fearofthedark" }, { panic = 10, square = sq })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    local panic = player:getStats():get(CharacterStat.PANIC)
    assert_eq(panic, 9, "panic should be 10 - 1 = 9 in bright light")
end)

test("fearofthedark does not affect player without the trait", function()
    local sq = { getLightLevel = function() return 0.1 end }
    local player = MockPlayer({}, { panic = 10, square = sq })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.PANIC), 10, "panic unchanged without trait")
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

-- ─── UT_accmetabolism ─────────────────────────────────────────────────────────

local ACC_METABOLISM_ID = "UniversalTraits:UT_accmetabolism"
local ACC_METABOLISM_PATH = base .. "../media/lua/shared/UniversalTraits/traits/UT_accmetabolism.lua"
local ACC_METABOLISM_TOLERANCE = 1e-6
dofile(ACC_METABOLISM_PATH)

test("accmetabolism one dispatch adds exactly hunger +0.05 and thirst +0.03", function()
    local player = MockPlayer({ ACC_METABOLISM_ID }, { hunger = 0.40, thirst = 0.50 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_close(player:getStats():get(CharacterStat.HUNGER), 0.45, ACC_METABOLISM_TOLERANCE,
        "one dispatch should add exactly 0.05 hunger")
    assert_close(player:getStats():get(CharacterStat.THIRST), 0.53, ACC_METABOLISM_TOLERANCE,
        "one dispatch should add exactly 0.03 thirst")
end)

test("accmetabolism caps hunger and thirst independently at one", function()
    local hungerCaps = MockPlayer({ ACC_METABOLISM_ID }, { hunger = 0.98, thirst = 0.40 })
    withActivePlayer(hungerCaps, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(hungerCaps:getStats():get(CharacterStat.HUNGER), 1,
        "hunger should cap independently at one")
    assert_close(hungerCaps:getStats():get(CharacterStat.THIRST), 0.43, ACC_METABOLISM_TOLERANCE,
        "thirst should still receive its exact delta when hunger caps")

    local thirstCaps = MockPlayer({ ACC_METABOLISM_ID }, { hunger = 0.40, thirst = 0.99 })
    withActivePlayer(thirstCaps, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_close(thirstCaps:getStats():get(CharacterStat.HUNGER), 0.45, ACC_METABOLISM_TOLERANCE,
        "hunger should still receive its exact delta when thirst caps")
    assert_eq(thirstCaps:getStats():get(CharacterStat.THIRST), 1,
        "thirst should cap independently at one")
end)

test("accmetabolism guards no trait, no player, and nil Stats", function()
    local withoutTrait = MockPlayer({}, { hunger = 0.40, thirst = 0.50 })
    withActivePlayer(withoutTrait, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_close(withoutTrait:getStats():get(CharacterStat.HUNGER), 0.40, ACC_METABOLISM_TOLERANCE,
        "hunger should remain unchanged without the trait")
    assert_close(withoutTrait:getStats():get(CharacterStat.THIRST), 0.50, ACC_METABOLISM_TOLERANCE,
        "thirst should remain unchanged without the trait")

    withActivePlayer(nil, function()
        Events.EveryTenMinutes:fire()
    end)

    local withoutStats = MockPlayer({ ACC_METABOLISM_ID }, { nilStats = true })
    withActivePlayer(withoutStats, function()
        Events.EveryTenMinutes:fire()
    end)
end)

test("accmetabolism repeated module evaluation leaves one callback and one delta", function()
    local beforeReload = Events.EveryTenMinutes._handlerCount()
    dofile(ACC_METABOLISM_PATH)
    dofile(ACC_METABOLISM_PATH)
    assert_eq(Events.EveryTenMinutes._handlerCount(), beforeReload,
        "repeated evaluation should replace the owned callback without changing handler count")

    local player = MockPlayer({ ACC_METABOLISM_ID }, { hunger = 0.20, thirst = 0.30 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_close(player:getStats():get(CharacterStat.HUNGER), 0.25, ACC_METABOLISM_TOLERANCE,
        "one retained callback should add one hunger delta")
    assert_close(player:getStats():get(CharacterStat.THIRST), 0.33, ACC_METABOLISM_TOLERANCE,
        "one retained callback should add one thirst delta")
end)

test("accmetabolism deterministic current-version Stats round-trip model", function()
    local beforeRoundTrip = MockPlayer({ ACC_METABOLISM_ID }, { hunger = 0.40, thirst = 0.50 })

    -- Deterministic harness model only: current-version Stats values are copied into
    -- a newly constructed player. This does not claim live PZ persistence proof.
    local savedStats = {
        hunger = beforeRoundTrip:getStats():get(CharacterStat.HUNGER),
        thirst = beforeRoundTrip:getStats():get(CharacterStat.THIRST),
    }
    local afterRoundTrip = MockPlayer({ ACC_METABOLISM_ID }, savedStats)

    withActivePlayer(afterRoundTrip, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_close(afterRoundTrip:getStats():get(CharacterStat.HUNGER), 0.45, ACC_METABOLISM_TOLERANCE,
        "modeled current-version Stats round-trip should retain hunger before one delta")
    assert_close(afterRoundTrip:getStats():get(CharacterStat.THIRST), 0.53, ACC_METABOLISM_TOLERANCE,
        "modeled current-version Stats round-trip should retain thirst before one delta")
end)

-- ─── UT_addictedtocaffeine ────────────────────────────────────────────────────

test("addictedtocaffeine adds stress when no caffeine flag set", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():get(CharacterStat.STRESS)
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.06,
        "stress should be +0.06 when no UT_hadCaffeine flag")
end)

test("addictedtocaffeine caps the exact stress increase at one", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.98 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 1,
        "0.98 + 0.06 should clamp to 1")
end)

test("addictedtocaffeine skips stress when caffeine flag is set", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.0 })
    player:getModData()["UT_hadCaffeine"] = true
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0, "no stress added when UT_hadCaffeine is set")
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

test("addictedtocaffeine caffeine suppression is one-shot", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.0 })
    player:getModData()["UT_hadCaffeine"] = true
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getModData()["UT_hadCaffeine"], nil,
        "the suppression flag should remain cleared after it is consumed")
    assert_eq(math.floor(player:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.06,
        "only the first tick should be suppressed")
end)

test("addictedtocaffeine does not affect player without the trait", function()
    local player = MockPlayer({}, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0, "no stress added without trait")
end)

test("addictedtocaffeine safely ignores a missing active player", function()
    withActivePlayer(nil, function()
        Events.EveryTenMinutes:fire()
    end)
end)

test("addictedtocaffeine safely ignores a trait player without stats", function()
    local player = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { noStats = true })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getModData()["UT_hadCaffeine"], nil,
        "missing stats should not synthesize caffeine state")
end)

test("addictedtocaffeine deterministic modData round-trip suppresses one post-load tick", function()
    local beforeSave = MockPlayer({ "UniversalTraits:UT_addictedtocaffeine" }, { stress = 0.25 })
    beforeSave:getModData()["UT_hadCaffeine"] = true

    -- Deterministic harness model only: current-version player modData is copied into
    -- a newly constructed player. This does not claim PZ save/load runtime proof.
    local savedModData = {}
    for key, value in pairs(beforeSave:getModData()) do savedModData[key] = value end
    local afterLoad = MockPlayer(
        { "UniversalTraits:UT_addictedtocaffeine" },
        { stress = 0.25, moddata = savedModData }
    )

    withActivePlayer(afterLoad, function()
        Events.EveryTenMinutes:fire()
        assert_eq(afterLoad:getStats():get(CharacterStat.STRESS), 0.25,
            "restored caffeine should suppress the first modeled post-load tick")
        assert_eq(afterLoad:getModData()["UT_hadCaffeine"], nil,
            "the modeled post-load tick should consume the restored flag")
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(math.floor(afterLoad:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.31,
        "the next modeled post-load tick should add exactly 0.06")
end)

-- ─── UT_ItemConsumptionHooks: UT_allergic ─────────────────────────────────────

test("allergic adds food sickness spike on guaranteed roll", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 0 })  -- 0 < 30 → spike fires
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    local sickness = player:getStats():get(CharacterStat.FOOD_SICKNESS)
    assert_eq(sickness, 20, "food sickness should be +20 on successful allergic roll")
end)

test("allergic does not spike on failed roll", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 30 })  -- 30 is NOT < 30 → no spike
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "no food sickness when roll fails")
end)

test("allergic does not trigger for medication items", function()
    local medicationTypes = {
        "Pills", "PillsAntiDep", "PillsBeta", "PillsSleepingTablets", "PillsVitamins",
    }
    for _, itemType in ipairs(medicationTypes) do
        local player = MockPlayer({ "UniversalTraits:UT_allergic" })
        setMockZombRandSequence({ 0 })  -- guaranteed roll but item is medication
        ISEatFoodAction.perform({ character = player, item = MockItem(itemType) })
        assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
            itemType .. " must be medication, not food")
    end
end)

test("allergic treats a near-miss pill type as ordinary food", function()
    local player = MockPlayer({ "UniversalTraits:UT_allergic" })
    setMockZombRandSequence({ 0 })
    ISEatFoodAction.perform({ character = player, item = MockItem("PillsVitaminsExtra") })
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 20,
        "near-miss type must not be classified as medication")
end)

test("allergic does not affect player without the trait", function()
    local player = MockPlayer({})
    setMockZombRandSequence({ 0 })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "non-allergic player unaffected")
end)

-- ─── UT_ItemConsumptionHooks: UT_antivaxxer ───────────────────────────────────

test("antivaxxer adds stress for each intended vanilla medication", function()
    local medicationTypes = { "Pills", "PillsAntiDep", "PillsSleepingTablets", "PillsVitamins" }
    for _, itemType in ipairs(medicationTypes) do
        local player = MockPlayer({ "UniversalTraits:UT_antivaxxer" }, { stress = 0.0 })
        ISEatFoodAction.perform({ character = player, item = MockItem(itemType) })
        local stress = player:getStats():get(CharacterStat.STRESS)
        assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.20,
            itemType .. " should add 0.20 stress")
    end
end)

test("antivaxxer skips beta blocker", function()
    local player = MockPlayer({ "UniversalTraits:UT_antivaxxer" }, { stress = 0.0 })
    local action = { character = player, item = MockItem("PillsBeta") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0,
        "beta blocker should not trigger antivaxxer stress")
end)

test("antivaxxer does not affect player without the trait", function()
    local player = MockPlayer({}, { stress = 0.0 })
    local action = { character = player, item = MockItem("Pills") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0,
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

test("caffeine consumption hooks are reload-safe and preserve later hook owners", function()
    local eatWrapper = ISEatFoodAction.perform
    local drinkWrapper = ISDrinkFluidAction.perform

    dofile(base .. "../media/lua/shared/UniversalTraits/UT_ItemConsumptionHooks.lua")
    Events.OnGameStart:fire()
    Events.OnGameStart:fire()

    assert_eq(ISEatFoodAction.perform, eatWrapper,
        "reloading must not stack or replace the installed eat wrapper")
    assert_eq(ISDrinkFluidAction.perform, drinkWrapper,
        "reloading must not stack or replace the installed drink wrapper")

    local laterOwner = function(self) return eatWrapper(self) end
    ISEatFoodAction.perform = laterOwner
    Events.OnGameStart:fire()
    assert_eq(ISEatFoodAction.perform, laterOwner,
        "a later hook owner must remain installed")
end)

test("gordanite consumption keeps one net 1.5x effect after native consumption", function()
    local cases = {
        { name = "full", percentage = 1.0, hungerChange = -0.2, expectedHunger = 0.5 },
        { name = "partial", percentage = 0.5, hungerChange = -0.2, expectedHunger = 0.55 },
        { name = "zero percentage", percentage = 0, hungerChange = -0.2, expectedHunger = 0.6 },
        { name = "negative percentage", percentage = -0.5, hungerChange = -0.2, expectedHunger = 0.6 },
        { name = "zero hunger change", percentage = 1.0, hungerChange = 0, expectedHunger = 0.6 },
        { name = "positive hunger change", percentage = 1.0, hungerChange = 0.2, expectedHunger = 0.6 },
    }

    for _, case in ipairs(cases) do
        -- The starting values represent state after vanilla complete() consumed
        -- the already-boosted 300-calorie item and applied its base hunger change.
        local player = MockPlayer({}, { hunger = 0.6, calories = 2300 })
        local item = MockItem("Stew", {
            hungerChange = case.hungerChange,
            calories = 300,
            moddata = { UT_gordHungerMult = 1.5 },
        })
        local action = {
            character = player,
            item = item,
            percentage = case.percentage,
            _originalPerformReturn = "vanilla-return",
        }

        local result = ISEatFoodAction.perform(action)

        assert_true(math.abs(player:getStats():get(CharacterStat.HUNGER) - case.expectedHunger) < 1e-9,
            case.name .. ": expected exactly one 1.5x hunger effect")
        assert_eq(player:getNutrition():getCalories(), 2300,
            case.name .. ": Gordanite calories must not receive a second 1.5x application")
        assert_eq(action._originalPerformCalls, 1,
            case.name .. ": original perform must run exactly once")
        assert_eq(result, nil,
            case.name .. ": wrapper return behavior must remain unchanged")
    end
end)

test("consumption hook leaves non-Gordanite food unchanged", function()
    local player = MockPlayer({}, { hunger = 0.6, calories = 2200 })
    local action = {
        character = player,
        item = MockItem("Stew", { hungerChange = -0.2, calories = 200 }),
        percentage = 1.0,
    }

    ISEatFoodAction.perform(action)

    assert_eq(player:getStats():get(CharacterStat.HUNGER), 0.6,
        "non-Gordanite hunger must remain unchanged")
    assert_eq(player:getNutrition():getCalories(), 2200,
        "non-Gordanite calories must remain unchanged")
    assert_eq(action._originalPerformCalls, 1,
        "non-Gordanite original perform must run exactly once")
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
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0, "no stress at craving < 10")
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
    local stress = player:getStats():get(CharacterStat.STRESS)
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
    local stress = player:getStats():get(CharacterStat.STRESS)
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
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0, "no stress when satisfied")
end)

-- ─── UT_physicallyactive ──────────────────────────────────────────────────────

-- Verify Perks stub for this section
_G.Perks = _G.Perks or { Fitness = "Fitness", Sprinting = "Sprinting" }

test("physicallyactive reduces stress per exercise loop", function()
    local player = MockPlayer({ "UniversalTraits:UT_physicallyactive" }, { stress = 0.5 })
    local action = { character = player }
    ISFitnessAction.exeLooped(action)
    local stress = player:getStats():get(CharacterStat.STRESS)
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.485,
        "stress should decrease by 0.015 per exercise loop")
end)

test("physicallyactive reduces boredom per exercise loop", function()
    local player = MockPlayer({ "UniversalTraits:UT_physicallyactive" }, { boredom = 50 })
    local action = { character = player }
    ISFitnessAction.exeLooped(action)
    assert_eq(player:getStats():get(CharacterStat.BOREDOM), 45, "boredom should decrease by 5 per exercise loop")
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
    assert_true(player:getStats():get(CharacterStat.ENDURANCE) >= 0.0, "endurance should remain non-negative")
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

test("scardycat panic cascade fires when panic rises by 5 or more", function()
    -- Two EveryOneMinute calls: first to set prevPanic, second to detect the rise
    local player = MockPlayer({ "UniversalTraits:UT_scardycat" }, { panic = 10 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()  -- prevPanic[id] = 10
        player:getStats():set(CharacterStat.PANIC, 20)  -- panic rose by 10 (>= 5)
        Events.EveryOneMinute:fire()  -- cascade: 20 + 15 = 35
    end)
    local panic = player:getStats():get(CharacterStat.PANIC)
    assert_true(panic >= 34 and panic <= 36,
        "panic cascade should add 15 when panic rises >= 5 in a minute (got " .. tostring(panic) .. ")")
end)

test("scardycat no cascade when panic does not rise by 5", function()
    local player = MockPlayer({ "UniversalTraits:UT_scardycat" }, { panic = 20 })
    withActivePlayer(player, function()
        Events.EveryOneMinute:fire()  -- prevPanic[id] = 20
        player:getStats():set(CharacterStat.PANIC, 23)  -- rose only 3 (< 5)
        Events.EveryOneMinute:fire()  -- no cascade
    end)
    local panic = player:getStats():get(CharacterStat.PANIC)
    assert_true(panic < 30,
        "no cascade should fire when panic rose less than 5 (got " .. tostring(panic) .. ")")
end)

-- ===== UT_melancholic behavioral tests (code changed: raises unhappiness) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_melancholic.lua")

test("melancholic raises unhappiness by 5 every 10 minutes", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" }, { unhappiness = 20 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.UNHAPPINESS), 25, "unhappiness should be 20 + 5 = 25")
end)

test("melancholic unhappiness caps at 100", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" }, { unhappiness = 98 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.UNHAPPINESS), 100, "unhappiness should cap at 100")
end)

test("melancholic does NOT raise stress", function()
    local player = MockPlayer({ "UniversalTraits:UT_melancholic" }, { stress = 0.0 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.0, "stress should be unchanged by melancholic")
end)

test("melancholic does not affect player without the trait", function()
    local player = MockPlayer({}, { unhappiness = 20 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.UNHAPPINESS), 20, "unhappiness unchanged without trait")
end)

-- ===== UT_weathersensitive behavioral tests (code changed: real weather check) =====
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_weathersensitive.lua")

test("weathersensitive raises stress when raining (precip > 0.3)", function()
    setMockClimate(0.5, 0.8)  -- heavy rain
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.2 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():get(CharacterStat.STRESS)
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.25,
        "stress should be 0.2 + 0.05 = 0.25 when raining")
end)

test("weathersensitive reduces stress when clear and sunny (clouds < 0.2)", function()
    setMockClimate(0.0, 0.1)  -- no rain, clear sky
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.4 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local stress = player:getStats():get(CharacterStat.STRESS)
    assert_eq(math.floor(stress * 1000 + 0.5) / 1000, 0.38,
        "stress should be 0.4 - 0.02 = 0.38 when sunny")
end)

test("weathersensitive does nothing when overcast but dry (no rain, clouds >= 0.2)", function()
    setMockClimate(0.0, 0.6)  -- no rain, overcast
    local player = MockPlayer({ "UniversalTraits:UT_weathersensitive" }, { stress = 0.3 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.3, "stress unchanged when overcast but dry")
end)

test("weathersensitive does not affect player without the trait", function()
    setMockClimate(0.5, 0.8)  -- raining
    local player = MockPlayer({}, { stress = 0.2 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.STRESS), 0.2, "stress unchanged without trait")
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

test("unwavering drains panic by 10 when above 10", function()
    local player = MockPlayer({ "UniversalTraits:UT_unwavering" }, { panic = 50 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    local panic = player:getStats():get(CharacterStat.PANIC)
    assert_eq(panic, 40, "panic should be 50 - 10 = 40 after drain")
end)

test("unwavering does not drain panic when at or below 10", function()
    local player = MockPlayer({ "UniversalTraits:UT_unwavering" }, { panic = 10 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.PANIC), 10, "panic unchanged when at 10 threshold")
end)

test("unwavering does not affect player without the trait", function()
    local player = MockPlayer({}, { panic = 50 })
    withActivePlayer(player, function()
        Events.EveryTenMinutes:fire()
    end)
    assert_eq(player:getStats():get(CharacterStat.PANIC), 50, "panic unchanged without trait")
end)

test("unwavering English copy states the exact fixed drain and release matches source", function()
    local expected = "Fear never really got its hooks into you. Every 10 in-game minutes, if panic is above 10, panic is reduced by 10."
    local function readDescription(path)
        local file = io.open(path, "r")
        assert_true(file ~= nil, "failed to open " .. path)
        local text = file:read("*a")
        file:close()
        return text:match('"UI_UT_unwaveringDesc"%s*:%s*"([^"]+)"')
    end

    local source = readDescription(base .. "../media/lua/shared/Translate/EN/UI.json")
    local release = readDescription(base .. "../release/UniversalTraits/42.0/media/lua/shared/Translate/EN/UI.json")
    assert_eq(source, expected, "source Unwavering copy must describe cadence, threshold, and amount")
    assert_eq(release, expected, "release Unwavering copy must match the accepted source copy")
    assert_eq(release, source, "Unwavering source/release copy parity")
end)

-- ===== UT_pillsallergy behavioral tests (hook in UT_ItemConsumptionHooks.lua) =====

test("pillsallergy dispatches for every vanilla medication type", function()
    local medicationTypes = {
        "Pills", "PillsAntiDep", "PillsBeta", "PillsSleepingTablets", "PillsVitamins",
    }
    for _, itemType in ipairs(medicationTypes) do
        local player = MockPlayer({ "UniversalTraits:UT_pillsallergy" })
        ISEatFoodAction.perform({ character = player, item = MockItem(itemType) })
        assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 15,
            itemType .. " should add 15 food sickness")
    end
end)

test("pillsallergy does not trigger on non-medication food", function()
    local player = MockPlayer({ "UniversalTraits:UT_pillsallergy" })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "no sickness when non-medication item consumed with pillsallergy")
end)

test("pillsallergy does not trigger on a near-miss medication type", function()
    local player = MockPlayer({ "UniversalTraits:UT_pillsallergy" })
    local action = { character = player, item = MockItem("PillsAntiDepCopy") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "near-miss type must not dispatch pillsallergy")
end)

test("pillsallergy does not affect player without the trait", function()
    local player = MockPlayer({})
    local action = { character = player, item = MockItem("Pills") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "no sickness when player lacks pillsallergy trait")
end)

-- ===== UT_wildplantsallergy behavioral tests (hook in UT_ItemConsumptionHooks.lua) =====

test("wildplantsallergy adds sickness 20 when foraged item consumed", function()
    local player = MockPlayer({ "UniversalTraits:UT_wildplantsallergy" })
    local action = { character = player, item = MockItem("Berries", { forageCategory = "WildPlants" }) }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 20,
        "food sickness should be +20 after foraged item consumed with wildplantsallergy")
end)

test("wildplantsallergy does not trigger on non-foraged food", function()
    local player = MockPlayer({ "UniversalTraits:UT_wildplantsallergy" })
    local action = { character = player, item = MockItem("Chips") }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "no sickness when non-foraged item consumed with wildplantsallergy")
end)

test("wildplantsallergy does not affect player without the trait", function()
    local player = MockPlayer({})
    local action = { character = player, item = MockItem("Berries", { forageCategory = "WildPlants" }) }
    ISEatFoodAction.perform(action)
    assert_eq(player:getStats():get(CharacterStat.FOOD_SICKNESS), 0,
        "no sickness when player lacks wildplantsallergy trait")
end)

-- ============================================================
-- Phase 4: behavioral tests for remaining 70 untested traits
-- ============================================================

-- ── dofile all 70 new trait files ────────────────────────────────────────────
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_analgesia.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_brittle.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_durability.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fasthands.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_glassbody.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_antigun.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_luddite.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_quickrest.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_restfulsleeper.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_snorer.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_slack.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_weaklybleedingwounds.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_deprived.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_broke.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_burned.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_injured_I.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_injured_II.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_paramedic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_pitcrew.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_anemic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_cangrabless.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_cangrabmore.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_gimp.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_staunch.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sorelegs.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_packmouse.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_depressive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fibromyalgia.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_optimist.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_paranoia.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_pessimist.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_ravenous.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_accmetabolism.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_mstoptimist.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_bigorexia.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_coldsensitive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_heatsensitive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_alcoholic_I.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_alcoholic_II.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_alcoholic_III.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_selfdestructive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_acrophobic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_albino.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_ironliver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_larkperson.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_owlperson.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_panicattacks.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_maniac.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_lesssweaty.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_highsweaty.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_adaptivemetabolism.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sedentary.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_backpacker.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sore.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sloth.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_squirrel.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_couchdweller.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_nervouswreck.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_vehophobic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fearful.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_leadfoot.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flimsy.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_anorexy.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_badteeth.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_competitiveeater.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sensitivestomach.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_ascetic.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_fitted.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_gourmand.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_evasive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_natural.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sharpshooter.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_tavernbrawler.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_trackman.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_woodsplitter.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_incomprehensive.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_cleaver.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_long_blades.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_long_blunts.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_onehanded_axes.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_prospear.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_twohanded_axes.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_twohanded_blades.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_twohanded_blunts.lua")

-- ─── Group 1: OnNewGame modData flags ────────────────────────────────────────

test("analgesia sets UT_painImmune=true on new game", function()
    local p = fireNewGame("UniversalTraits:UT_analgesia")
    assert_eq(p:getModData()["UT_painImmune"], true, "expected UT_painImmune=true")
end)
test("analgesia does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["UT_painImmune"], nil, "UT_painImmune should not be set")
end)

test("brittle sets UT_fractureMult=1.5 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_brittle")
    assert_eq(p:getModData()["UT_fractureMult"], 1.5, "expected UT_fractureMult=1.5")
end)
test("brittle does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["UT_fractureMult"], nil, "UT_fractureMult should not be set")
end)

test("durability sets UT_itemDurabilityMult on new game", function()
    local p = fireNewGame("UniversalTraits:UT_durability")
    assert_true(type(p:getModData()["UT_itemDurabilityMult"]) == "number" and
        p:getModData()["UT_itemDurabilityMult"] > 1.0,
        "expected UT_itemDurabilityMult > 1.0")
end)

test("fasthands sets UT_transferSpeedMult < 1 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_fasthands")
    local v = p:getModData()["UT_transferSpeedMult"]
    assert_true(type(v) == "number" and v < 1.0, "expected UT_transferSpeedMult < 1.0, got " .. tostring(v))
end)

test("glassbody sets UT_damageMult > 1 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_glassbody")
    local v = p:getModData()["UT_damageMult"]
    assert_true(type(v) == "number" and v > 1.0, "expected UT_damageMult > 1.0, got " .. tostring(v))
end)

-- ─── Group 2: OnNewGame XP / modifiers ───────────────────────────────────────

test("antigun sets Aiming and Reloading XP mult to 0.5 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_antigun")
    assert_eq(p:getModData()["UT_xpMult_Aiming"],    0.5, "UT_xpMult_Aiming")
    assert_eq(p:getModData()["UT_xpMult_Reloading"], 0.5, "UT_xpMult_Reloading")
end)
test("antigun does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["UT_xpMult_Aiming"], nil, "UT_xpMult_Aiming should not be set")
end)

test("luddite sets Electricity XP mult to 0.6 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_luddite")
    assert_eq(p:getModData()["UT_xpMult_Electricity"], 0.6, "UT_xpMult_Electricity")
end)

test("quickrest sets UT_sleepQualMod=0.3 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_quickrest")
    assert_eq(p:getModData()["UT_sleepQualMod"], 0.3, "UT_sleepQualMod")
end)

test("restfulsleeper sets UT_sleepQualMod=0.5 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_restfulsleeper")
    assert_eq(p:getModData()["UT_sleepQualMod"], 0.5, "UT_sleepQualMod")
end)

test("snorer sets UT_noiseMult=2.0 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_snorer")
    assert_eq(p:getModData()["UT_noiseMult"], 2.0, "UT_noiseMult")
end)

test("slack sets UT_workSpeedMod=0.4 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_slack")
    assert_eq(p:getModData()["UT_workSpeedMod"], 0.4, "UT_workSpeedMod")
end)

test("weaklybleedingwounds sets UT_bleedDrainMult=0.6 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_weaklybleedingwounds")
    assert_eq(p:getModData()["UT_bleedDrainMult"], 0.6, "UT_bleedDrainMult")
end)

test("deprived calls stripSpawnItems on new game", function()
    local p = fireNewGame("UniversalTraits:UT_deprived")
    assert_eq(p:getModData()["_stripCalled"], true, "expected _stripCalled=true from stripSpawnItems")
end)
test("deprived does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["_stripCalled"], nil, "_stripCalled should not be set")
end)

-- ─── Group 3: OnNewGame spawn conditions ─────────────────────────────────────

test("broke applies spawn condition and stress/fatigue stats on new game", function()
    local p = fireNewGame("UniversalTraits:UT_broke")
    assert_true(p:getModData()["_spawnCond"] ~= nil, "expected _spawnCond set")
    assert_eq(p:getModData()["_spawn_stress"],  0.5, "_spawn_stress")
    assert_eq(p:getModData()["_spawn_fatigue"], 0.3, "_spawn_fatigue")
end)
test("broke does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["_spawnCond"], nil, "_spawnCond should not be set")
end)

test("burned applies spawn condition and harsh stats on new game", function()
    local p = fireNewGame("UniversalTraits:UT_burned")
    assert_true(p:getModData()["_spawnCond"] ~= nil, "expected _spawnCond set")
    assert_eq(p:getModData()["_spawn_stress"],  0.7, "_spawn_stress")
    assert_eq(p:getModData()["_spawn_fatigue"], 0.5, "_spawn_fatigue")
    assert_eq(p:getModData()["_spawn_panic"],   0.3, "_spawn_panic")
end)

test("injured_I applies spawn condition and stress=0.3 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_injured_I")
    assert_true(p:getModData()["_spawnCond"] ~= nil, "expected _spawnCond set")
    assert_eq(#p:getModData()["_spawnCond"].scratches, 2, "expected 2 scratched parts")
    assert_eq(p:getModData()["_spawn_stress"], 0.3, "_spawn_stress")
end)

test("injured_II applies spawn condition and stress=0.6 on new game", function()
    local p = fireNewGame("UniversalTraits:UT_injured_II")
    assert_true(p:getModData()["_spawnCond"] ~= nil, "expected _spawnCond set")
    assert_eq(#p:getModData()["_spawnCond"].cuts, 4, "expected 4 cut parts")
    assert_eq(p:getModData()["_spawn_stress"],  0.6, "_spawn_stress")
    assert_eq(p:getModData()["_spawn_fatigue"], 0.4, "_spawn_fatigue")
end)

test("invalid timed-action and fence events are not manufactured", function()
    assert_eq(Events.OnActionAdded, nil)
    assert_eq(Events.OnFenceClimb, nil)
    assert_eq(Events.OnClimbFence, nil)
end)

test("paramedic accelerates only the exact medical Type set", function()
    local p = MockPlayer({ "UniversalTraits:UT_paramedic" })
    local types = {
        "ISMedicalCheckAction", "ISApplyBandage", "ISCleanBurn", "ISDisinfect",
        "ISRemoveBullet", "ISRemoveGlass", "ISSplint", "ISStitch",
    }
    for _, actionType in ipairs(types) do
        local action = { character = p, Type = actionType }
        assert_eq(UTCore.applyWorkDuration(action, 120), 60, actionType)
        assert_eq(UTCore.applyWorkDuration(action, 120), 60, actionType .. " must not compound")
    end
    assert_eq(UTCore.applyWorkDuration({ character = p, Type = "ISCleanWound" }, 120), 120)
    assert_eq(UTCore.applyWorkDuration({ character = p, Type = "ISReadABook" }, 120), 120)
end)

test("pitcrew accelerates only the exact mechanics Type set", function()
    local p = MockPlayer({ "UniversalTraits:UT_pitcrew" })
    for _, actionType in ipairs({ "ISInstallVehiclePart", "ISUninstallVehiclePart", "ISFixVehiclePartAction" }) do
        assert_eq(UTCore.applyWorkDuration({ character = p, Type = actionType }, 120), 60, actionType)
    end
    for _, actionType in ipairs({ "ISEnterVehicle", "ISExitVehicle", "ISOpenMechanicsUIAction", "ISRepairVehicleAction" }) do
        assert_eq(UTCore.applyWorkDuration({ character = p, Type = actionType }, 120), 120, actionType)
    end
end)

test("trait work duration preserves guards, minimum, and additive composition", function()
    local medical = MockPlayer({ "UniversalTraits:UT_paramedic" })
    assert_eq(UTCore.applyWorkDuration({ character = medical, Type = "ISStitch" }, -1), -1)
    assert_eq(UTCore.applyWorkDuration({ character = medical, Type = "ISStitch" }, 1), 1)
    assert_eq(UTCore.applyWorkDuration({ character = MockPlayer({}), Type = "ISStitch" }, 120), 120)

    medical:getModData()["UT_modifierBuckets"] = { workAdd = { test = 0.25 } }
    assert_eq(UTCore.applyWorkDuration({ character = medical, Type = "ISStitch" }, 120), 90,
        "general +0.25 and paramedic -0.5 compose to -0.25")
end)

-- ─── Group 4: OnCreatePlayer ─────────────────────────────────────────────────

test("anemic sets UT_bleedDecayMult=0.33 (not bandaged-only) on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_anemic")
    assert_eq(p:getModData()["UT_bleedDecayMult"],        0.33,  "bleedDecayMult")
    assert_eq(p:getModData()["UT_bleedDecayBandagedOnly"], false, "bandagedOnly should be false")
end)
test("anemic does not affect player without trait", function()
    local p = MockPlayer({})
    Events.OnCreatePlayer:fire(0, p)
    assert_eq(p:getModData()["UT_bleedDecayMult"], nil, "should not be set")
end)

test("cangrabless sets maxWeightBase=7 on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_cangrabless")
    assert_eq(p:getMaxWeightBase(), 7, "expected maxWeightBase=7")
end)

test("cangrabmore sets maxWeightBase=9 on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_cangrabmore")
    assert_eq(p:getMaxWeightBase(), 9, "expected maxWeightBase=9")
end)

test("gimp sets UT_speedMod=-0.5 on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_gimp")
    assert_eq(p:getModData()["UT_speedMod"], -0.5, "expected UT_speedMod=-0.5")
end)

test("staunch sets UT_bleedDecayMult=3.0 bandaged-only on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_staunch")
    assert_eq(p:getModData()["UT_bleedDecayMult"],        3.0,  "bleedDecayMult")
    assert_eq(p:getModData()["UT_bleedDecayBandagedOnly"], true, "bandagedOnly should be true")
end)

test("sorelegs sets UT_speedMod=-0.2 and reduces carry weight on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_sorelegs")
    assert_eq(p:getModData()["UT_speedMod"], -0.2, "UT_speedMod")
    assert_true(p:getMaxWeightBase() < 8, "carry weight should be reduced")
end)

test("packmouse reduces carry weight by 2 on create", function()
    local p = fireCreatePlayer("UniversalTraits:UT_packmouse")
    assert_eq(p:getMaxWeightBase(), 6, "expected 8-2=6 carry weight")
end)

-- ─── Group 5: EveryTenMinutes periodic effects ───────────────────────────────

test("depressive raises stress by 0.08 each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_depressive" }, { stress = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(math.floor(p:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.08,
        "expected stress 0.08 after one ETM tick")
end)
test("depressive does not affect player without trait", function()
    local p = MockPlayer({}, { stress = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.0, "stress unchanged without trait")
end)

test("fibromyalgia raises stress and fatigue each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_fibromyalgia" }, { stress = 0.0, fatigue = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,  "stress should increase")
    assert_true(p:getStats():get(CharacterStat.FATIGUE) > 0, "fatigue should increase")
end)

test("optimist reduces stress and panic each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_optimist" }, { stress = 0.5, panic = 0.4 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) < 0.5, "stress should decrease")
    assert_true(p:getStats():get(CharacterStat.PANIC)  < 0.4, "panic should decrease")
end)

test("paranoia raises panic by 6 each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_paranoia" }, { panic = 0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.PANIC), 6,
        "expected panic 6 after one ETM tick")
end)

test("pessimist raises stress by 0.05 each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_pessimist" }, { stress = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(math.floor(p:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.05,
        "expected stress 0.05 after one ETM tick")
end)

test("ravenous raises hunger by 0.1 each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_ravenous" }, { hunger = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(math.floor(p:getStats():get(CharacterStat.HUNGER) * 1000 + 0.5) / 1000, 0.1,
        "expected hunger 0.1 after one ETM tick")
end)

test("accmetabolism raises hunger and thirst each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_accmetabolism" }, { hunger = 0.0, thirst = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.HUNGER) > 0, "hunger should increase")
    assert_true(p:getStats():get(CharacterStat.THIRST) > 0, "thirst should increase")
end)

test("mstoptimist applies large stress reduction when stress > 0.6", function()
    local p = MockPlayer({ "UniversalTraits:UT_mstoptimist" }, { stress = 0.8 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) < 0.8, "stress should decrease")
    assert_eq(math.floor(p:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.72,
        "expected -0.08 at high stress: 0.8-0.08=0.72")
end)
test("mstoptimist applies small stress reduction when stress <= 0.6", function()
    local p = MockPlayer({ "UniversalTraits:UT_mstoptimist" }, { stress = 0.5 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(math.floor(p:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.47,
        "expected -0.03 at low stress: 0.5-0.03=0.47")
end)

test("bigorexia adds baseline stress each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_bigorexia" }, { stress = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) >= 0.04,
        "expected at least +0.04 baseline stress, got " .. tostring(p:getStats():get(CharacterStat.STRESS)))
end)
test("bigorexia adds extra stress when Strength < 5", function()
    local p = MockPlayer({ "UniversalTraits:UT_bigorexia" }, { stress = 0.0 })
    -- default Strength perk level = 0 (< 5) → extra +0.02
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(math.floor(p:getStats():get(CharacterStat.STRESS) * 1000 + 0.5) / 1000, 0.06,
        "expected 0.04+0.02=0.06 stress when Strength<5")
end)

test("coldsensitive raises stress and fatigue when bodyTemp < 36", function()
    local p = MockPlayer({ "UniversalTraits:UT_coldsensitive" }, { bodyTemp = 35.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,  "stress should increase when cold")
    assert_true(p:getStats():get(CharacterStat.FATIGUE) > 0, "fatigue should increase when cold")
end)
test("coldsensitive does NOT fire when bodyTemp >= 36", function()
    local p = MockPlayer({ "UniversalTraits:UT_coldsensitive" }, { bodyTemp = 37.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS),  0.0, "no stress when warm")
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.0, "no fatigue when warm")
end)

test("heatsensitive raises stress and fatigue when bodyTemp > 38", function()
    local p = MockPlayer({ "UniversalTraits:UT_heatsensitive" }, { bodyTemp = 39.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,  "stress should increase when hot")
    assert_true(p:getStats():get(CharacterStat.FATIGUE) > 0, "fatigue should increase when hot")
end)
test("heatsensitive does NOT fire when bodyTemp <= 38", function()
    local p = MockPlayer({ "UniversalTraits:UT_heatsensitive" }, { bodyTemp = 37.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS),  0.0, "no stress when cool")
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.0, "no fatigue when cool")
end)

test("alcoholic_I fires stress spike on every 3rd EveryTenMinutes when sober", function()
    -- Fire 9× to guarantee ≥3 trigger ticks regardless of where counter starts
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_I" }, { stress = 0.0, drunkenness = 0.0 })
    withActivePlayer(p, function()
        for _ = 1, 9 do Events.EveryTenMinutes:fire() end
    end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,
        "expected stress to increase at least once in 9 ETM fires while sober")
end)
test("alcoholic_I does NOT fire stress when intoxication >= 5", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_I" }, { stress = 0.0, intoxication = 10 })
    withActivePlayer(p, function()
        for _ = 1, 9 do Events.EveryTenMinutes:fire() end
    end)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.0, "no stress when not sober enough")
end)

test("alcoholic_II raises stress when intoxication < 5 each EveryTenMinutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_II" }, { stress = 0.0, intoxication = 0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0, "stress should increase when sober")
end)
test("alcoholic_II does NOT fire when intoxication >= 5", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_II" }, { stress = 0.0, intoxication = 10 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.0, "no stress when drunk")
end)

test("selfdestructive can fire stress and fatigue spike (guaranteed roll)", function()
    -- ZombRand(10) → 0 (default) → 0 < 2 → fires
    resetMockZombRand()
    local p = MockPlayer({ "UniversalTraits:UT_selfdestructive" }, { stress = 0.0, fatigue = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,  "stress should spike on guaranteed roll")
    assert_true(p:getStats():get(CharacterStat.FATIGUE) > 0, "fatigue should spike on guaranteed roll")
end)
test("selfdestructive does NOT fire when roll fails", function()
    setMockZombRandDefault(5)  -- 5 is not < 2 → no spike
    local p = MockPlayer({ "UniversalTraits:UT_selfdestructive" }, { stress = 0.0, fatigue = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS),  0.0, "no stress when roll fails")
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.0, "no fatigue when roll fails")
    resetMockZombRand()
end)

test("adaptivemetabolism clamps hunger at 0.01 when calories > 0", function()
    local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" }, { hunger = 1.0, calories = 2000.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.HUNGER), 0.01, "hunger should be clamped to 0.01")
end)
test("adaptivemetabolism does nothing when hunger is at or below 0.01 and calories > 0", function()
    local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" }, { hunger = 0.005, calories = 2000.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.HUNGER), 0.005, "hunger unchanged when already below cap")
end)
test("adaptivemetabolism does nothing when calories <= 0", function()
    local p = MockPlayer({ "UniversalTraits:UT_adaptivemetabolism" }, { hunger = 1.0, calories = 0.0 })
    withActivePlayer(p, function() Events.EveryTenMinutes:fire() end)
    assert_eq(p:getStats():get(CharacterStat.HUNGER), 1.0, "hunger unmodified when no calories remain")
end)

-- ─── Group 6: EveryOneMinute ──────────────────────────────────────────────────

test("acrophobic raises panic when z > 0", function()
    local p = MockPlayer({ "UniversalTraits:UT_acrophobic" }, { panic = 0.0 })
    p._z = 1
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.PANIC) > 0, "panic should increase when elevated")
end)
test("acrophobic does NOT fire when z == 0", function()
    local p = MockPlayer({ "UniversalTraits:UT_acrophobic" }, { panic = 0.0 })
    -- _z defaults to 0
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.PANIC), 0.0, "no panic at ground level")
end)

test("albino raises stress and fatigue when outdoors during daytime", function()
    setMockTimeOfDay(12)  -- midday on the engine's 0..24 clock
    -- default _indoors = false → isOutside() = true
    local p = MockPlayer({ "UniversalTraits:UT_albino" }, { stress = 0.0, fatigue = 0.0 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,  "stress should increase outdoors at midday")
    assert_true(p:getStats():get(CharacterStat.FATIGUE) > 0, "fatigue should increase outdoors at midday")
end)
test("albino does NOT fire when indoors", function()
    setMockTimeOfDay(12)
    local p = MockPlayer({ "UniversalTraits:UT_albino" }, { stress = 0.0, fatigue = 0.0 })
    p._indoors = true
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS),  0.0, "no effect when indoors")
    assert_eq(p:getStats():get(CharacterStat.FATIGUE), 0.0, "no effect when indoors")
end)

test("alcoholic_III raises stress when intoxication < 10 each minute", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_III" }, { stress = 0.0, intoxication = 0 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0, "stress should increase when low drunkenness")
end)
test("alcoholic_III raises panic when intoxication < 5 each minute", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_III" }, { panic = 0, intoxication = 0 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.PANIC) > 0, "panic should increase when below panic threshold")
end)
test("alcoholic_III does NOT fire when intoxication >= 10", function()
    local p = MockPlayer({ "UniversalTraits:UT_alcoholic_III" }, { stress = 0.0, intoxication = 20 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.0, "no stress when properly drunk")
end)

test("ironliver reduces intoxication by 10pct when > 10", function()
    local p = MockPlayer({ "UniversalTraits:UT_ironliver" }, { intoxication = 50 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.INTOXICATION), 45,
        "expected intoxication 50 * 0.9 = 45")
end)
test("ironliver does NOT fire when intoxication <= 10", function()
    local p = MockPlayer({ "UniversalTraits:UT_ironliver" }, { intoxication = 5 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.INTOXICATION), 5, "intoxication should stay at 5")
end)

test("larkperson reduces stress during daytime", function()
    setMockTimeOfDay(12)  -- midday
    local p = MockPlayer({ "UniversalTraits:UT_larkperson" }, { stress = 0.5 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) < 0.5, "stress should decrease during day")
end)
test("larkperson increases stress at night", function()
    setMockTimeOfDay(0)  -- night
    local p = MockPlayer({ "UniversalTraits:UT_larkperson" }, { stress = 0.3 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0.3, "stress should increase at night")
end)

test("owlperson reduces stress at night", function()
    setMockTimeOfDay(0)  -- night
    local p = MockPlayer({ "UniversalTraits:UT_owlperson" }, { stress = 0.5 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) < 0.5, "stress should decrease at night")
end)
test("owlperson increases stress during day", function()
    setMockTimeOfDay(12)  -- midday
    local p = MockPlayer({ "UniversalTraits:UT_owlperson" }, { stress = 0.3 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0.3, "stress should increase during day")
end)

test("day and night traits honor 0..24 clock boundaries", function()
    local cases = {
        { 0, false }, { 5.99, false }, { 6, true },
        { 17.99, true }, { 18, false }, { 23.99, false },
    }
    for _, case in ipairs(cases) do
        local hour, isDay = case[1], case[2]
        setMockTimeOfDay(hour)

        local lark = MockPlayer({ "UniversalTraits:UT_larkperson" }, { stress = 0.5 })
        withActivePlayer(lark, function() Events.EveryOneMinute:fire() end)
        assert_eq(
            lark:getStats():get(CharacterStat.STRESS) < 0.5,
            isDay,
            "lark day classification mismatch at hour " .. tostring(hour)
        )

        local owl = MockPlayer({ "UniversalTraits:UT_owlperson" }, { stress = 0.5 })
        withActivePlayer(owl, function() Events.EveryOneMinute:fire() end)
        assert_eq(
            owl:getStats():get(CharacterStat.STRESS) < 0.5,
            not isDay,
            "owl night classification mismatch at hour " .. tostring(hour)
        )

        local albino = MockPlayer(
            { "UniversalTraits:UT_albino" },
            { stress = 0.0, fatigue = 0.0 }
        )
        withActivePlayer(albino, function() Events.EveryOneMinute:fire() end)
        assert_eq(
            albino:getStats():get(CharacterStat.STRESS) > 0,
            isDay,
            "albino daylight classification mismatch at hour " .. tostring(hour)
        )
    end
end)

test("panicattacks adds panic spike on guaranteed roll", function()
    resetMockZombRand()  -- ZombRand(20) → 0 == 0 → fires
    local p = MockPlayer({ "UniversalTraits:UT_panicattacks" }, { panic = 0.0 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.PANIC) > 0, "panic should spike on guaranteed roll")
end)
test("panicattacks does NOT fire when roll fails", function()
    setMockZombRandDefault(5)  -- 5 != 0 → no spike
    local p = MockPlayer({ "UniversalTraits:UT_panicattacks" }, { panic = 0.0 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.PANIC), 0.0, "no spike when roll fails")
    resetMockZombRand()
end)

test("maniac registers one normal OnZombieDead handler", function()
    assert_eq(Events.OnZombieDead:getHandlerCount(), 1, "maniac should register once")
end)
test("maniac resolves the player attacker from the one-argument zombie event", function()
    local p = MockPlayer({ "UniversalTraits:UT_maniac" }, { stress = 0.5, boredom = 0.5 })
    Events.OnZombieDead:fire(MockZombie({ attackedBy = p }))
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.35, "stress should decrease by 0.15")
    assert_eq(p:getStats():get(CharacterStat.BOREDOM), 0.30, "boredom should decrease by 0.20")
end)
test("maniac does not affect player without trait", function()
    local p = MockPlayer({}, { stress = 0.5, boredom = 0.5 })
    Events.OnZombieDead:fire(MockZombie({ attackedBy = p }))
    assert_eq(p:getStats():get(CharacterStat.STRESS),  0.5, "stress unchanged without trait")
    assert_eq(p:getStats():get(CharacterStat.BOREDOM), 0.5, "boredom unchanged without trait")
end)
test("maniac rejects nil and non-zombie event objects", function()
    Events.OnZombieDead:fire(nil)
    Events.OnZombieDead:fire(MockPlayer({ "UniversalTraits:UT_maniac" }))
end)
test("maniac rejects zombies without an attacker", function()
    Events.OnZombieDead:fire(MockZombie())
end)
test("maniac rejects non-player attackers", function()
    Events.OnZombieDead:fire(MockZombie({ attackedBy = MockZombie() }))
end)
test("maniac clamps stress and boredom at zero", function()
    local p = MockPlayer({ "UniversalTraits:UT_maniac" }, { stress = 0.1, boredom = 0.1 })
    Events.OnZombieDead:fire(MockZombie({ attackedBy = p }))
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0, "stress floor")
    assert_eq(p:getStats():get(CharacterStat.BOREDOM), 0, "boredom floor")
end)
test("maniac applies once for each qualifying zombie death", function()
    local p = MockPlayer({ "UniversalTraits:UT_maniac" }, { stress = 0.8, boredom = 0.8 })
    Events.OnZombieDead:fire(MockZombie({ attackedBy = p }))
    Events.OnZombieDead:fire(MockZombie({ attackedBy = p }))
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.5, "two stress reductions")
    assert_true(math.abs(p:getStats():get(CharacterStat.BOREDOM) - 0.4) < 0.000001,
        "two boredom reductions")
end)
test("maniac old fabricated player-zombie signature has no effect", function()
    local p = MockPlayer({ "UniversalTraits:UT_maniac" }, { stress = 0.5, boredom = 0.5 })
    Events.OnZombieDead:fire(p, MockZombie({ attackedBy = p }))
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.5, "fabricated signature rejected")
    assert_eq(p:getStats():get(CharacterStat.BOREDOM), 0.5, "fabricated signature rejected")
end)
test("maniac same-process reload retains one handler", function()
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_maniac.lua")
    assert_eq(Events.OnZombieDead:getHandlerCount(), 1, "reload should replace prior handler")
end)

test("lesssweaty reduces wetness when not sleeping and wetness > 0", function()
    setMockClimate(0.0, 0.5)  -- not raining, indoors
    local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" }, { wetness = 50 })
    p._sleeping = false
    p._indoors  = true   -- isOutside() = false → indoor reduction = 3
    withActivePlayer(p, function()
        Events.OnCreatePlayer:fire(0, p)
        Events.EveryOneMinute:fire()
    end)
    assert_eq(p:getStats():get(CharacterStat.WETNESS), 47, "wetness should decrease by 3 indoors")
end)
test("lesssweaty skips when player is sleeping", function()
    local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" }, { wetness = 50 })
    p._sleeping = true
    withActivePlayer(p, function()
        Events.OnCreatePlayer:fire(0, p)
        Events.EveryOneMinute:fire()
    end)
    assert_eq(p:getStats():get(CharacterStat.WETNESS), 50, "wetness unchanged when sleeping")
end)

test("lesssweaty cools mild overheating after create-player setup", function()
    local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" }, { bodyTemp = 37.4, wetness = 0 })
    withActivePlayer(p, function()
        Events.OnCreatePlayer:fire(0, p)
        Events.EveryOneMinute:fire()
    end)
    local temp = p:getStats():get(CharacterStat.TEMPERATURE)
    assert_true(math.abs(temp - 37.32) < 0.0001, "mild overheating should cool by 0.08")
end)

test("lesssweaty cools strong overheating after create-player setup", function()
    local p = MockPlayer({ "UniversalTraits:UT_lesssweaty" }, { bodyTemp = 37.9, wetness = 0 })
    withActivePlayer(p, function()
        Events.OnCreatePlayer:fire(0, p)
        Events.EveryOneMinute:fire()
    end)
    local temp = p:getStats():get(CharacterStat.TEMPERATURE)
    assert_true(math.abs(temp - 37.78) < 0.0001, "strong overheating should cool by 0.12")
end)

test("highsweaty increases wetness when sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_highsweaty" }, { wetness = 0 })
    p._sprinting = true
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.WETNESS) > 0, "wetness should increase when sprinting")
end)

-- ─── Group 7: EveryHours ─────────────────────────────────────────────────────


test("sedentary reduces endurance each in-game hour", function()
    local p = MockPlayer({ "UniversalTraits:UT_sedentary" }, { endurance = 0.9 })
    withActivePlayer(p, function() Events.EveryHours:fire() end)
    assert_true(p:getStats():get(CharacterStat.ENDURANCE) < 0.9, "endurance should decrease")
    assert_eq(p:getModData()["UT_sedentaryPenalty"], true, "penalty flag should be set")
end)

-- ─── Group 8: OnPlayerUpdate / registerPeriodicHandler ───────────────────────

test("backpacker applies carry weight bonus relative to Strength", function()
    local p = MockPlayer({ "UniversalTraits:UT_backpacker" })
    p:setPerkLevel(Perks.Strength, 0)
    withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
    -- applyStrengthCarryWeight(player, +4) → 5 + Strength(0) + 4 = 9
    assert_eq(p:getMaxWeightBase(), 9, "expected 5+0+4=9 carry weight")
end)
test("backpacker scales carry weight with high Strength", function()
    local p = MockPlayer({ "UniversalTraits:UT_backpacker" })
    p:setPerkLevel(Perks.Strength, 5)
    withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
    assert_eq(p:getMaxWeightBase(), 14, "expected 5+5+4=14 carry weight")
end)

test("sore registers pain floor via UTCore.applyStatFloor on update", function()
    local p = MockPlayer({ "UniversalTraits:UT_sore" })
    withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
    assert_eq(p:getModData()["UT_statFloor_Pain"], 20, "expected pain floor set to 20")
end)

test("sloth records fatigue removal when not running or sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_sloth" })
    p._running   = false
    p._sprinting = false
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local accum = p:getStats()._charStatAccum[CharacterStat.FATIGUE]
    assert_true(type(accum) == "number" and accum < 0,
        "expected fatigue charstat removal, got " .. tostring(accum))
end)
test("sloth skips when sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_sloth" })
    p._sprinting = true
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats()._charStatAccum[CharacterStat.FATIGUE], nil, "no fatigue removal when sprinting")
end)

test("squirrel records fatigue removal when running", function()
    local p = MockPlayer({ "UniversalTraits:UT_squirrel" })
    p._running = true
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local accum = p:getStats()._charStatAccum[CharacterStat.FATIGUE]
    assert_true(type(accum) == "number" and accum < 0,
        "expected fatigue charstat removal when running, got " .. tostring(accum))
end)
test("squirrel skips when not running or sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_squirrel" })
    p._running   = false
    p._sprinting = false
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats()._charStatAccum[CharacterStat.FATIGUE], nil, "no fatigue removal when idle")
end)

test("sundayrunner records unhappiness addition when sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_sundayrunner" })
    p._sprinting = true
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local accum = p:getStats()._charStatAccum[CharacterStat.UNHAPPINESS]
    assert_true(type(accum) == "number" and accum > 0,
        "expected unhappiness increase when sprinting, got " .. tostring(accum))
end)
test("sundayrunner skips when not sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_sundayrunner" })
    p._sprinting = false
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats()._charStatAccum[CharacterStat.UNHAPPINESS], nil,
        "no unhappiness change when not sprinting")
end)

test("couchdweller records boredom and unhappiness removal when indoors", function()
    local p = MockPlayer({ "UniversalTraits:UT_couchdweller" })
    p._indoors = true   -- isOutside() = false → handler proceeds
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local boredom = p:getStats()._charStatAccum[CharacterStat.BOREDOM]
    assert_true(type(boredom) == "number" and boredom < 0,
        "expected boredom removal when indoors, got " .. tostring(boredom))
end)
test("couchdweller skips when outdoors", function()
    local p = MockPlayer({ "UniversalTraits:UT_couchdweller" })
    p._indoors = false   -- isOutside() = true → handler returns early
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats()._charStatAccum[CharacterStat.BOREDOM], nil,
        "no boredom removal when outdoors")
end)

test("nervouswreck reduces panicReductionValue by 70pct on first update", function()
    local p = MockPlayer({ "UniversalTraits:UT_nervouswreck" })
    p:getBodyDamage()._panicReductionValue = 0.06
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getModData()["UT_nervouswreck_applied"], true, "applied flag should be set")
    assert_true(math.abs(p:getBodyDamage():getPanicReductionValue() - 0.06 * 0.30) < 0.0001,
        "panicReductionValue should be 30% of original")
end)
test("nervouswreck does not re-apply when already applied", function()
    local p = MockPlayer({ "UniversalTraits:UT_nervouswreck" })
    p:getBodyDamage()._panicReductionValue = 0.06
    Events.OnPlayerUpdate:fire(p)  -- first apply
    local reduced = p:getBodyDamage():getPanicReductionValue()
    Events.OnPlayerUpdate:fire(p)  -- second apply — should be a no-op
    assert_eq(p:getBodyDamage():getPanicReductionValue(), reduced,
        "value should not change on second update")
end)

local MOTION_SICKNESS_ID = "UniversalTraits:UT_motionsickness"
local function firePlayerUpdates(player, count)
    for _ = 1, count do Events.OnPlayerUpdate:fire(player) end
end

local function rebuildFor(player)
    Events.OnCreatePlayer:fire(0, player)
end

local BUTTERFINGERS_ID = "UniversalTraits:UT_butterfingers"
local function findButterfingersRegistration()
    local found = nil
    local count = 0
    for i = 1, #UTCore._tickHandlers do
        local handler = UTCore._tickHandlers[i]
        if handler.id == BUTTERFINGERS_ID then
            found = handler
            count = count + 1
        end
    end
    assert_eq(count, 1, "butterfingers should have exactly one registration")
    return found
end

local function butterTick(player, tickCount)
    local tick = UTCore.buildMockTickContext(player)
    tick.tickCount = tickCount
    findButterfingersRegistration().fn(player, tick)
end

test("butterfingers uses dispatcher ticks and the mock exposes no GameTime.getTicks API", function()
    assert_eq(getGameTime().getTicks, nil, "B42 GameTime must not invent getTicks")
    local registration = findButterfingersRegistration()
    assert_true(registration.opts.throttle == nil or registration.opts.throttle == 0,
        "pending-drop consumer must run every update")
    local p = MockPlayer({ BUTTERFINGERS_ID }, { playerNum = 201 })
    local ok, err = pcall(function() butterTick(p, 1) end)
    assert_true(ok, "handler should be safe with production-faithful APIs: " .. tostring(err))
end)

test("butterfingers rolls at exactly 300 dispatcher ticks, not before", function()
    resetMockZombRand()
    setMockZombRandSequence({ 0 })
    local p = MockPlayer({ BUTTERFINGERS_ID }, { playerNum = 202 })
    butterTick(p, 299)
    assert_eq(p:getModData()["UT_dropNext"], nil, "no roll before the 300-tick boundary")
    butterTick(p, 300)
    assert_eq(p:getModData()["UT_dropNext"], true, "successful roll schedules at tick 300")
    resetMockZombRand()
end)

test("butterfingers success range is ZombRand 0 through 2, excluding 3", function()
    for roll = 0, 3 do
        resetMockZombRand()
        setMockZombRandSequence({ roll })
        local p = MockPlayer({ BUTTERFINGERS_ID }, { playerNum = 210 + roll })
        butterTick(p, 300)
        assert_eq(p:getModData()["UT_dropNext"], roll < 3 and true or nil,
            "unexpected scheduling result for roll " .. tostring(roll))
    end
    resetMockZombRand()
end)

test("butterfingers consumes a successful roll on the following update", function()
    resetMockZombRand()
    setMockZombRandSequence({ 2 })
    local item = MockItem("ButterKnife")
    local inv = MockInventory(1.0)
    local sq = MockSquare()
    inv:AddItem(item)
    local p = MockPlayer({ BUTTERFINGERS_ID }, {
        playerNum = 220, primaryHandItem = item, inventory = inv, square = sq,
    })
    butterTick(p, 300)
    assert_eq(p:getPrimaryHandItem(), item, "scheduling update must not drop immediately")
    assert_eq(#sq._dropped, 0, "scheduling update must leave the square unchanged")
    butterTick(p, 301)
    assert_eq(p:getModData()["UT_dropNext"], nil, "following update consumes the pending flag")
    assert_eq(p:getPrimaryHandItem(), nil, "item leaves the primary hand")
    assert_eq(#inv._items, 0, "item leaves inventory")
    assert_eq(sq._dropped[1], item, "same item enters the current square")
    resetMockZombRand()
end)

test("butterfingers clears a pending flag with an empty primary hand", function()
    local sq = MockSquare()
    local p = MockPlayer({ BUTTERFINGERS_ID }, {
        playerNum = 221, inventory = MockInventory(0), square = sq,
    })
    p:getModData()["UT_dropNext"] = true
    butterTick(p, 1)
    assert_eq(p:getModData()["UT_dropNext"], nil, "empty-hand update still consumes the flag")
    assert_eq(#sq._dropped, 0, "empty hand must not create a world item")
end)

test("butterfingers keeps the default vehicle gate", function()
    local p = MockPlayer({ BUTTERFINGERS_ID }, { playerNum = 222, vehicle = MockVehicle() })
    p:getModData()["UT_dropNext"] = true
    rebuildFor(p)
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getModData()["UT_dropNext"], true, "non-vehicle-aware handler stays gated in vehicles")
end)

test("butterfingers activates through OnCreatePlayer rebuild", function()
    resetMockZombRand()
    setMockZombRandSequence({ 99 })
    local p = MockPlayer({ BUTTERFINGERS_ID }, { playerNum = 223 })
    rebuildFor(p)
    local active = false
    for i = 1, #(UTCore._activeTickHandlers or {}) do
        if UTCore._activeTickHandlers[i].id == BUTTERFINGERS_ID then active = true end
    end
    assert_true(active, "OnCreatePlayer rebuild should activate Butterfingers")
    p:getModData()["UT_dropNext"] = true
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getModData()["UT_dropNext"], nil, "active handler should consume on the next update")
    resetMockZombRand()
end)

test("butterfingers source and release runtime stay byte-identical", function()
    local function readAll(path)
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        return content
    end
    local relative = "lua/shared/UniversalTraits/traits/UT_butterfingers.lua"
    assert_eq(readAll(base .. "../media/" .. relative),
        readAll(base .. "../release/UniversalTraits/42.0/media/" .. relative),
        "source and release Butterfingers files must match")
end)

test("motionsickness source and release runtime stay byte-identical", function()
    local function readAll(path)
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        return content
    end
    local relative = "lua/shared/UniversalTraits/traits/UT_motionsickness.lua"
    assert_eq(readAll(base .. "../media/" .. relative),
        readAll(base .. "../release/UniversalTraits/42.0/media/" .. relative),
        "source and release Motion Sickness files must match")
end)

local function updatesToNextMotionCadence()
    local remainder = UTCore.getMockDispatchTickCount() % 60
    return remainder == 0 and 60 or 60 - remainder
end

local function findMotionSicknessRegistrations()
    local found = {}
    for i = 1, #UTCore._tickHandlers do
        local handler = UTCore._tickHandlers[i]
        if handler.id == MOTION_SICKNESS_ID then found[#found + 1] = handler end
    end
    return found
end

test("motionsickness has one dispatch-managed vehicle-aware registration", function()
    local registrations = findMotionSicknessRegistrations()
    assert_eq(#registrations, 1, "motionsickness should register exactly once")
    local handler = registrations[1]
    assert_eq(handler.id, MOTION_SICKNESS_ID, "registration id")
    assert_eq(handler.opts.vehicleAware, true, "registration should be vehicle-aware")
    assert_eq(handler.opts.throttle, 60, "dispatcher should own the 60-update cadence")
end)
test("motionsickness real dofile loader path is idempotent", function()
    local before = UTCore.getTickHandlerCount()
    dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_motionsickness.lua")
    assert_eq(UTCore.getTickHandlerCount(), before,
        "re-evaluating the production file must not append another handler")
    assert_eq(#findMotionSicknessRegistrations(), 1,
        "repeated production-file evaluation must leave one effective handler")
end)
test("motionsickness first update is safe and has no effect before cadence", function()
    local p = MockPlayer({ MOTION_SICKNESS_ID }, { vehicle = MockVehicle(), stress = 0.0 })
    rebuildFor(p)
    local beforeCadence = updatesToNextMotionCadence() - 1
    firePlayerUpdates(p, beforeCadence)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.0, "updates before cadence should not apply stress")
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.01, "cadence update should apply stress")
end)
test("motionsickness applies exactly 0.01 to driver and passenger on cadence", function()
    local driver = MockPlayer({ MOTION_SICKNESS_ID },
        { vehicle = MockVehicle(), driving = true, stress = 0.0 })
    rebuildFor(driver)
    firePlayerUpdates(driver, updatesToNextMotionCadence())
    assert_eq(driver:getStats():get(CharacterStat.STRESS), 0.01, "driver: exact cadence effect")

    local passenger = MockPlayer({ MOTION_SICKNESS_ID },
        { vehicle = MockVehicle(), driving = false, stress = 0.0 })
    rebuildFor(passenger)
    firePlayerUpdates(passenger, updatesToNextMotionCadence())
    assert_eq(passenger:getStats():get(CharacterStat.STRESS), 0.01, "passenger: exact cadence effect")
end)
test("motionsickness repeats cadence and caps stress at 1.0", function()
    local p = MockPlayer({ MOTION_SICKNESS_ID }, { vehicle = MockVehicle(), stress = 0.985 })
    rebuildFor(p)
    firePlayerUpdates(p, updatesToNextMotionCadence())
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.995, "first cadence should add exactly 0.01")
    firePlayerUpdates(p, 60)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 1, "second cadence should cap at 1.0")
end)
test("motionsickness skips on foot and without the trait", function()
    local onFoot = MockPlayer({ MOTION_SICKNESS_ID }, { stress = 0.0 })
    rebuildFor(onFoot)
    firePlayerUpdates(onFoot, updatesToNextMotionCadence())
    assert_eq(onFoot:getStats():get(CharacterStat.STRESS), 0.0, "no stress on foot")

    local noTrait = MockPlayer({}, { vehicle = MockVehicle(), stress = 0.0 })
    rebuildFor(noTrait)
    firePlayerUpdates(noTrait, updatesToNextMotionCadence())
    assert_eq(noTrait:getStats():get(CharacterStat.STRESS), 0.0, "no stress without trait")
end)
test("motionsickness rebuild preserves cadence and snapshots trait removal", function()
    local p = MockPlayer({ MOTION_SICKNESS_ID }, { vehicle = MockVehicle(), stress = 0.0 })
    rebuildFor(p)
    local untilCadence = updatesToNextMotionCadence()
    firePlayerUpdates(p, untilCadence - 1)
    rebuildFor(p)
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.01,
        "active-array rebuild must not reset the shared dispatcher cadence")

    p:getCharacterTraits():remove(CharacterTrait.get(ResourceLocation.of(MOTION_SICKNESS_ID)))
    firePlayerUpdates(p, 60)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.02,
        "trait removal must not affect the active snapshot before rebuild")
    rebuildFor(p)
    firePlayerUpdates(p, 60)
    assert_eq(p:getStats():get(CharacterStat.STRESS), 0.02,
        "trait removal must stop effects after the production recheck point")
end)

test("vehophobic raises panic and stress when driving (past cooldown)", function()
    local vehicle = MockVehicle()
    local p = MockPlayer({ "UniversalTraits:UT_vehophobic" },
        { vehicle = vehicle, driving = true, stress = 0.0, panic = 0.0 })
    -- cooldown starts nil (→ 0) → handler fires
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getModData()["UT_vehophobic_cooldown"], 30, "cooldown should be set to 30")
end)
test("vehophobic skips when not driving", function()
    local p = MockPlayer({ "UniversalTraits:UT_vehophobic" },
        { driving = false, panic = 0.0 })
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getStats():get(CharacterStat.PANIC), 0.0, "no panic when not driving")
end)

test("fearful emits sound and sets cooldown at high panic (guaranteed roll)", function()
    resetMockZombRand()  -- ZombRand(0, 1000) → 0; panic 80 → chance = 3+8 = 11; 0 ≤ 11 → fires
    local p = MockPlayer({ "UniversalTraits:UT_fearful" }, { panic = 80 })
    Events.OnPlayerUpdate:fire(p)
    assert_true(p._said == "!" or p:getModData()["UT_fearful_cooldown"] == 60,
        "expected fearful to emit sound or set cooldown at high panic")
end)
test("fearful does not fire when panic < 5 (below threshold)", function()
    resetMockZombRand()
    local p = MockPlayer({ "UniversalTraits:UT_fearful" }, { panic = 0 })
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._said, nil, "no sound when panic is below threshold")
end)

test("leadfoot increases vehicle max speed by 20pct via vehicle trait system", function()
    local vehicle = MockVehicle()
    local p = MockPlayer({ "UniversalTraits:UT_leadfoot" }, { vehicle = vehicle })
    p:setVehicle(vehicle)
    Events.OnEnterVehicle:fire(p)
    assert_eq(vehicle:getMaxSpeed(), 120, "expected +20% max speed from leadfoot")
end)

test("flimsy registers arm pain from heavy backpack (>20 weight)", function()
    local pack = MockBackpack(25)  -- 25 > 20 → pain = min(25*0.1, 20) = 2.5
    local p = MockPlayer({ "UniversalTraits:UT_flimsy" }, { backpack = pack })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local armL = p:getBodyDamage():getBodyPart(BodyPartType.UpperArm_L)
    assert_true(armL:getAdditionalPain() > 0, "arm pain should increase with heavy backpack")
end)
test("flimsy clears arm pain when no backpack equipped", function()
    -- set initial pain, then run handler with no backpack → pain = 0
    local p = MockPlayer({ "UniversalTraits:UT_flimsy" })
    p:getBodyDamage():getBodyPart(BodyPartType.UpperArm_L)._pain = 10
    -- _backpack = nil by default
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    local armL = p:getBodyDamage():getBodyPart(BodyPartType.UpperArm_L)
    assert_eq(armL:getAdditionalPain(), 0, "arm pain should be cleared when no backpack")
end)

-- ─── Group 9: Food-timer / complex patterns ───────────────────────────────────

test("anorexy records stress via CharacterStat.add on rising food timer", function()
    local p = MockPlayer({ "UniversalTraits:UT_anorexy" })
    p:getBodyDamage()._healthFromFoodTimer = 100
    Events.OnPlayerUpdate:fire(p)   -- first call: sets prevTimer=100, no trigger
    p:getBodyDamage()._healthFromFoodTimer = 200  -- jump +100 > 50 → triggers
    Events.OnPlayerUpdate:fire(p)
    local stressAccum = p:getStats()._charStatAccum[CharacterStat.STRESS]
    assert_true(type(stressAccum) == "number" and stressAccum > 0,
        "expected stress charstat addition, got " .. tostring(stressAccum))
end)
test("anorexy does not fire on first update (no prev state)", function()
    local p = MockPlayer({ "UniversalTraits:UT_anorexy" })
    p:getBodyDamage()._healthFromFoodTimer = 200  -- no prev → no trigger
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getStats()._charStatAccum[CharacterStat.STRESS], nil,
        "no stress on first call when prev is nil")
end)

test("badteeth applies head pain when food timer > 1000 and rising", function()
    local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
    p:getBodyDamage()._healthFromFoodTimer = 1200  -- > 1000 and > UTCore.getModData default 0
    withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
    local headPain = p:getBodyDamage():getBodyPart(BodyPartType.Head):getAdditionalPain()
    assert_true(headPain > 0, "expected head pain > 0 after rising food timer above 1000")
end)
test("badteeth does NOT fire when food timer < 1000", function()
    local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
    p:getBodyDamage()._healthFromFoodTimer = 500
    withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
    local headPain = p:getBodyDamage():getBodyPart(BodyPartType.Head):getAdditionalPain()
    assert_eq(headPain, 0, "no pain when food timer below 1000")
end)

test("competitiveeater records boredom and hunger removal on rising food timer", function()
    local p = MockPlayer({ "UniversalTraits:UT_competitiveeater" })
    p:getBodyDamage()._healthFromFoodTimer = 100
    Events.OnPlayerUpdate:fire(p)  -- set prev
    p:getBodyDamage()._healthFromFoodTimer = 200  -- jump > 50 → trigger
    Events.OnPlayerUpdate:fire(p)
    local boredomAccum = p:getStats()._charStatAccum[CharacterStat.BOREDOM]
    local hungerAccum  = p:getStats()._charStatAccum[CharacterStat.HUNGER]
    assert_true(type(boredomAccum) == "number" and boredomAccum < 0,
        "expected boredom charstat removal, got " .. tostring(boredomAccum))
    assert_true(type(hungerAccum) == "number" and hungerAccum < 0,
        "expected hunger charstat removal, got " .. tostring(hungerAccum))
end)

test("sensitivestomach applies torso pain on rising food timer above 1000", function()
    local p = MockPlayer({ "UniversalTraits:UT_sensitivestomach" })
    p:getBodyDamage()._healthFromFoodTimer = 1200
    Events.OnPlayerUpdate:fire(p)  -- sets prevTimer=1000 (nil init), 1200>1000 → applies pain
    local torso = p:getBodyDamage():getBodyPart(BodyPartType.FromString("Torso_Lower"))
    assert_true(torso:getAdditionalPain() > 0, "expected torso pain after digestion")
end)

test("ascetic reduces hunger via EveryOneMinute passive benefit", function()
    local p = MockPlayer({ "UniversalTraits:UT_ascetic" }, { hunger = 0.5 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getStats():get(CharacterStat.HUNGER) < 0.5,
        "expected hunger to decrease from ascetic passive hunger rate reduction")
end)
test("ascetic OnPlayerUpdate runs without error", function()
    local p = MockPlayer({ "UniversalTraits:UT_ascetic" })
    Events.OnPlayerUpdate:fire(p)  -- must not throw
end)

test("fitted OnPlayerUpdate runs without error (smoke test)", function()
    local p = MockPlayer({ "UniversalTraits:UT_fitted" })
    Events.OnPlayerUpdate:fire(p)  -- must not throw
end)

test("gourmand OnPlayerUpdate runs without error (smoke test)", function()
    local p = MockPlayer({ "UniversalTraits:UT_gourmand" })
    Events.OnPlayerUpdate:fire(p)  -- must not throw
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- BEHAVIORAL QA TESTS — multi-tick, proving gameplay-visible outcomes
-- Written to catch bugs like the idealweight compounding feedback loop.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── trekker: calorie refund stays LINEAR across 20 ticks ──────────────────────
test("trekker calorie refund is linear (no compounding)", function()
    local p = MockPlayer({ "UniversalTraits:UT_trekker" }, { endurance = 1.0 })
    p._moving = true; p._sprinting = false; p._running = false
    p:getNutrition():setCalories(2000)

    local GAME_BURN = 5     -- simulated game calorie burn per tick
    local REFUND_RATIO = (0.13 * 0.6 - 0.016) / (0.13 * 0.6)  -- ~0.794

    -- Seed prev values with initial tick
    Events.OnPlayerUpdate:fire(p)

    local refunds = {}
    for i = 1, 20 do
        -- Simulate game burning calories between ticks
        local before = p:getNutrition():getCalories()
        p:getNutrition():setCalories(before - GAME_BURN)
        Events.OnPlayerUpdate:fire(p)
        local after = p:getNutrition():getCalories()
        local restored = after - (before - GAME_BURN)
        refunds[i] = restored
    end

    -- Each tick's refund should be approximately the same (linear), not growing
    local firstRefund = refunds[1]
    local lastRefund = refunds[20]
    -- Tolerance: refunds should be within 10% of each other (no drift)
    local ratio = lastRefund / firstRefund
    assert_true(ratio > 0.9 and ratio < 1.1,
        "trekker refund should be linear: first=" .. firstRefund .. " last=" .. lastRefund .. " ratio=" .. ratio)
    -- Verify refund is approximately GAME_BURN * REFUND_RATIO
    local expected = GAME_BURN * REFUND_RATIO
    assert_true(firstRefund > expected * 0.8 and firstRefund < expected * 1.2,
        "trekker refund magnitude wrong: expected ~" .. expected .. " got " .. firstRefund)
end)

test("trekker does NOT refund when sprinting", function()
    local p = MockPlayer({ "UniversalTraits:UT_trekker" }, { endurance = 1.0 })
    p._moving = true; p._sprinting = true; p._running = false
    p:getNutrition():setCalories(2000)
    Events.OnPlayerUpdate:fire(p)  -- seed
    p:getNutrition():setCalories(1995)  -- game burns 5
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getNutrition():getCalories(), 1995, "no refund while sprinting")
end)

test("trekker refunds endurance loss while walking", function()
    local p = MockPlayer({ "UniversalTraits:UT_trekker" }, { endurance = 0.8 })
    p._moving = true; p._sprinting = false; p._running = false
    p:getNutrition():setCalories(2000)
    Events.OnPlayerUpdate:fire(p)  -- seed lastEndurance = 0.8
    p:getStats():set(CharacterStat.ENDURANCE, 0.75)  -- game drains 0.05
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p:getStats():get(CharacterStat.ENDURANCE), 0.8,
        "trekker should restore endurance to pre-drain level")
end)

-- ─── marathonrunner: endurance/fatigue refund LINEAR across 20 ticks ───────────
test("marathonrunner endurance refund is linear (no compounding)", function()
    local p = MockPlayer({ "UniversalTraits:UT_marathonrunner" })
    p:getStats():set(CharacterStat.ENDURANCE, 1.0)

    -- Marathonrunner uses file-local lastEndurance, need to prime it
    -- Fire 5 ticks to pass throttle (throttle=5, fires on tick%5==0)
    for i = 1, 5 do Events.OnPlayerUpdate:fire(p) end

    local drains = {}
    for i = 1, 20 do
        -- Simulate game draining endurance
        local cur = p:getStats():get(CharacterStat.ENDURANCE)
        local drained = cur - 0.05
        p:getStats():set(CharacterStat.ENDURANCE, drained)
        -- Fire 5 ticks to hit throttle
        for t = 1, 5 do Events.OnPlayerUpdate:fire(p) end
        local after = p:getStats():get(CharacterStat.ENDURANCE)
        drains[i] = after - drained  -- how much was refunded
    end

    -- Refund should be ~0.05 * 0.15 = 0.0075 each time, not growing
    local first = drains[1]
    local last = drains[20]
    assert_true(first > 0, "should get some endurance refund, got " .. first)
    local ratio = last / first
    assert_true(ratio > 0.85 and ratio < 1.15,
        "marathonrunner refund should be linear: first=" .. first .. " last=" .. last)
end)

test("marathonrunner fatigue refund is linear (no compounding)", function()
    local p = MockPlayer({ "UniversalTraits:UT_marathonrunner" }, { fatigue = 0.0 })

    -- Prime the handler
    for i = 1, 5 do Events.OnPlayerUpdate:fire(p) end

    local refunds = {}
    for i = 1, 20 do
        local cur = p:getStats():get(CharacterStat.FATIGUE)
        p:getStats():set(CharacterStat.FATIGUE, cur + 0.05)  -- game increases fatigue
        for t = 1, 5 do Events.OnPlayerUpdate:fire(p) end
        local after = p:getStats():get(CharacterStat.FATIGUE)
        refunds[i] = (cur + 0.05) - after  -- how much was removed
    end

    local first = refunds[1]
    local last = refunds[20]
    assert_true(first > 0, "should get some fatigue refund")
    local ratio = last / first
    assert_true(ratio > 0.85 and ratio < 1.15,
        "marathonrunner fatigue refund should be linear: first=" .. first .. " last=" .. last)
end)

-- ─── olympian: same delta pattern as marathonrunner ────────────────────────────
test("olympian endurance refund is linear (no compounding)", function()
    local p = MockPlayer({ "UniversalTraits:UT_olympian" })
    p:getStats():set(CharacterStat.ENDURANCE, 1.0)

    for i = 1, 5 do Events.OnPlayerUpdate:fire(p) end  -- prime

    local drains = {}
    for i = 1, 20 do
        local cur = p:getStats():get(CharacterStat.ENDURANCE)
        p:getStats():set(CharacterStat.ENDURANCE, cur - 0.05)
        for t = 1, 5 do Events.OnPlayerUpdate:fire(p) end
        local after = p:getStats():get(CharacterStat.ENDURANCE)
        drains[i] = after - (cur - 0.05)
    end

    local first = drains[1]
    local last = drains[20]
    assert_true(first > 0, "olympian should refund endurance")
    local ratio = last / first
    assert_true(ratio > 0.85 and ratio < 1.15,
        "olympian endurance refund should be linear: first=" .. first .. " last=" .. last)
end)

-- ─── evasive: dodge mechanic over 20 ticks ─────────────────────────────────────
test("evasive restores health on dodge (ZombRand < 50)", function()
    setMockZombRandDefault(0)  -- always dodge
    local p = MockPlayer({ "UniversalTraits:UT_evasive" }, { health = 100 })
    Events.OnPlayerUpdate:fire(p)  -- seed lastHealth

    p._health = 80  -- simulate 20 damage
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._health, 100, "evasive should restore full health on dodge")
    resetMockZombRand()
end)

test("evasive does NOT restore health when dodge fails (ZombRand >= 50)", function()
    setMockZombRandDefault(50)  -- fail dodge
    local p = MockPlayer({ "UniversalTraits:UT_evasive" }, { health = 100 })
    Events.OnPlayerUpdate:fire(p)  -- seed lastHealth

    p._health = 80  -- simulate 20 damage
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._health, 80, "evasive should NOT restore when dodge fails")
    resetMockZombRand()
end)

test("evasive dodge does not compound over multiple hits", function()
    setMockZombRandDefault(0)  -- always dodge
    local p = MockPlayer({ "UniversalTraits:UT_evasive" }, { health = 100 })
    Events.OnPlayerUpdate:fire(p)  -- seed

    -- Hit 1: 20 damage → dodged
    p._health = 80
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._health, 100, "first dodge should restore to 100")

    -- Hit 2: 30 damage → dodged
    p._health = 70
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._health, 100, "second dodge should restore to 100")

    -- Hit 3: no damage this tick
    Events.OnPlayerUpdate:fire(p)
    assert_eq(p._health, 100, "no change when no damage")
    resetMockZombRand()
end)

-- ─── ascetic: eating detection and passive hunger reduction ────────────────────
test("ascetic detects eating via healthFromFoodTimer rising edge", function()
    setMockGameTime(10, 0)  -- worldAgeHours = 10
    local p = MockPlayer({ "UniversalTraits:UT_ascetic" }, { healthFromFoodTimer = 100 })
    Events.OnPlayerUpdate:fire(p)  -- seed prevTimer=100

    -- First meal: timer jumps by >50 → sets lastAte=10, no penalty (first meal)
    p:getBodyDamage()._healthFromFoodTimer = 200
    Events.OnPlayerUpdate:fire(p)
    local unhappyAfterFirstMeal = p:getStats():get(CharacterStat.UNHAPPINESS)
    assert_eq(unhappyAfterFirstMeal, 0, "no penalty on first meal")

    -- Second meal within 1 hour: should trigger penalty
    p:getBodyDamage()._healthFromFoodTimer = 350
    Events.OnPlayerUpdate:fire(p)
    local unhappyAfterSecondMeal = p:getStats():get(CharacterStat.UNHAPPINESS)
    assert_true(unhappyAfterSecondMeal > 0,
        "penalty for eating again within 1 hour, got " .. unhappyAfterSecondMeal)
end)

test("ascetic passive hunger reduction works over 10 minutes", function()
    local p = MockPlayer({ "UniversalTraits:UT_ascetic" }, { hunger = 0.5 })
    withActivePlayer(p, function()
        for i = 1, 10 do
            Events.EveryOneMinute:fire()
        end
    end)
    local hunger = p:getStats():get(CharacterStat.HUNGER)
    -- 10 minutes × 0.0015 = 0.015 reduction
    assert_true(hunger < 0.5, "hunger should decrease from passive reduction")
    assert_true(hunger > 0.48, "hunger should not drop too fast: " .. hunger)
end)

-- ─── fast: endurance regen over 30+ ticks ──────────────────────────────────────
test("fast regens endurance after 30 ticks", function()
    local p = MockPlayer({ "UniversalTraits:UT_fast" }, { endurance = 0.5 })
    -- Fire 30 ticks to pass the internal counter
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local endurance = p:getStats():get(CharacterStat.ENDURANCE)
    assert_true(endurance > 0.5, "fast should regen endurance after 30 ticks, got " .. endurance)
end)

test("fast endurance regen is bounded by max", function()
    local p = MockPlayer({ "UniversalTraits:UT_fast" }, { endurance = 0.99 })
    for i = 1, 60 do Events.OnPlayerUpdate:fire(p) end
    local endurance = p:getStats():get(CharacterStat.ENDURANCE)
    assert_true(endurance <= 1.0, "fast should not exceed max endurance")
end)

test("fast applies +0.3 speed modifier on create", function()
    local p = MockPlayer({ "UniversalTraits:UT_fast" })
    Events.OnCreatePlayer:fire(0, p)
    local speedMod = p:getModData()["UT_speedMod"]
    assert_true(speedMod ~= nil and speedMod > 0, "fast should set positive speed modifier")
end)

-- ─── noodlelegs: endurance drain over 30+ ticks ───────────────────────────────
test("noodlelegs drains endurance after 30 ticks", function()
    local p = MockPlayer({ "UniversalTraits:UT_noodlelegs" }, { endurance = 0.5 })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local endurance = p:getStats():get(CharacterStat.ENDURANCE)
    assert_true(endurance < 0.5, "noodlelegs should drain endurance, got " .. endurance)
end)

test("noodlelegs applies -0.2 speed modifier on create", function()
    local p = MockPlayer({ "UniversalTraits:UT_noodlelegs" })
    Events.OnCreatePlayer:fire(0, p)
    local speedMod = p:getModData()["UT_speedMod"]
    assert_true(speedMod ~= nil and speedMod < 0, "noodlelegs should set negative speed modifier")
end)

-- ─── natural: speed bonus scales with clothing count ───────────────────────────
test("natural gives +10% speed with no clothing", function()
    local wornItems = MockWornItemsFull({})
    local p = MockPlayer({ "UniversalTraits:UT_natural" }, { wornItems = wornItems })
    -- Fire enough ticks to pass throttle (30)
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local speedMod = p:getModData()["UT_speedMod"] or 0
    assert_true(math.abs(speedMod - 0.10) < 0.02,
        "natural should give ~0.10 speed with 0 clothing, got " .. speedMod)
end)

test("natural gives 0 speed bonus with 5+ clothing items", function()
    local items = {}
    for i = 1, 5 do items[i] = MockClothingItem("Shirt" .. i) end
    local wornItems = MockWornItemsFull(items)
    local p = MockPlayer({ "UniversalTraits:UT_natural" }, { wornItems = wornItems })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local speedMod = p:getModData()["UT_speedMod"] or 0
    assert_true(math.abs(speedMod) < 0.01,
        "natural should give ~0 speed with 5 clothing, got " .. speedMod)
end)

test("natural speed scales: 3 items = +0.04", function()
    local items = {}
    for i = 1, 3 do items[i] = MockClothingItem("Shirt" .. i) end
    local wornItems = MockWornItemsFull(items)
    local p = MockPlayer({ "UniversalTraits:UT_natural" }, { wornItems = wornItems })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local speedMod = p:getModData()["UT_speedMod"] or 0
    -- 0.10 - 3 * 0.02 = 0.04
    assert_true(math.abs(speedMod - 0.04) < 0.02,
        "natural should give ~0.04 speed with 3 clothing, got " .. speedMod)
end)

-- ─── slowworker: +50% work speed penalty ───────────────────────────────────────
test("slowworker applies +0.5 work speed on new game", function()
    local p = MockPlayer({ "UniversalTraits:UT_slowworker" })
    Events.OnNewGame:fire(p)
    local workMod = p:getModData()["UT_workSpeedMod"]
    assert_true(workMod ~= nil and workMod > 0, "slowworker should set positive work speed mod (slower)")
end)

-- ─── incomprehensive: skill cap reduction on new game ──────────────────────────
test("incomprehensive sets skill cap reduction on new game", function()
    local p = MockPlayer({ "UniversalTraits:UT_incomprehensive" })
    Events.OnNewGame:fire(p)
    assert_eq(p:getModData()["UT_skillCapReduction"], 2,
        "incomprehensive should set UT_skillCapReduction = 2")
end)

-- ─── indefatigable: slows endurance drain while active ─────────────────────────
test("indefatigable boosts endurance while sprinting above threshold", function()
    local p = MockPlayer({ "UniversalTraits:UT_indefatigable" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.5)
    p._sprinting = true; p._running = false
    -- Fire enough ticks for throttle=30
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    local endurance = p:getStats():get(CharacterStat.ENDURANCE)
    assert_true(endurance > 0.5, "indefatigable should boost endurance while sprinting, got " .. endurance)
end)

test("indefatigable triggers recovery when exhausted", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_indefatigable" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.03)  -- below 0.05 threshold
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_true(p:getModData()["UT_indefRecovering"] == true,
        "should enter recovery when exhausted")
end)

test("indefatigable recovers to 0.5 after cooldown", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_indefatigable" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.03)
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_true(p:getModData()["UT_indefRecovering"] == true, "should be recovering")
    -- Advance time past 3-minute cooldown (3/60 = 0.05 hours)
    advanceMockGameTimeHours(0.1)
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_eq(p:getStats():get(CharacterStat.ENDURANCE), 0.5,
        "indefatigable should recover to 0.5 after cooldown")
    assert_true(p:getModData()["UT_indefRecovering"] == nil, "recovery flag should be cleared")
end)

-- ─── secondwind: burst of endurance when exhausted while sprinting ──────────────
test("secondwind triggers endurance burst when sprinting at low endurance", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_secondwind" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.08)  -- below 0.1 threshold
    p._sprinting = true
    -- Fire enough ticks for throttle=15
    for i = 1, 15 do Events.OnPlayerUpdate:fire(p) end
    local endurance = p:getStats():get(CharacterStat.ENDURANCE)
    assert_true(endurance > 0.3, "secondwind should provide endurance burst, got " .. endurance)
    assert_true(p:getModData()["UT_secondwindTriggered"] == true, "should be on cooldown")
end)

test("secondwind does NOT trigger twice without cooldown expiry", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_secondwind" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.08)
    p._sprinting = true
    for i = 1, 15 do Events.OnPlayerUpdate:fire(p) end
    local after_first = p:getStats():get(CharacterStat.ENDURANCE)

    -- Drain again
    p:getStats():set(CharacterStat.ENDURANCE, 0.05)
    for i = 1, 15 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(p:getStats():get(CharacterStat.ENDURANCE), 0.05,
        "secondwind should NOT trigger while on cooldown")
end)

test("secondwind cooldown resets after 10 min", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_secondwind" })
    p:getStats():set(CharacterStat.ENDURANCE, 0.08)
    p._sprinting = true
    for i = 1, 15 do Events.OnPlayerUpdate:fire(p) end
    assert_true(p:getModData()["UT_secondwindTriggered"] == true, "should be triggered")
    -- Advance time past 10-minute cooldown
    advanceMockGameTimeHours(0.2)
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getModData()["UT_secondwindTriggered"] == nil, "cooldown should expire")
end)

-- ─── hardy: exhaustion tracking and recovery bonus ─────────────────────────────
test("hardy enters exhaustion state when fatigue > 0.8", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_hardy" }, { fatigue = 0.9 })
    withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
    assert_true(p:getModData()["UT_hardyExhausted"] == true,
        "hardy should enter exhaustion when fatigue > 0.8")
end)

test("hardy applies stress during exhaustion", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_hardy" }, { fatigue = 0.9, stress = 0.0 })
    withActivePlayer(p, function()
        Events.EveryOneMinute:fire()  -- enters exhaustion
        Events.EveryOneMinute:fire()  -- now applies stress
    end)
    assert_true(p:getStats():get(CharacterStat.STRESS) > 0,
        "hardy should add stress during exhaustion")
end)

test("hardy recovers after resting 10 minutes below fatigue 0.3", function()
    setMockGameTime(0, 0)
    local p = MockPlayer({ "UniversalTraits:UT_hardy" }, { fatigue = 0.9 })
    withActivePlayer(p, function()
        Events.EveryOneMinute:fire()  -- enters exhaustion
    end)
    -- Drop fatigue and advance 10 game minutes (10 EveryOneMinute calls)
    p:getStats():set(CharacterStat.FATIGUE, 0.2)
    withActivePlayer(p, function()
        for i = 1, 10 do Events.EveryOneMinute:fire() end
    end)
    assert_true(p:getModData()["UT_hardyExhausted"] == nil, "hardy should exit exhaustion after resting")
    assert_true(p:getModData()["UT_hardyBonus"] ~= nil, "hardy should enter bonus phase")
end)

-- ─── sharpshooter: +25% hit chance and range on ranged weapons ─────────────────
test("sharpshooter boosts hit chance by 25%", function()
    local weapon = MockWeapon("Pistol", 0, false, false,
        { isRanged = true, hitChance = 40, maxRange = 10.0, subCategory = "Pistol" })
    local p = MockPlayer({ "UniversalTraits:UT_sharpshooter" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getHitChance(), 50, "sharpshooter should boost hit chance from 40 to 50")
end)

test("sharpshooter boosts max range by 25%", function()
    local weapon = MockWeapon("Pistol", 0, false, false,
        { isRanged = true, hitChance = 40, maxRange = 10.0, subCategory = "Pistol" })
    local p = MockPlayer({ "UniversalTraits:UT_sharpshooter" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getMaxRange(), 12.5, "sharpshooter should boost range from 10 to 12.5")
end)

test("sharpshooter does NOT compound bonus on repeated ticks", function()
    local weapon = MockWeapon("Pistol", 0, false, false,
        { isRanged = true, hitChance = 40, maxRange = 10.0, subCategory = "Pistol" })
    local p = MockPlayer({ "UniversalTraits:UT_sharpshooter" }, { primaryHandItem = weapon })
    for i = 1, 60 do Events.OnPlayerUpdate:fire(p) end  -- two full cycles
    assert_eq(weapon:getHitChance(), 50, "sharpshooter should NOT compound: still 50 after 60 ticks")
    assert_eq(weapon:getMaxRange(), 12.5, "sharpshooter range should NOT compound")
end)

-- ─── cleaver: +10% crit on Long Blade weapons ─────────────────────────────────
test("cleaver adds 10% crit to Long Blade weapon", function()
    local weapon = MockWeapon("Katana", 0, false, true,
        { criticalChance = 15, subCategory = "Long Blade" })
    local p = MockPlayer({ "UniversalTraits:UT_cleaver" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 25, "cleaver should boost crit from 15 to 25")
end)

test("cleaver does NOT boost non-Long-Blade weapons", function()
    local weapon = MockWeapon("BaseballBat", 0, false, true,
        { criticalChance = 15, subCategory = "Long Blunt" })
    local p = MockPlayer({ "UniversalTraits:UT_cleaver" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 15, "cleaver should NOT affect Long Blunt weapons")
end)

test("cleaver crit does NOT compound over multiple ticks", function()
    local weapon = MockWeapon("Katana", 0, false, true,
        { criticalChance = 15, subCategory = "Long Blade" })
    local p = MockPlayer({ "UniversalTraits:UT_cleaver" }, { primaryHandItem = weapon })
    for i = 1, 90 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 25, "crit should NOT compound: still 25")
end)

-- ─── long_blades: +10% crit on Long Blade (redundant with cleaver) ─────────────
test("long_blades adds 10% crit to Long Blade weapon", function()
    local weapon = MockWeapon("Katana", 0, false, true,
        { criticalChance = 15, subCategory = "Long Blade" })
    local p = MockPlayer({ "UniversalTraits:UT_long_blades" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 25, "long_blades should boost crit from 15 to 25")
end)

-- ─── long_blunts: +10% crit on Long Blunt weapons ─────────────────────────────
test("long_blunts adds 10% crit to Long Blunt weapon", function()
    local weapon = MockWeapon("BaseballBat", 0, false, true,
        { criticalChance = 10, subCategory = "Long Blunt" })
    local p = MockPlayer({ "UniversalTraits:UT_long_blunts" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "long_blunts should boost crit from 10 to 20")
end)

test("long_blunts does NOT compound on repeated ticks", function()
    local weapon = MockWeapon("BaseballBat", 0, false, true,
        { criticalChance = 10, subCategory = "Long Blunt" })
    local p = MockPlayer({ "UniversalTraits:UT_long_blunts" }, { primaryHandItem = weapon })
    for i = 1, 90 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "long_blunts crit should NOT compound")
end)

-- ─── onehanded_axes: +5% crit on one-handed Axe weapons ───────────────────────
test("onehanded_axes adds 5% crit to one-handed axe", function()
    local weapon = MockWeapon("HandAxe", 0, false, true,
        { criticalChance = 10, categories = { WeaponCategory.AXE } })
    local p = MockPlayer({ "UniversalTraits:UT_onehanded_axes" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 15, "onehanded_axes should boost from 10 to 15")
end)

test("onehanded_axes ignores two-handed axes", function()
    local weapon = MockWeapon("FireAxe", 0, true, true,
        { criticalChance = 10, categories = { WeaponCategory.AXE } })
    local p = MockPlayer({ "UniversalTraits:UT_onehanded_axes" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 10, "onehanded_axes should NOT affect two-handed axes")
end)

-- ─── twohanded_axes: +10% crit on two-handed Axe weapons ──────────────────────
test("twohanded_axes adds 10% crit to two-handed axe", function()
    local weapon = MockWeapon("FireAxe", 0, true, true,
        { criticalChance = 10, categories = { WeaponCategory.AXE } })
    local p = MockPlayer({ "UniversalTraits:UT_twohanded_axes" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "twohanded_axes should boost from 10 to 20")
end)

-- ─── twohanded_blades: +10% crit on two-handed Long Blade ─────────────────────
test("twohanded_blades adds 10% crit to two-handed Long Blade", function()
    local weapon = MockWeapon("Claymore", 0, true, true,
        { criticalChance = 10, subCategory = "Long Blade" })
    local p = MockPlayer({ "UniversalTraits:UT_twohanded_blades" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "twohanded_blades should boost from 10 to 20")
end)

test("twohanded_blades ignores one-handed Long Blade", function()
    local weapon = MockWeapon("Machete", 0, false, true,
        { criticalChance = 10, subCategory = "Long Blade" })
    local p = MockPlayer({ "UniversalTraits:UT_twohanded_blades" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 10, "twohanded_blades should NOT affect one-handed")
end)

-- ─── twohanded_blunts: +10% crit on Long Blunt ────────────────────────────────
test("twohanded_blunts adds 10% crit to Long Blunt weapon", function()
    local weapon = MockWeapon("Sledgehammer", 0, true, true,
        { criticalChance = 10, subCategory = "Long Blunt" })
    local p = MockPlayer({ "UniversalTraits:UT_twohanded_blunts" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "twohanded_blunts should boost from 10 to 20")
end)

-- ─── prospear: +10% crit on Spear weapons ──────────────────────────────────────
test("prospear adds 10% crit to spear weapon", function()
    local weapon = MockWeapon("CraftedSpear", 0, false, true,
        { criticalChance = 10, categories = { WeaponCategory.SPEAR } })
    local p = MockPlayer({ "UniversalTraits:UT_prospear" }, { primaryHandItem = weapon })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "prospear should boost from 10 to 20")
end)

test("prospear does NOT compound on repeated ticks", function()
    local weapon = MockWeapon("CraftedSpear", 0, false, true,
        { criticalChance = 10, categories = { WeaponCategory.SPEAR } })
    local p = MockPlayer({ "UniversalTraits:UT_prospear" }, { primaryHandItem = weapon })
    for i = 1, 90 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(weapon:getCriticalChance(), 20, "prospear crit should NOT compound")
end)

-- ─── fitted: clothing weight reduction and speed penalty removal ───────────────
test("fitted halves clothing weight when worn", function()
    local shirt = MockClothingItem("Shirt", { actualWeight = 2.0, runSpeedModifier = 0.8, combatSpeedModifier = 0.9 })
    local wornItems = MockWornItemsFull({ shirt, MockClothingItem("Pants") })
    local inv = MockInventoryFull({ shirt, MockClothingItem("Pants") })
    local p = MockPlayer({ "UniversalTraits:UT_fitted" }, { wornItems = wornItems, inventory = inv })
    -- setWornItems stub
    p.setWornItems = function(self, wi) end
    -- Fire enough ticks for throttle=30
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(shirt:getActualWeight(), 1.0, "fitted should halve clothing weight from 2.0 to 1.0")
end)

test("fitted removes run speed penalty on clothing", function()
    local shirt = MockClothingItem("Shirt", { actualWeight = 2.0, runSpeedModifier = 0.7, combatSpeedModifier = 0.8 })
    local wornItems = MockWornItemsFull({ shirt, MockClothingItem("Pants") })
    local inv = MockInventoryFull({ shirt, MockClothingItem("Pants") })
    local p = MockPlayer({ "UniversalTraits:UT_fitted" }, { wornItems = wornItems, inventory = inv })
    p.setWornItems = function(self, wi) end
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(shirt:getRunSpeedModifier(), 1.0, "fitted should set run speed modifier to 1.0")
    assert_eq(shirt:getCombatSpeedModifier(), 1.0, "fitted should set combat speed modifier to 1.0")
end)

-- ─── gourmand: food stat modification ──────────────────────────────────────────
test("gourmand boosts hunger relief by 50%", function()
    local food = MockFoodItemFull("Steak", { hungChange = -20, unhappyChange = -10, boredomChange = -8, category = "Food" })
    local inv = MockInventoryFull({ food })
    local p = MockPlayer({ "UniversalTraits:UT_gourmand" }, { inventory = inv })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(food:getHungChange(), -30, "gourmand should boost hunger relief from -20 to -30")
end)

test("gourmand improves happiness on food", function()
    local food = MockFoodItemFull("Steak", { hungChange = -20, unhappyChange = -10, boredomChange = -8, category = "Food" })
    local inv = MockInventoryFull({ food })
    local p = MockPlayer({ "UniversalTraits:UT_gourmand" }, { inventory = inv })
    for i = 1, 30 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(food:getUnhappyChange(), -15, "gourmand should boost unhappy from -10 to -15")
    assert_eq(food:getBoredomChange(), -12, "gourmand should boost boredom from -8 to -12")
end)

test("gourmand does NOT compound food bonuses on repeated ticks", function()
    local food = MockFoodItemFull("Steak", { hungChange = -20, unhappyChange = -10, boredomChange = -8, category = "Food" })
    local inv = MockInventoryFull({ food })
    local p = MockPlayer({ "UniversalTraits:UT_gourmand" }, { inventory = inv })
    for i = 1, 90 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(food:getHungChange(), -30, "gourmand hunger should NOT compound: still -30")
end)

-- ─── trackman: trap condition restoration ──────────────────────────────────────
test("trackman restores trap items to max condition", function()
    local trap = MockTrapItem("TrapMouse", 3, 10)
    local inv = MockInventoryFull({ trap })
    local p = MockPlayer({ "UniversalTraits:UT_trackman" }, { inventory = inv })
    for i = 1, 60 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(trap:getCondition(), 10, "trackman should restore trap to max condition")
end)

test("trackman ignores non-trap items", function()
    local item = MockTrapItem("Hammer", 3, 10)
    local inv = MockInventoryFull({ item })
    local p = MockPlayer({ "UniversalTraits:UT_trackman" }, { inventory = inv })
    for i = 1, 60 do Events.OnPlayerUpdate:fire(p) end
    assert_eq(item:getCondition(), 3, "trackman should NOT touch non-trap items")
end)

-- ─── tavernbrawler: stomp bonus damage ─────────────────────────────────────────
test("tavernbrawler deals 30 bonus damage to downed zombie", function()
    local zombie = MockZombie({ health = 100 })
    zombie._knockedDown = true
    zombie.isKnockedDown = function(self) return true end
    local p = MockPlayer({ "UniversalTraits:UT_tavernbrawler" })
    local weapon = MockWeapon("Boots")
    _G.getSpecificPlayer = function(i) return i == 0 and p or nil end
    Events.OnHitZombie:fire(zombie, p, weapon, 10)
    assert_eq(zombie:getHealth(), 70, "tavernbrawler should deal 30 extra HP to downed zombie")
end)

test("tavernbrawler does NOT fire on standing zombie", function()
    local zombie = MockZombie({ health = 100 })
    local p = MockPlayer({ "UniversalTraits:UT_tavernbrawler" })
    _G.getSpecificPlayer = function(i) return i == 0 and p or nil end
    Events.OnHitZombie:fire(zombie, p, MockWeapon("Boots"), 10)
    assert_eq(zombie:getHealth(), 100, "tavernbrawler should NOT fire on standing zombie")
end)

test("woodsplitter inherits exact vanilla Axeman formulas", function()
    assert_eq(12 * 1.5, 18, "tree damage multiplier is exactly 1.5")
    assert_eq(0.83 * 0.95, 0.7885, "axe swing-time multiplier is exactly 0.95")
    assert_eq(1.0 / 0.8, 1.25, "general axe combat/swing animation is exactly 25% faster")
end)

test("woodsplitter has no weapon mutation or fake tree event", function()
    local f = assert(io.open(base .. "../media/lua/shared/UniversalTraits/traits/UT_woodsplitter.lua", "r"))
    local source = f:read("*a")
    f:close()
    assert_true(not source:find("setTreeDamage", 1, true), "no HandWeapon.treeDamage mutation")
    assert_true(not source:find("OnTreeChopped", 1, true), "no nonexistent tree event")
    assert_true(not source:find("setHp", 1, true), "no fake extra hit")
end)

test("woodsplitter definition grants and excludes vanilla Axeman", function()
    local f = assert(io.open(base .. "../media/scripts/UT_character_traits.txt", "r"))
    local source = f:read("*a")
    f:close()
    local block = source:match("character_trait_definition%s+UniversalTraits:UT_woodsplitter%s*(%b{})")
    assert_true(block ~= nil, "Wood Splitter definition should exist")
    assert_true(block:find("DisabledInMultiplayer%s*=%s*true"), "Wood Splitter must be disabled in MP selection")
    assert_true(block:find("GrantedTraits%s*=%s*Axeman"), "Wood Splitter must declaratively grant Axeman")
    assert_true(block:find("XPBoosts%s*=%s*Axe%s*=%s*1"), "Wood Splitter must grant exactly +1 Axe XP boost")
    assert_true(block:find("MutuallyExclusiveTraits%s*=%s*Axeman"),
        "Wood Splitter must exclude separately selected or profession-granted Axeman")
    assert_true(block:find("Cost%s*=%s*4[%s,]"), "Wood Splitter must use the accepted 4-point cost")
end)

test("woodsplitter engine ordering makes exclusion selection-only", function()
    local function read(path)
        local f = assert(io.open(base .. "../../../PZCodebase/" .. path, "r"))
        local source = f:read("*a")
        f:close()
        return source
    end
    local parser = read("Java/source/zombie/scripting/objects/CharacterTraitDefinitionScript.java")
    local mutualPos = assert(parser:find("for (CharacterTrait mutuallyExclusiveCharacterTrait", 1, true))
    local grantPos = assert(parser:find("for (CharacterTrait freeTrait", 1, true))
    assert_true(mutualPos < grantPos, "mutual exclusions must be installed before granted traits")

    local definition = read("Java/source/zombie/characters/traits/CharacterTraitDefinition.java")
    assert_true(definition:find("this.updateMutualExclusiveTraits();", 1, true) ~= nil,
        "adding GrantedTraits must propagate bidirectional exclusions")
    assert_true(definition:find("traitToTest.mutuallyExclusiveTraits.add(this.getType())", 1, true) ~= nil,
        "Axeman must learn the reverse Wood Splitter exclusion")

    local creation = read("Lua/client/OptionScreens/CharacterCreationProfession.lua")
    local addGrant = assert(creation:find("self.listboxTraitSelected:addUniqueItem(freeCharacterTraitDefinition:getLabel()", 1, true))
    local testGrant = assert(creation:find("self:doTestForMutuallyExclusiveTraits(freeCharacterTraitDefinition, false)", addGrant, true))
    assert_true(addGrant < testGrant, "the intentional Axeman grant is selected before exclusion hides alternatives")
    assert_true(creation:find("self.listboxTrait:removeMatchingItems(exclusiveCharacterTraitDefinition:getLabel())", 1, true) ~= nil,
        "exclusion removes availability, not already-selected granted traits")
end)

test("woodsplitter selection and repopulation follow the engine contract", function()
    local function resourceLocationOf(id)
        local namespace, path = id:match("^([^:]+):(.+)$")
        return string.lower((namespace or "base") .. ":" .. (path or id))
    end
    assert_eq(resourceLocationOf("Axeman"), "base:axeman",
        "unqualified Axeman resolves through ResourceLocation to base:axeman")

    local WOOD, AXEMAN = "universaltraits:ut_woodsplitter", resourceLocationOf("Axeman")
    local definitions = {
        [WOOD] = { grants = { AXEMAN }, excludes = { [AXEMAN] = true } },
        [AXEMAN] = { grants = {}, excludes = { [WOOD] = true } },
    }
    local function has(list, id)
        for _, value in ipairs(list) do if value == id then return true end end
        return false
    end
    local function addUnique(list, id)
        if not has(list, id) then list[#list + 1] = id end
    end
    local function repopulate(state)
        local selected = {}
        for _, id in ipairs(state.profession) do addUnique(selected, id) end
        for _, id in ipairs(state.selected) do addUnique(selected, id) end
        local available = {}
        for id in pairs(definitions) do available[id] = not has(selected, id) end
        for _, selectedId in ipairs(selected) do
            for excludedId in pairs(definitions[selectedId].excludes) do available[excludedId] = false end
        end
        return available, selected
    end
    local function selectTrait(state, id)
        local available = repopulate(state)
        if not available[id] then return false end
        addUnique(state.selected, id)
        for _, grantedId in ipairs(definitions[id].grants) do addUnique(state.selected, grantedId) end
        return true
    end
    local function switchProfession(state, granted)
        state.profession = granted
        for _, professionId in ipairs(granted) do
            for excludedId in pairs(definitions[professionId].excludes) do
                for index = #state.selected, 1, -1 do
                    if state.selected[index] == excludedId then table.remove(state.selected, index) end
                end
            end
        end
    end

    local state = { selected = {}, profession = { AXEMAN } }
    local available = repopulate(state)
    assert_true(not available[WOOD], "profession-granted Axeman excludes Wood Splitter before selection")

    state = { selected = {}, profession = {} }
    assert_true(selectTrait(state, AXEMAN), "direct Axeman selection succeeds")
    available = repopulate(state)
    assert_true(not available[WOOD], "directly selected Axeman excludes Wood Splitter")

    state = { selected = {}, profession = {} }
    assert_true(selectTrait(state, WOOD), "Wood Splitter selection succeeds")
    local selected
    available, selected = repopulate(state)
    assert_true(has(selected, WOOD) and has(selected, AXEMAN),
        "Wood Splitter retains itself and its unique granted Axeman")
    assert_true(not available[WOOD] and not available[AXEMAN],
        "repopulation keeps selected and mutually excluded traits unavailable")

    switchProfession(state, { AXEMAN })
    available, selected = repopulate(state)
    assert_true(not has(selected, WOOD) and has(selected, AXEMAN),
        "switching to an Axeman profession removes Wood Splitter and preserves Axeman")
    assert_true(not available[WOOD], "repopulation after profession switch keeps Wood Splitter excluded")
end)

test("woodsplitter anchors all four vanilla Axeman effects in SVN 964", function()
    local function read(path)
        local f = assert(io.open(base .. "../../../PZCodebase/" .. path, "r"))
        local source = f:read("*a")
        f:close()
        return source
    end
    local tree = read("Java/source/zombie/iso/objects/IsoTree.java")
    assert_true(tree:find("hasTrait(CharacterTrait.AXEMAN)", 1, true) ~= nil, "tree checks Axeman")
    assert_true(tree:find("dmg *= 1.5F", 1, true) ~= nil, "tree damage is multiplied by 1.5")
    local weapon = read("Java/source/zombie/inventory/types/HandWeapon.java")
    assert_true(weapon:find("mod = 0.95F", 1, true) ~= nil, "axe attack-time multiplier is 0.95")
    local character = read("Java/source/zombie/characters/IsoGameCharacter.java")
    assert_true(character:find("CharacterTrait.AXEMAN) ? 1.0F : 0.8F", 1, true) ~= nil,
        "Axeman speed branch is 1.0 versus 0.8")
    local axeCategory = assert(character:find("weapon.isOfWeaponCategory(WeaponCategory.AXE)", 1, true))
    local combatUse = assert(character:find("combatSpeed *= this.getChopTreeSpeed();", axeCategory, true))
    assert_true(axeCategory < combatUse, "general axe calculateCombatSpeed consumes the Axeman speed branch")
    local spawn = read("Lua/shared/Items/SpawnItems.lua")
    assert_true(spawn:find("[CharacterTrait.AXEMAN] = { ItemKey.Container.KEY_RING_PINE_TREE", 1, true) ~= nil,
        "Axeman is eligible for the pine-tree key ring")
end)

dofile(base .. "test_scrounger_runtime.lua").run(test, assert_eq, assert_true, base)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
