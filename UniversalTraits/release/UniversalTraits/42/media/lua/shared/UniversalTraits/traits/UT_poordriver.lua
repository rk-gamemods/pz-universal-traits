-- UT_poordriver.lua
local TRAIT_ID = "UniversalTraits:UT_poordriver"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyVehicleMod(player, "UT_poorState", {
        maxSpeed       = 0.75,
        brakingForce   = 0.5,
        engineQuality  = 0.5,
        engineLoudness = 1.5,
        enginePower    = 0.66,
        mass           = 1.33,
    })
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
