-- UT_indefatigable.lua
-- Stamina system: slows endurance drain while active, triggers recovery burst after exhaustion.

local TRAIT_ID = "UniversalTraits:UT_indefatigable"
local COOLDOWN_MINUTES = 3

local function onTick(player, tick)

    local stats = tick.stats
    local moddata = tick.modData

    if moddata["UT_indefRecovering"] then return end

    local endurance = stats:get(CharacterStat.ENDURANCE)
    if endurance < 0.05 then
        moddata["UT_indefCooldown"] = getGameTime():getWorldAgeHours()
        moddata["UT_indefRecovering"] = true
        return
    end

    if (tick.isSprinting or tick.isRunning) and endurance > 0.1 then
        stats:set(CharacterStat.ENDURANCE, math.min(CharacterStat.ENDURANCE:getMaximumValue(), endurance + 0.005))
    end
end

local function onEveryMinute()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local moddata = player:getModData()
    if not moddata["UT_indefRecovering"] then return end

    local cooldownStart = moddata["UT_indefCooldown"]
    if not cooldownStart then
        moddata["UT_indefRecovering"] = nil
        return
    end

    local elapsed = getGameTime():getWorldAgeHours() - cooldownStart
    if elapsed >= (COOLDOWN_MINUTES / 60.0) then
        player:getStats():set(CharacterStat.ENDURANCE, 0.5)
        moddata["UT_indefRecovering"] = nil
        moddata["UT_indefCooldown"] = nil
    end
end

UTCore.registerTickHandler(TRAIT_ID, onTick, { throttle = 30 })
Events.EveryOneMinute.Add(onEveryMinute)
