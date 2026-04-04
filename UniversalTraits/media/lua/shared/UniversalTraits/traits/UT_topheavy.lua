-- UT_topheavy.lua
-- Source: FillerTraits UpgradeTraits.lua:188-194 — IndomTimecheck().
-- OnPlayerUpdate: carry weight = 5 + Strength - 3 (reduces base by 3; default is 5+Strength+0).

local TRAIT_ID = "UniversalTraits:UT_topheavy"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyStrengthCarryWeight(player, -3)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
