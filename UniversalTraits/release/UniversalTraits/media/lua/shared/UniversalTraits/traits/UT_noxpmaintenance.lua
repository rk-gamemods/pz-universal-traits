-- UT_noxpmaintenance.lua
-- Disables XP gain for Maintenance skill

local TRAIT_ID = "UniversalTraits:UT_noxpmaintenance"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Maintenance")
end

Events.OnNewGame.Add(onNewGame)
