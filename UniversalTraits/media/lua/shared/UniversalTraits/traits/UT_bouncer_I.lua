-- UT_bouncer_I.lua
-- Bouncer (I & II): when surrounded by 3+ enemies within 1.75 tiles,
-- 5% chance per update tick to stagger one close enemy back.
-- Cooldown: 60 ticks between triggers (stored in moddata as UT_bouncer_cooldown).

local TRAIT_I  = "UniversalTraits:UT_bouncer_I"
local TRAIT_II = "UniversalTraits:UT_bouncer_II"

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not player then return end
    if not (UTCore.hasTrait(player, TRAIT_I) or UTCore.hasTrait(player, TRAIT_II)) then return end

    local md = player:getModData()
    if md["UT_bouncer_cooldown"] == nil then
        md["UT_bouncer_cooldown"] = 0
    end

    -- Decrement cooldown each tick (minimum 0)
    if md["UT_bouncer_cooldown"] > 0 then
        md["UT_bouncer_cooldown"] = md["UT_bouncer_cooldown"] - 1
        return
    end

    -- Cooldown is zero — check trigger conditions
    local spottedList = player:getSpottedList()
    if spottedList:size() < 3 then return end

    -- Collect enemies within 1.75 tiles
    local closeEnemies = {}
    for i = 0, spottedList:size() - 1 do
        local enemy = spottedList:get(i)
        if player:DistTo(enemy) < 1.75 then
            closeEnemies[#closeEnemies + 1] = enemy
        end
    end

    if #closeEnemies < 3 then return end

    -- 5% chance to stagger one close enemy
    if ZombRand(100) < 5 then
        local target = closeEnemies[1]
        target:setBumpType("stagger")
        target:setVariable("BumpDone", false)
        target:setVariable("BumpFall", true)
        md["UT_bouncer_cooldown"] = 60
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
