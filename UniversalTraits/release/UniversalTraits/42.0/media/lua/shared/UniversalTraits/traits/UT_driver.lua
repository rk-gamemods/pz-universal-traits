-- UT_driver.lua
-- Source: MoreTraits vehicleCheck() — mild vehicle improvement, weaker tier than expertdriver.
-- OnPlayerUpdate: top speed +20%, engine power +20%, braking +20%, engine 20% quieter.

local TRAIT_ID = "UniversalTraits:UT_driver"

UTCore.registerVehicleTrait(TRAIT_ID, "UT_driverState", {
    maxSpeed       = 1.2,
    enginePower    = 1.2,
    brakingForce   = 1.2,
    engineLoudness = 0.8,
}, 1)
