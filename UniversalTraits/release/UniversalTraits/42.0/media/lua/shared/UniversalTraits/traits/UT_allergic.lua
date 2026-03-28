-- UT_allergic.lua
-- Allergic: general allergy marker

local TRAIT_ID = "UniversalTraits:UT_allergic"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_generalAllergyFlag"] = true
end

Events.OnNewGame.Add(onNewGame)
