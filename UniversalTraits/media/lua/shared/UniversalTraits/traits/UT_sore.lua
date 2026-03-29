-- UT_sore.lua
-- Source: FillerTraits UpgradeTraits.lua:283-284 — Sore().
-- OnPlayerUpdate: pain never drops below 20.

local TRAIT_ID = "UniversalTraits:UT_sore"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyStatFloor(player, CharacterStat.PAIN, 20)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
