-- UT_noxpaxe.lua
-- Disables XP gain for Axe skill

local TRAIT_ID = "UniversalTraits:UT_noxpaxe"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Axe")
end

Events.OnNewGame.Add(onNewGame)
