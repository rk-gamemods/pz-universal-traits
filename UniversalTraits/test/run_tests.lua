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

-- Verify all 96 expected trait IDs are registered in CharacterTrait._registered
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
}

test("all 99 trait IDs registered with CharacterTrait", function()
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

test("total registration count is 99", function()
    local count = 0
    for _ in pairs(CharacterTrait._registered) do count = count + 1 end
    assert_eq(count, 99, "registration count")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
