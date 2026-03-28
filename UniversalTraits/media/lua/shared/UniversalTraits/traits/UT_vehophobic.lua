-- UT_vehophobic.lua
-- Vehicle phobic: panic and stress on vehicle enter

local TRAIT_ID = "UniversalTraits:UT_vehophobic"

local function onVehicleEnter(player, vehicle)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    stats:setPanic(math.min(1, stats:getPanic() + 0.3))
    stats:setStress(math.min(1, stats:getStress() + 0.2))
end

Events.OnEnterVehicle.Add(onVehicleEnter)
