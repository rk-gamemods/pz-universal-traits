-- UT_immunocompromised.lua
-- Immunocompromised: infection susceptibility

local TRAIT_ID = "UniversalTraits:UT_immunocompromised"

UTImmunocompromisedRuntime = UTImmunocompromisedRuntime or {}

if UTImmunocompromisedRuntime.onEveryOneMinute then
    Events.EveryOneMinute.Remove(UTImmunocompromisedRuntime.onEveryOneMinute)
end

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    player:getModData()["UT_immunocompromised"] = true
end

local function onEveryOneMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player:getStats()
    local infectionLevel = stats:get(CharacterStat.ZOMBIE_INFECTION)
    if infectionLevel and infectionLevel > 0 then
        stats:set(CharacterStat.ZOMBIE_INFECTION, math.min(100, infectionLevel + 1))
    end
end

Events.OnNewGame.Add(onNewGame)
Events.EveryOneMinute.Add(onEveryOneMinute)
UTImmunocompromisedRuntime.onEveryOneMinute = onEveryOneMinute
