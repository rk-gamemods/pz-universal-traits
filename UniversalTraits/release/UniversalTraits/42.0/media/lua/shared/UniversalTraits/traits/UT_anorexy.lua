-- UT_anorexy.lua
-- Anorexy: raises stress when eating, detected via rising edge on healthFromFoodTimer.

local TRAIT_ID = "UniversalTraits:UT_anorexy"

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local healTimer = player:getBodyDamage():getHealthFromFoodTimer()
    local prev = md["UT_anorexy_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        pcall(function()
            local stats = player:getStats()
            stats:add(CharacterStat.STRESS, 10)
        end)
    end

    md["UT_anorexy_prevTimer"] = healTimer
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
