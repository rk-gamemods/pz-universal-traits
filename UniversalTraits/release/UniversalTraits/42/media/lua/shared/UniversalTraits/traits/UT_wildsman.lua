-- UT_wildsman.lua
-- Wildsman: +30% foraging yield multiplier (via modData flag) and 50% larger
-- fish (more hunger restored). Sets modData flags on new game for engine/UTCore
-- to consume, and hooks OnFishCaught for the fish size effect.

local TRAIT_ID = "UniversalTraits:UT_wildsman"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_wildsmanForageBoost"] = 1.3
    player:getModData()["UT_wildsmanFishSizeBoost"] = 1.5
end

local function onFishCaught(player, fish)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if fish then
        local hunger = fish:getHungerChange()
        if hunger then
            fish:setHungerChange(hunger * 1.5)
        end
    end
end

Events.OnNewGame.Add(onNewGame)

-- Hook fish-catch event; use pcall so missing events in other PZ versions don't error.
if Events.OnFishCaught then Events.OnFishCaught.Add(onFishCaught) end
