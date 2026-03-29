-- UT_deprived.lua
-- Source: MoreTraits initToadTraitsItems() — player spawns naked with no items.
-- OnNewGame: UTCore.stripSpawnItems clears clothing, inventory, adds key ring.

local TRAIT_ID = "UniversalTraits:UT_deprived"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.stripSpawnItems(player)
end

Events.OnNewGame.Add(onNewGame)
