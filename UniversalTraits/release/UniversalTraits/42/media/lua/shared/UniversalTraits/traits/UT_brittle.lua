-- UT_brittle.lua
-- 50% increased fracture chance

local TRAIT_ID = "UniversalTraits:UT_brittle"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_fractureMult"] = 1.5
end

Events.OnNewGame.Add(onNewGame)
