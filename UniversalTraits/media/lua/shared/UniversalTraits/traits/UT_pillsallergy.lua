-- UT_pillsallergy.lua
-- Pills allergy: medicine reaction marker

local TRAIT_ID = "UniversalTraits:UT_pillsallergy"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_pillsAllergyFlag"] = true
end

Events.OnNewGame.Add(onNewGame)
