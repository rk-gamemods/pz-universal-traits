-- UT_noxpfirstaid.lua
-- Disables XP gain for Doctor skill

local TRAIT_ID = "UniversalTraits:UT_noxpfirstaid"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Doctor")
end

Events.OnNewGame.Add(onNewGame)
