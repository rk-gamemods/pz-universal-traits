-- UT_broke.lua
-- Broken leg: left foot fractured and injured, high stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_broke"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    UTCore.applySpawnCondition(player, {
        fractures = {BodyPartType.Foot_L},
        injuries = {BodyPartType.Foot_L}
    })

    UTCore.applySpawnStats(player, {
        stress = 0.5,
        fatigue = 0.3
    })

    player:getModData()["UT_brokenLeg"] = true
end

Events.OnNewGame.Add(onNewGame)
