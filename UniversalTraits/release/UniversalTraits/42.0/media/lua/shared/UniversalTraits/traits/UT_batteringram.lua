-- UT_batteringram.lua
-- +50% push force via moddata flag

local TRAIT_ID = "UniversalTraits:UT_batteringram"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_pushForce"] = 1.5
end

Events.OnNewGame.Add(onNewGame)
