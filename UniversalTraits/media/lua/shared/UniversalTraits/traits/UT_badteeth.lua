-- UT_badteeth.lua
-- Bad Teeth: adds head pain equal to 1 percent of the food-healing timer increase.
-- Runtime behavior is owned by UT_ItemConsumptionHooks.lua.

local TRAIT_ID = "UniversalTraits:UT_badteeth"

-- Remove the obsolete polling registration during a same-process script reload.
UTCore.unregisterPeriodicHandler(TRAIT_ID, "OnPlayerUpdate")
