-- UTCore_DamageMultHook.lua
-- Reads UT_damageMult from player moddata.
-- When the local player takes weapon damage, applies the multiplier to
-- the health deficit: extra = lost_health * (mult - 1.0).
--
-- Mechanism: OnPlayerUpdate tracks prev_health every tick.
-- OnWeaponHitCharacter fires when a weapon (from any attacker including zombies)
-- hits a character. When target == local player, the health deficit since the
-- last tick is multiplied and applied as an additional reduction.
--
-- mult = 1.5 (glassbody): player loses 50% more health per hit than normal.
-- mult = 1.0: no effect (hook exits early).
--
-- Safety: health is clamped to 0 — does not go below 0.
-- Self-damage (from falls, bleeding) also triggers this hook. Falls give exactly
-- the intended "glass body" experience; bleeding already has its own drain hook.

UTCore = UTCore or {}

local function onPlayerUpdate(player, tick)
    if player:isDead() then return end
    local md = tick and tick.modData or player:getModData()
    -- Skip health tracking when damage mult is not active (no glassbody trait)
    if not md["UT_damageMult"] then return end
    -- Track health each tick for the hit-detection diff in onWeaponHitCharacter
    md["UT_dmgPrevHealth"] = player:getHealth()
end

local function onWeaponHitCharacter(attacker, weapon, target)
    local player = getPlayer()
    if not player or target ~= player then return end

    local md = player:getModData()
    local mult = md["UT_damageMult"]
    if not mult or mult <= 1.0 then return end

    local prevHealth = md["UT_dmgPrevHealth"]
    if prevHealth == nil then return end

    local curHealth = player:getHealth()
    if curHealth >= prevHealth then return end  -- no loss this frame

    local lost  = prevHealth - curHealth
    local extra = lost * (mult - 1.0)
    player:setHealth(math.max(0, curHealth - extra))
    -- Update stored health so the next hit starts from the new value
    md["UT_dmgPrevHealth"] = player:getHealth()
end

if UTCore.registerCoreHandler then
    UTCore.registerCoreHandler("DamageMultHook", onPlayerUpdate, { priority = 0 })
else
    if Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
end
