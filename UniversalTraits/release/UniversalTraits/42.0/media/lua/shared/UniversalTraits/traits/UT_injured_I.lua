-- UT_injured_I.lua
-- Injured (minor): two body parts damaged, stress

local TRAIT_ID = "UniversalTraits:UT_injured_I"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    UTCore.applySpawnCondition(player, {
        injuries = {BodyPartType.Hand_L, BodyPartType.Foot_L}
    })

    UTCore.applySpawnStats(player, {
        stress = 0.3
    })
end

Events.OnNewGame.Add(onNewGame)
