-- UT_injured_II.lua
-- Injured (severe): four body parts damaged, stress and fatigue

local TRAIT_ID = "UniversalTraits:UT_injured_II"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    UTCore.applySpawnCondition(player, {
        injuries = {BodyPartType.Hand_L, BodyPartType.Hand_R, BodyPartType.Foot_L, BodyPartType.Torso_Upper}
    })

    UTCore.applySpawnStats(player, {
        stress = 0.6,
        fatigue = 0.4
    })
end

Events.OnNewGame.Add(onNewGame)
