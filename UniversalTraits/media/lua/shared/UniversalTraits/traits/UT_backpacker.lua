-- UT_backpacker.lua
-- Source: FillerTraits UpgradeTraits.lua:188-194 — IndomTimecheck().
-- OnPlayerUpdate: carry weight = 5 + Strength + 4 (scales dynamically with Strength).

local TRAIT_ID = "UniversalTraits:UT_backpacker"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyStrengthCarryWeight(player, 4, TRAIT_ID)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
