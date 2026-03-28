-- UT_ascetic.lua
-- Warns if eating too frequently; penalizes mood if eating within 5 minutes of last meal

local TRAIT_ID = "UniversalTraits:UT_ascetic"

local function onEat(player, food)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local modData = player:getModData()
    local currentWorldAgeHours = getGameTime():getWorldAgeHours()
    local lastAteHours = modData["UT_ateRecently"]

    -- Check if ate within last 5 minutes (5/60 hours)
    if lastAteHours and (currentWorldAgeHours - lastAteHours) < (5 / 60) then
        print("WARNING: Ascetic trait - eating too soon after last meal!")
    end

    -- Update last meal time
    modData["UT_ateRecently"] = currentWorldAgeHours
    modData["UT_asceticPenalty"] = true
end

Events.OnEat.Add(onEat)
