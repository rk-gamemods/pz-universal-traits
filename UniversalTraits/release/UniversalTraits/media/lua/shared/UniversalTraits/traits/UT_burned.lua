-- UT_burned.lua
-- Burned: severe burns on upper body and hands, high stress/fatigue/panic

local TRAIT_ID = "UniversalTraits:UT_burned"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    UTCore.applySpawnCondition(player, {
        burnSeverity = 0.6,
        injuries = {BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Torso_Upper}
    })

    UTCore.applySpawnStats(player, {
        stress = 0.7,
        fatigue = 0.5,
        panic = 0.3
    })
end

Events.OnNewGame.Add(onNewGame)
