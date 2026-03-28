-- UT_wildplantsallergy.lua
-- Wild plants allergy: wild food reaction marker

local TRAIT_ID = "UniversalTraits:UT_wildplantsallergy"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_wildplantAllergyFlag"] = true
end

Events.OnNewGame.Add(onNewGame)
