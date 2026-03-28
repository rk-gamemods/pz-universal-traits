-- UT_leadfoot.lua
-- Grants 20% vehicle speed boost when driving

local TRAIT_ID = "UniversalTraits:UT_leadfoot"

local function onVehicleEnter(player, vehicle)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_vehicleSpeedBoost"] = 0.2
end

local function onVehicleExit(player, vehicle)
    player:getModData()["UT_vehicleSpeedBoost"] = nil
end

Events.OnEnterVehicle.Add(onVehicleEnter)
Events.OnExitVehicle.Add(onVehicleExit)
