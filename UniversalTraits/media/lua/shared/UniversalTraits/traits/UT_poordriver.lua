-- UT_poordriver.lua
-- Worsens vehicle handling when driving

local TRAIT_ID = "UniversalTraits:UT_poordriver"

local function onVehicleEnter(player, vehicle)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_vehicleHandlingPenalty"] = true
end

local function onVehicleExit(player, vehicle)
    player:getModData()["UT_vehicleHandlingPenalty"] = nil
end

Events.OnEnterVehicle.Add(onVehicleEnter)
Events.OnExitVehicle.Add(onVehicleExit)
