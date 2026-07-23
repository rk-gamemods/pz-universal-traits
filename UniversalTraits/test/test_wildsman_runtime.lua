local M = {}

function M.run(test, assert_eq, assert_true, base)
    local runtimePath = base .. "../media/lua/shared/UniversalTraits/traits/UT_wildsman.lua"
    local function assert_close(actual, expected, message)
        assert_true(math.abs(actual - expected) <= 1e-12,
            (message or "values differ") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
    local saved = {
        Events = Events,
        Fishing = Fishing,
        ISBaseIcon = ISBaseIcon,
        UTCore = UTCore,
        UTWildsmanRuntime = UTWildsmanRuntime,
        ZombRand = ZombRand,
    }

    local function scenario(options)
        options = options or {}
        local onGameStart = {}
        local onNewGame = {}
        local randomValues = options.randomValues or {}
        local randomIndex = 0
        local player = { hasWildsman = options.hasTrait ~= false }

        Events = {
            OnGameStart = {
                Add = function(handler) onGameStart[#onGameStart + 1] = handler end,
            },
            OnNewGame = {
                Add = function(handler) onNewGame[#onNewGame + 1] = handler end,
            },
        }
        UTCore = {
            hasTrait = function(actual, traitId)
                assert_eq(actual, player, "Wildsman must check the forage or fishing character")
                assert_eq(traitId, "UniversalTraits:UT_wildsman")
                return actual.hasWildsman
            end,
        }
        ZombRand = function(limit)
            randomIndex = randomIndex + 1
            local value = randomValues[randomIndex]
            assert_true(value ~= nil, "unexpected Wildsman random roll")
            assert_true(value >= 0 and value < limit, "Wildsman mock roll must fit the engine bound")
            return value
        end

        ISBaseIcon = {
            initItemCount = function(self)
                self.originalCalls = (self.originalCalls or 0) + 1
                self.itemCount = self.baseCount
            end,
        }
        Fishing = {
            Fish = {
                createFish = function(self)
                    self.originalCalls = (self.originalCalls or 0) + 1
                    return self.nextFish
                end,
            },
        }
        UTWildsmanRuntime = nil

        dofile(runtimePath)
        local firstForageWrapper = ISBaseIcon.initItemCount
        local firstFishWrapper = Fishing.Fish.createFish
        if options.reload then dofile(runtimePath) end

        local function makeIcon(baseCount)
            return setmetatable({ character = player, baseCount = baseCount }, { __index = ISBaseIcon })
        end

        local function makeFish(overrides)
            overrides = overrides or {}
            local values = {
                calories = 120,
                lipids = 8,
                carbohydrates = 4,
                proteins = 20,
                baseHunger = -0.2,
                hungChange = -0.2,
                actualWeight = 6,
                worldScale = 0.5,
            }
            local modData = overrides.modData or {
                fishing_FishSize = 50,
                fishing_FishHandItem = "Trout_Hand_Medium",
            }
            return {
                getModData = function() return modData end,
                getCalories = function() return values.calories end,
                setCalories = function(_, value) values.calories = value end,
                getLipids = function() return values.lipids end,
                setLipids = function(_, value) values.lipids = value end,
                getCarbohydrates = function() return values.carbohydrates end,
                setCarbohydrates = function(_, value) values.carbohydrates = value end,
                getProteins = function() return values.proteins end,
                setProteins = function(_, value) values.proteins = value end,
                getBaseHunger = function() return values.baseHunger end,
                setBaseHunger = function(_, value) values.baseHunger = value end,
                getHungChange = function() return values.hungChange end,
                setHungChange = function(_, value) values.hungChange = value end,
                getActualWeight = function() return values.actualWeight end,
                setActualWeight = function(_, value) values.actualWeight = value end,
                setWorldScale = function(_, value) values.worldScale = value end,
                values = values,
            }
        end

        local function makeProducer(item, character)
            return setmetatable({
                character = character == false and nil or player,
                nextFish = item,
                fishSize = 2.5,
                fishSizeLen = 50,
            }, { __index = Fishing.Fish })
        end

        return {
            player = player,
            makeIcon = makeIcon,
            makeFish = makeFish,
            makeProducer = makeProducer,
            onGameStart = onGameStart,
            onNewGame = onNewGame,
            randomCalls = function() return randomIndex end,
            firstForageWrapper = firstForageWrapper,
            firstFishWrapper = firstFishWrapper,
        }
    end

    test("wildsman installs only supported reload-safe forage and fishing hooks", function()
        local s = scenario({ reload = true })
        assert_eq(ISBaseIcon.initItemCount, s.firstForageWrapper, "reload must not wrap forage counts twice")
        assert_eq(Fishing.Fish.createFish, s.firstFishWrapper, "reload must not wrap fish creation twice")
        assert_eq(#s.onNewGame, 0, "Wildsman must not retain an event that only writes unused flags")
        assert_eq(#s.onGameStart, 1, "one deferred installer must cover late class availability")
    end)

    test("wildsman applies an exact expected 30 percent bonus to integer forage counts", function()
        local s = scenario({ randomValues = { 29, 30, 19, 20 } })
        local cases = {
            { base = 1, expected = 2 },
            { base = 1, expected = 1 },
            { base = 4, expected = 6 },
            { base = 4, expected = 5 },
            { base = 10, expected = 13 },
        }
        for _, case in ipairs(cases) do
            local icon = s.makeIcon(case.base)
            icon:initItemCount()
            assert_eq(icon.originalCalls, 1, "vanilla count generation must run exactly once")
            assert_eq(icon.itemCount, case.expected)
        end
        assert_eq(s.randomCalls(), 4, "only fractional bonuses require a random roll")

        local control = scenario({ hasTrait = false })
        local icon = control.makeIcon(4)
        icon:initItemCount()
        assert_eq(icon.itemCount, 4, "non-Wildsman forage yield must remain vanilla")
        assert_eq(control.randomCalls(), 0)
    end)

    test("wildsman scales the current fish result without a nonexistent world-scale getter", function()
        local s = scenario()
        local fish = s.makeFish()
        local producer = s.makeProducer(fish)
        local produced = producer:createFish({})

        assert_eq(produced, fish)
        assert_eq(producer.originalCalls, 1)
        assert_eq(fish.values.calories, 180)
        assert_eq(fish.values.lipids, 12)
        assert_eq(fish.values.carbohydrates, 6)
        assert_eq(fish.values.proteins, 30)
        assert_close(fish.values.baseHunger, -0.3)
        assert_close(fish.values.hungChange, -0.3)
        assert_eq(fish.values.actualWeight, 9)
        assert_eq(fish.values.worldScale, 0.75, "world scale is derived from vanilla fishing length")
        assert_eq(fish:getModData().fishing_FishSize, 75)
        assert_eq(producer.fishSize, 3.75)
        assert_eq(producer.fishSizeLen, 75)
        assert_eq(fish:getModData().UT_wildsmanFishScaled, true)
    end)

    test("wildsman leaves controls and already-scaled fish unchanged", function()
        local control = scenario({ hasTrait = false })
        local ordinaryFish = control.makeFish()
        control.makeProducer(ordinaryFish):createFish({})
        assert_eq(ordinaryFish.values.actualWeight, 6)
        assert_eq(ordinaryFish:getModData().UT_wildsmanFishScaled, nil)

        local s = scenario()
        local fish = s.makeFish()
        local first = s.makeProducer(fish)
        local second = s.makeProducer(fish)
        first:createFish({})
        second:createFish({})
        assert_eq(fish.values.actualWeight, 9, "the same caught item must not scale twice")
        assert_eq(fish.values.calories, 180)
    end)

    Events = saved.Events
    Fishing = saved.Fishing
    ISBaseIcon = saved.ISBaseIcon
    UTCore = saved.UTCore
    UTWildsmanRuntime = saved.UTWildsmanRuntime
    ZombRand = saved.ZombRand
end

return M
