-- UT_indefatigable.lua
-- Stamina system: slows endurance drain while active, triggers recovery burst after exhaustion.

local TRAIT_ID = "UniversalTraits:UT_indefatigable"
local COOLDOWN_MINUTES = 3

local tickCounter = 0

local function onPlayerUpdate(player)
    if UTCore.shouldSkipTick(player) then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    tickCounter = tickCounter + 1
    if tickCounter % 30 ~= 0 then return end

    local stats = player:getStats()
    local moddata = player:getModData()

    if moddata["UT_indefRecovering"] then return end

    local endurance = stats:get(CharacterStat.ENDURANCE)
    if endurance < 0.05 then
        moddata["UT_indefCooldown"] = getGameTime():getWorldAgeHours()
        moddata["UT_indefRecovering"] = true
        return
    end

    if (player:isSprinting() or player:isRunning()) and endurance > 0.1 then
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

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.EveryOneMinute.Add(onEveryMinute)
