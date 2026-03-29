-- UT_ascetic.lua
-- Ascetic: penalizes mood when eating within 5 in-game minutes of the last meal.
-- Detected via rising edge on healthFromFoodTimer (same pattern as sensitivestomach).

local TRAIT_ID = "UniversalTraits:UT_ascetic"

local function onPlayerUpdate(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local md = player:getModData()
    local healTimer = player:getBodyDamage():getHealthFromFoodTimer()
    local prev = md["UT_ascetic_prevTimer"]

    -- Detect moment food was eaten: timer jumps up from a low/nil value
    if prev ~= nil and healTimer > prev + 50 then
        local lastAteHours = md["UT_ascetic_lastAte"]
        local currentHours = getGameTime():getWorldAgeHours()

        if lastAteHours and (currentHours - lastAteHours) < (5 / 60) then
            -- Ate within 5 in-game minutes of last meal — penalize unhappiness
            pcall(function()
                local stats = player:getStats()
                stats:add(CharacterStat.UNHAPPINESS, 10)
                stats:add(CharacterStat.STRESS, 5)
            end)
        end

        md["UT_ascetic_lastAte"] = currentHours
    end

    md["UT_ascetic_prevTimer"] = healTimer
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
