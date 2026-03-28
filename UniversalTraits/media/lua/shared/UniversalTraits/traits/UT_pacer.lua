-- UT_pacer.lua
-- +15% movement speed modifier
-- Runtime: restlessness indoors — gains unhappiness after extended time inside.

local TRAIT_ID = "UniversalTraits:UT_pacer"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_speedMod"] = 0.15
end

Events.OnNewGame.Add(onNewGame)

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    if md["UT_pacer_indoor_ticks"] == nil then
        md["UT_pacer_indoor_ticks"] = 0
    end

    -- Check if indoors
    local indoors = false
    local ok, result = pcall(function() return player:isIndoors() end)
    if ok then indoors = result end

    if not indoors then
        md["UT_pacer_indoor_ticks"] = 0
        return
    end

    -- Increment indoor counter
    md["UT_pacer_indoor_ticks"] = md["UT_pacer_indoor_ticks"] + 1

    -- After 600 ticks indoors, apply unhappiness penalty
    if md["UT_pacer_indoor_ticks"] >= 600 then
        pcall(function()
            local bd = player:getBodyDamage()
            bd:setUnhappinessLevel(math.min(100, bd:getUnhappinessLevel() + 2))
        end)
        md["UT_pacer_indoor_ticks"] = 0
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
