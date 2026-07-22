-- UT_competitiveeater.lua
-- Competitive Eater: removes 10 boredom and 0.05 hunger after food is consumed.
-- Runtime behavior is owned by UT_ItemConsumptionHooks.lua.

local TRAIT_ID = "UniversalTraits:UT_competitiveeater"

-- Remove the obsolete polling registration during a same-process script reload.
UTCore.unregisterTickHandler(TRAIT_ID, "consumption-hook")
