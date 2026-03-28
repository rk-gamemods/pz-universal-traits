-- UT_incomprehensive.lua
-- Reduces effective skill cap by 2

local TRAIT_ID = "UniversalTraits:UT_incomprehensive"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_skillCapReduction"] = 2
end

Events.OnNewGame.Add(onNewGame)
