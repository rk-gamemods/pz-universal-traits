-- UT_competitiveeater.lua
-- Competitive eater: reduces boredom and hunger slightly on eating.
-- Detected via rising edge on healthFromFoodTimer (same pattern as sensitivestomach).

local TRAIT_ID = "UniversalTraits:UT_competitiveeater"

local function onTick(player, tick)
    local md = tick.modData
    local healTimer = tick.bodyDamage:getHealthFromFoodTimer()
    local prev = md["UT_competitiveeater_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        pcall(function()
            local stats = tick.stats
            stats:add(CharacterStat.BOREDOM, -10)
            stats:add(CharacterStat.HUNGER, -5)
        end)
    end

    md["UT_competitiveeater_prevTimer"] = healTimer
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
