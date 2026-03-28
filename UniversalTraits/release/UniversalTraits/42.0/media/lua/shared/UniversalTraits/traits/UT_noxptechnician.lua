-- UT_noxptechnician.lua
-- Disables XP gain for Electricity and Mechanics

local TRAIT_ID = "UniversalTraits:UT_noxptechnician"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Electricity")
    UTCore.disableXP(player, "Mechanics")
end

Events.OnNewGame.Add(onNewGame)
