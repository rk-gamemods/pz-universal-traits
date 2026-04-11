-- UT_competitiveeater.lua
-- Competitive eater: reduces boredom and hunger slightly on eating.
-- Detected via rising edge on healthFromFoodTimer (same pattern as sensitivestomach).

local TRAIT_ID = "UniversalTraits:UT_competitiveeater"

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local healTimer = player:getBodyDamage():getHealthFromFoodTimer()
    local prev = md["UT_competitiveeater_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        pcall(function()
            local stats = player:getStats()
            stats:add(CharacterStat.BOREDOM, -10)
            stats:add(CharacterStat.HUNGER, -5)
        end)
    end

    md["UT_competitiveeater_prevTimer"] = healTimer
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
