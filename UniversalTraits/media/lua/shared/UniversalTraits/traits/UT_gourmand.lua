-- UT_gourmand.lua
-- Gourmand: adds 50% of each beneficial hunger, boredom, and unhappiness
-- change after food is actually consumed.
-- The post-consumption mechanism is implemented by UT_ItemConsumptionHooks.lua.

local TRAIT_ID = "UniversalTraits:UT_gourmand" -- luacheck: ignore (handled by the shared hook)
