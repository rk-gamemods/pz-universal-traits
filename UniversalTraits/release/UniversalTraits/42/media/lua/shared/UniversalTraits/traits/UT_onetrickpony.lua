-- UT_onetrickpony.lua
-- Flag for XP system: penalty when training multiple skills

local TRAIT_ID = "UniversalTraits:UT_onetrickpony"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_multiSkillPenalty"] = true
end

Events.OnNewGame.Add(onNewGame)
