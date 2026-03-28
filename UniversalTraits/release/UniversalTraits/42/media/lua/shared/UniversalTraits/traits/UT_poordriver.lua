-- UT_poordriver.lua
-- Worsens vehicle physics (braking, speed, engine, mass) while driving.
-- Mirrors MoreTraits vehicleCheck pattern: applied via OnPlayerUpdate when isDriving().

local TRAIT_ID = "UniversalTraits:UT_poordriver"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if not player:isDriving() then return end

    local vehicle = player:getVehicle()
    if not vehicle then return end

    local vmd = vehicle:getModData()

    -- Store baseline on first encounter
    if vmd.UT_baseMaxSpeed == nil then
        vmd.UT_baseMaxSpeed      = vehicle:getMaxSpeed()
        vmd.UT_baseBrakingForce  = vehicle:getBrakingForce()
        vmd.UT_baseEnginePower   = vehicle:getEnginePower()
        vmd.UT_baseMass          = vehicle:getMass()
        vmd.UT_baseInitialMass   = vehicle:getInitialMass()
        vmd.UT_poorState         = "Normal"
    end

    if vmd.UT_poorState ~= "PoorDriver" then
        vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed * 0.75)
        vehicle:setBrakingForce(vmd.UT_baseBrakingForce * 0.5)
        vehicle:setEngineFeature(
            vehicle:getEngineQuality() * 0.5,
            vehicle:getEngineLoudness() * 1.5,
            vmd.UT_baseEnginePower * 0.66
        )
        vehicle:setMass(vmd.UT_baseMass * 1.33)
        vehicle:setInitialMass(vmd.UT_baseInitialMass * 1.33)
        vehicle:updateTotalMass()
        vmd.UT_poorState = "PoorDriver"
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
