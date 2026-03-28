-- UT_noxpshooter.lua
-- Disables XP gain for Aiming and Reloading

local TRAIT_ID = "UniversalTraits:UT_noxpshooter"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Aiming")
    UTCore.disableXP(player, "Reloading")
end

Events.OnNewGame.Add(onNewGame)
