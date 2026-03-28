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
        local infectionLevel = bodyDamage:getInfectionLevel()
        if infectionLevel and infectionLevel > 0 then
            bodyDamage:setInfectionLevel(math.min(1, infectionLevel + 0.01))
        end
    end
end

Events.OnNewGame.Add(onNewGame)
Events.EveryOneMinute.Add(onEveryOneMinute)
