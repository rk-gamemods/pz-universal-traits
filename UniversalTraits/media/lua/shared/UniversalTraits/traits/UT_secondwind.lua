-- UT_secondwind.lua
-- Stamina recovery trigger: burst of endurance when exhausted while sprinting (10-minute cooldown).

local TRAIT_ID = "UniversalTraits:UT_secondwind"
local COOLDOWN_HOURS = 10 / 60.0

local tickCounter = 0

local function onTick(player, tick)
    tickCounter = tickCounter + 1
    if tickCounter % 15 ~= 0 then return end

    local stats = tick.stats
    local moddata = tick.modData

    if moddata["UT_secondwindTriggered"] then return end

    if tick.isSprinting and stats:get(CharacterStat.ENDURANCE) <= 0.1 then
        stats:set(CharacterStat.ENDURANCE, math.min(CharacterStat.ENDURANCE:getMaximumValue(), stats:get(CharacterStat.ENDURANCE) + 0.3))
        moddata["UT_secondwindCooldown"] = getGameTime():getWorldAgeHours()
        moddata["UT_secondwindTriggered"] = true
    end
end

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local moddata = player:getModData()
    if not moddata["UT_secondwindTriggered"] then return end

    local cooldownStart = moddata["UT_secondwindCooldown"]
    if not cooldownStart then
        moddata["UT_secondwindTriggered"] = nil
        return
    end

    if getGameTime():getWorldAgeHours() - cooldownStart >= COOLDOWN_HOURS then
        moddata["UT_secondwindTriggered"] = nil
        moddata["UT_secondwindCooldown"] = nil
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick)
Events.EveryOneMinute.Add(onEveryMinute)
