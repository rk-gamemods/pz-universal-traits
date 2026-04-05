-- UT_immunocompromised.lua
-- Immunocompromised: infection susceptibility

local TRAIT_ID = "UniversalTraits:UT_immunocompromised"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_immunocompromised"] = true
end

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        local infectionLevel = bodyDamage:getApparentInfectionLevel()
        if infectionLevel and infectionLevel > 0 then
            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, math.min(100, infectionLevel + 1))

        end
    end
end

Events.OnNewGame.Add(onNewGame)
Events.EveryOneMinute.Add(onEveryOneMinute)
