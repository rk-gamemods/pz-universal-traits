-- UT_driver.lua
-- Source: MoreTraits vehicleCheck() — mild vehicle improvement, weaker tier than expertdriver.
-- OnPlayerUpdate: top speed +20%, engine power +20%, braking +20%, engine 20% quieter.

local TRAIT_ID = "UniversalTraits:UT_driver"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyVehicleMod(player, "UT_driverState", {
        maxSpeed       = 1.2,
        enginePower    = 1.2,
        brakingForce   = 1.2,
        engineLoudness = 0.8,
    })
end

UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)
