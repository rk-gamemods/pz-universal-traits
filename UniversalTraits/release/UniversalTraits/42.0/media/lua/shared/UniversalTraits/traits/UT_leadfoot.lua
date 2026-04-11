-- UT_leadfoot.lua
-- Lead Foot: +20% vehicle top speed while driving (same tier as UT_driver).
-- Uses UTCore vehicle trait system: applied once on vehicle enter, restored on exit.
-- This replaces the old shoe stommp-power implementation which did not match the description.

local TRAIT_ID = "UniversalTraits:UT_leadfoot"

UTCore.registerVehicleTrait(TRAIT_ID, "UT_leadfootState", {
    maxSpeed = 1.2,
}, 1)
