-- UT_snorer.lua
-- Double noise output while sleeping

local TRAIT_ID = "UniversalTraits:UT_snorer"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.applyNoiseMod(player, 2.0)
end

Events.OnNewGame.Add(onNewGame)
