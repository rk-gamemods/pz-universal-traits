-- UT_anorexy.lua
-- Anorexy: adds 0.10 stress after food is consumed.
-- Runtime behavior is owned by UT_ItemConsumptionHooks.lua.

local TRAIT_ID = "UniversalTraits:UT_anorexy"

-- Remove the obsolete polling registration during a same-process script reload.
UTCore.unregisterTickHandler(TRAIT_ID, "consumption-hook")
