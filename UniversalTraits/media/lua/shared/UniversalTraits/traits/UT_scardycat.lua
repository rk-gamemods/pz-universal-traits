-- UT_scardycat.lua
-- Scaredy cat: screams (makes noise) when too many zombies are spotted.

local TRAIT_ID = "UniversalTraits:UT_scardycat"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_scardycat_cooldown"] == nil then
        md["UT_scardycat_cooldown"] = 0
    end

    if md["UT_scardycat_cooldown"] > 0 then
        md["UT_scardycat_cooldown"] = md["UT_scardycat_cooldown"] - 1
        return
    end

    -- Count spotted zombies
    local zombieCount = 0
    pcall(function()
        zombieCount = player:getSpottedList():size()
    end)
    if zombieCount <= 8 then return end

    -- 3% chance to scream
    if ZombRand(100) < 3 then
        local shouted = false
        pcall(function()
            player:ShouldBeShouting(true)
            shouted = true
        end)
        if not shouted then
            pcall(function() player:Say("!") end)
        end
        md["UT_scardycat_cooldown"] = 120
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
