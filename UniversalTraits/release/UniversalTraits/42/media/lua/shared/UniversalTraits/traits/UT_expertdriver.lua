-- UT_expertdriver.lua
-- Improves vehicle physics (braking, speed, engine, mass) while driving.
-- Mirrors MoreTraits vehicleCheck pattern: applied via OnPlayerUpdate when isDriving().

local TRAIT_ID = "UniversalTraits:UT_expertdriver"

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
        vmd.UT_expertState       = "Normal"
    end

    if vmd.UT_expertState ~= "ExpertDriver" then
        vehicle:setMaxSpeed(vmd.UT_baseMaxSpeed * 1.25)
        vehicle:setBrakingForce(vmd.UT_baseBrakingForce * 2)
        vehicle:setEngineFeature(
            vehicle:getEngineQuality() * 2,
            vehicle:getEngineLoudness() * 0.25,
            vmd.UT_baseEnginePower * 3
        )
        vehicle:setMass(vmd.UT_baseMass * 0.5)
        vehicle:setInitialMass(vmd.UT_baseInitialMass * 0.5)
        vehicle:updateTotalMass()
        vmd.UT_expertState = "ExpertDriver"
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
