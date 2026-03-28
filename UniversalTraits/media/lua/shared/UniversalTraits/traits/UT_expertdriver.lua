-- UT_expertdriver.lua
-- Improves vehicle handling when driving

local TRAIT_ID = "UniversalTraits:UT_expertdriver"

local function onVehicleEnter(player, vehicle)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_vehicleHandlingBoost"] = true
end

local function onVehicleExit(player, vehicle)
    player:getModData()["UT_vehicleHandlingBoost"] = nil
end

Events.OnEnterVehicle.Add(onVehicleEnter)
Events.OnExitVehicle.Add(onVehicleExit)
