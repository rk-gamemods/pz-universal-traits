-- UT_injured_I.lua
-- Injured (minor): two light wounds and stress

local TRAIT_ID = "UniversalTraits:UT_injured_I"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    UTCore.applySpawnCondition(player, {
        scratches = {BodyPartType.Hand_L, BodyPartType.Foot_L}
    })

    UTCore.applySpawnStats(player, {
        stress = 0.3
    })
end

Events.OnNewGame.Add(onNewGame)
