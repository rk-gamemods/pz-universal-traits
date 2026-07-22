-- UTCore_DamageMultHook.lua
-- Reads UT_damageMult from player moddata.
--
-- Track resolved overall body-health changes in the existing central update
-- dispatch. This covers every damage source without trusting events that fire
-- before damage resolution, including OnWeaponHitCharacter/WEAPONHIT.

UTCore = UTCore or {}

local function resetTracking()
    UTCore._damageMultTrackedPlayer = nil
    UTCore._damageMultLastHealth = nil
end

local function onPlayerUpdate(player, tick)
    if not player then
        resetTracking()
        return
    end

    local modData = tick and tick.modData or player:getModData()
    local mult = modData and modData["UT_damageMult"]
    if type(mult) ~= "number" or mult ~= mult or mult == math.huge or mult <= 1.0 then
        resetTracking()
        return
    end

    local bodyDamage = tick and tick.bodyDamage or player:getBodyDamage()
    if not bodyDamage then
        resetTracking()
        return
    end

    local health = bodyDamage:getOverallBodyHealth()
    if type(health) ~= "number" or health ~= health then
        resetTracking()
        return
    end

    if UTCore._damageMultTrackedPlayer ~= player or UTCore._damageMultLastHealth == nil then
        UTCore._damageMultTrackedPlayer = player
        UTCore._damageMultLastHealth = health
        return
    end

    local lastHealth = UTCore._damageMultLastHealth
    if health >= lastHealth or health <= 0 then
        UTCore._damageMultLastHealth = health
        return
    end

    local extra = (lastHealth - health) * (mult - 1.0)
    extra = math.min(extra, health)
    if extra > 0 then
        bodyDamage:ReduceGeneralHealth(extra)
    end

    -- ReduceGeneralHealth changes body parts immediately, but SVN 964 updates
    -- overallBodyHealth later in BodyDamage.calculateOverallHealth(). Store the
    -- expected resolved value so our own extra loss is not multiplied again.
    UTCore._damageMultLastHealth = math.max(0, health - extra)
end

-- Remove the obsolete pre-resolution listener when this file is reloaded over
-- a previous version in the same process.
if Events and Events.OnWeaponHitCharacter then
    if UTCore._damageMultWeaponHitHandler then
        Events.OnWeaponHitCharacter.Remove(UTCore._damageMultWeaponHitHandler)
    end
    UTCore._damageMultWeaponHitHandler = nil
end

resetTracking()
UTCore._damageMultUpdateHandler = onPlayerUpdate

if Events and Events.OnPlayerUpdate and UTCore._damageMultDirectHandler then
    Events.OnPlayerUpdate.Remove(UTCore._damageMultDirectHandler)
    UTCore._damageMultDirectHandler = nil
end

if UTCore.registerCoreHandler then
    if not UTCore._damageMultTickDispatcher then
        UTCore._damageMultTickDispatcher = function(player, tick)
            local handler = UTCore._damageMultUpdateHandler
            if handler then handler(player, tick) end
        end
        UTCore.registerCoreHandler("DamageMultHook", UTCore._damageMultTickDispatcher, { priority = 0 })
    end
elseif Events and Events.OnPlayerUpdate then
    UTCore._damageMultDirectHandler = onPlayerUpdate
    Events.OnPlayerUpdate.Add(UTCore._damageMultDirectHandler)
end
