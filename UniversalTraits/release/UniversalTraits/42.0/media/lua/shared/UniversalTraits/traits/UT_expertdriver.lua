-- UT_expertdriver.lua
local TRAIT_ID = "UniversalTraits:UT_expertdriver"

UTCore.registerVehicleTrait(TRAIT_ID, "UT_expertState", {
    maxSpeed       = 1.25,
    brakingForce   = 2.0,
    engineQuality  = 2.0,
    engineLoudness = 0.25,
    enginePower    = 3.0,
    mass           = 0.5,
}, 2)
