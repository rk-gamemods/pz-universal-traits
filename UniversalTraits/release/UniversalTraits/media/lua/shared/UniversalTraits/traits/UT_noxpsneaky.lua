-- UT_noxpsneaky.lua
-- Disables XP gain for Sneaking and Lightfoot skills

local TRAIT_ID = "UniversalTraits:UT_noxpsneaky"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Sneaking")
    UTCore.disableXP(player, "Lightfoot")
end

Events.OnNewGame.Add(onNewGame)
