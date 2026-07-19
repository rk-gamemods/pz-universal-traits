-- UTCore_DamageMultHook.lua
-- Reads UT_damageMult from player moddata.
--
-- OnWeaponHitCharacter is raised before the engine applies the weapon hit.
-- Apply only the extra portion here; the engine applies the original hit after
-- the event returns.  Using the event's damage avoids folding unrelated health
-- loss since an earlier update into this hit.

UTCore = UTCore or {}

local function onWeaponHitCharacter(attacker, target, weapon, damage)
    local player = getPlayer()
    if not player or target ~= player or player:isDead() then return end

    local mult = player:getModData()["UT_damageMult"]
    if type(mult) ~= "number" or mult <= 1.0 then return end
    if type(damage) ~= "number" or damage ~= damage or damage <= 0 then return end

    local health = player:getHealth()
    if type(health) ~= "number" or health ~= health or health <= 0 then return end

    -- The event damage is the only loss attributable to this callback. Cap its
    -- contribution to the health that exists before the engine applies the hit.
    local attributableDamage = math.min(damage, health)
    local extra = attributableDamage * (mult - 1.0)
    player:setHealth(math.max(0, health - extra))
end

if Events and Events.OnWeaponHitCharacter then
    if UTCore._damageMultWeaponHitHandler then
        Events.OnWeaponHitCharacter.Remove(UTCore._damageMultWeaponHitHandler)
    end

    UTCore._damageMultWeaponHitHandler = onWeaponHitCharacter
    Events.OnWeaponHitCharacter.Add(UTCore._damageMultWeaponHitHandler)
end
