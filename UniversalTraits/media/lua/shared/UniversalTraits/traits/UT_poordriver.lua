-- UT_poordriver.lua
local TRAIT_ID = "UniversalTraits:UT_poordriver"

UTCore.registerVehicleTrait(TRAIT_ID, "UT_poorState", {
    maxSpeed       = 0.75,
    brakingForce   = 0.5,
    engineQuality  = 0.5,
    engineLoudness = 1.5,
    enginePower    = 0.66,
    mass           = 1.33,
}, 2)
