-- UT_allergic.lua
-- Allergic: food allergy triggers a food sickness spike when eating.
-- The eating detection and sickness spike are handled centrally by
-- UT_ItemConsumptionHooks.lua (ISEatFoodAction.perform override).
-- This file registers the trait ID for trait-check purposes only.
--
-- Mechanic summary:
--   On eating any non-medication food: 30% chance to add +20 food sickness.
--   Food sickness causes nausea/vomiting and health degradation at high levels.
--   Subsides naturally over ~30 minutes of game time.
--   No specific treatment item; rest and hydration are the player's options.

local TRAIT_ID = "UniversalTraits:UT_allergic" -- luacheck: ignore (referenced by UT_ItemConsumptionHooks)

