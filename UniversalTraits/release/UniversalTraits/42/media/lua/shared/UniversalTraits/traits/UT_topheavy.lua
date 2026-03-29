-- UT_topheavy.lua
-- Source: FillerTraits UpgradeTraits.lua:188-194 — IndomTimecheck().
-- OnPlayerUpdate: carry weight = 5 + Strength + 2 (scales dynamically, penalised vs default).

local TRAIT_ID = "UniversalTraits:UT_topheavy"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyStrengthCarryWeight(player, 2)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
