-- UT_superimmune.lua
-- Super immune: infection resistance

local TRAIT_ID = "UniversalTraits:UT_superimmune"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_superimmune"] = true
end

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local bodyDamage = player:getBodyDamage()
    if bodyDamage then
        local infectionLevel = bodyDamage:getApparentInfectionLevel()
        if infectionLevel and infectionLevel > 0 then
            player:getStats():set(CharacterStat.ZOMBIE_INFECTION, math.max(0, infectionLevel - 2))

        end
    end
end

Events.OnNewGame.Add(onNewGame)
Events.EveryOneMinute.Add(onEveryOneMinute)
