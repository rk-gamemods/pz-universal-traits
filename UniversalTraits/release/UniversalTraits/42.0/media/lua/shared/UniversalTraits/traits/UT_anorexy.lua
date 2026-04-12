-- UT_anorexy.lua
-- Anorexy: raises stress when eating, detected via rising edge on healthFromFoodTimer.

local TRAIT_ID = "UniversalTraits:UT_anorexy"

local function onTick(player, tick)
    local md = tick.modData
    local healTimer = tick.bodyDamage:getHealthFromFoodTimer()
    local prev = md["UT_anorexy_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        pcall(function()
            local stats = tick.stats
            stats:add(CharacterStat.STRESS, 10)
        end)
    end

    md["UT_anorexy_prevTimer"] = healTimer
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
