-- java_api_validation.lua
-- Validates that every Java method name called from our Lua code
-- actually exists on the real PZ Java class. Reads the decompiled
-- Java source under PZCodebase/Java/source and extracts public method
-- signatures, then asserts each declared call is found.
--
-- This exists because Lua mocks happily accept ANY method name — a
-- typo like p:isInfected() vs p:IsInfected() passes every mock test
-- but crashes in-game. This validator is the seatbelt.
--
-- To add coverage: append entries to CALL_MANIFEST below. Format:
--   { class = "BodyPart", method = "SetBitten", file = "<lua>:<line>" }

local M = {}

-- Map class short names to the absolute Java file path.
-- `base` is the run_tests.lua directory.
local function classFiles(base)
    local src = base .. "../../../PZCodebase/Java/source/"
    return {
        BodyPart        = src .. "zombie/characters/BodyDamage/BodyPart.java",
        BodyDamage      = src .. "zombie/characters/BodyDamage/BodyDamage.java",
        IsoPlayer       = src .. "zombie/characters/IsoPlayer.java",
        IsoGameCharacter = src .. "zombie/characters/IsoGameCharacter.java",
    }
end

-- Extract public method names from a Java source file.
-- Matches `public <return-type> <name>(` at any indent; ignores constructors
-- (constructors have no return type, so `public ClassName(` is skipped by
-- requiring a return type token before the name).
local function extractMethods(path)
    local f = io.open(path, "r")
    if not f then
        error("Java source not found: " .. path)
    end
    local content = f:read("*a")
    f:close()
    local methods = {}
    -- Pattern: "public" + optional "static"/"final" + return type token + name + "("
    -- Return-type token can be `boolean`, `void`, `float`, `String`, `ArrayList<...>`, etc.
    -- We use a permissive regex: public (static|final| )* <TYPE> <NAME>(
    for ret, name in content:gmatch("public%s+([%w_<>%[%],%s%.]-)%s+([%w_]+)%s*%(") do
        -- Reject constructor (ret will be empty string when pattern hits "public <Name>(")
        -- and common keyword false-positives.
        if ret ~= "" and ret ~= "class" and ret ~= "interface" and ret ~= "enum" then
            methods[name] = true
        end
    end
    return methods
end

-- Lua code's declared Java API calls. Update this when adding new calls.
-- Each entry is { class, method, source }.
M.CALL_MANIFEST = {
    -- UT_bouncer_I.lua — injury reads/writes
    { class = "BodyPart", method = "bitten",           source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "isDeepWounded",    source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "getFractureTime",  source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "IsInfected",       source = "UT_bouncer_I.lua / UTCore_TickDispatch.lua" },
    { class = "BodyPart", method = "HasInjury",        source = "UTCore_TickDispatch.lua" },
    { class = "BodyPart", method = "SetBitten",        source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "setBiteTime",      source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "SetInfected",      source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "SetFakeInfected",  source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "setDeepWounded",   source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "setDeepWoundTime", source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "setScratched",     source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "setFractureTime",  source = "UT_bouncer_I.lua" },
    { class = "BodyPart", method = "getType",          source = "UT_bouncer_I.lua" },

    -- UTCore_TickDispatch.lua — body damage gates
    { class = "BodyDamage", method = "getOverallBodyHealth", source = "UTCore_TickDispatch.lua" },
    { class = "BodyDamage", method = "getBodyParts",         source = "UTCore_TickDispatch.lua / UT_bouncer_I.lua" },
}

function M.run(base, test, assert_true)
    local files = classFiles(base)
    local cache = {}
    local function methodsOf(cls)
        if cache[cls] then return cache[cls] end
        local p = files[cls]
        assert(p, "no Java file mapping for class " .. tostring(cls))
        cache[cls] = extractMethods(p)
        return cache[cls]
    end

    for _, entry in ipairs(M.CALL_MANIFEST) do
        local testName = string.format("java API: %s.%s exists [%s]",
            entry.class, entry.method, entry.source)
        test(testName, function()
            local m = methodsOf(entry.class)
            assert_true(m[entry.method] == true,
                entry.class .. "." .. entry.method ..
                "() not found in decompiled Java source — " ..
                "called from " .. entry.source)
        end)
    end
end

return M
