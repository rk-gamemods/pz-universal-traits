-- UT_antivaxxer.lua
-- Anti-Vaxxer: stress spike when consuming medication (pills and injectables).
-- Beta blockers are explicitly excluded (they calm the user, not trigger paranoia).
-- Mechanic is handled centrally by UT_ItemConsumptionHooks.lua (ISEatFoodAction.perform override).
--   Detected item types: Antibiotics, Painkillers, SleepingTablets, Antidepressants, etc.
--   Excluded: BetaBlockers.
--   Effect: +0.20 stress immediately when medication is consumed.

local TRAIT_ID = "UniversalTraits:UT_antivaxxer" -- luacheck: ignore (referenced by UT_ItemConsumptionHooks)

