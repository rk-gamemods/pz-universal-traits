-- UT_batteringram.lua
-- Intercepts zombie collisions while sprinting or running, knocking the zombie
-- down and draining endurance.
--
-- v4 ZombieCollisionHook does NOT manipulate any player bump/animation state.
-- It only detects nearby zombies and fires this callback, which operates
-- exclusively on ZOMBIES (knockDown, setHealth) and PLAYER STATS (endurance).
-- If the engine's normal bump fires anyway, the BumpedState lifecycle handles
-- recovery — that's designed game mechanics, not something we prevent.
--
-- The callback fires when a zombie enters collision range (proximity-based),
-- NOT on bump rising edge. This means the trait effect (knockdown, damage)
-- applies proactively, before the engine even attempts a bump check.
--
-- Synergy: if the player also has UT_martial, delegates to UT_martial.applyBonusDamage
-- so the damage formula stays in one place.

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN_RUN    = 0.05   -- per collision while running (~20 before exhausted)
local ENDURANCE_DRAIN_SPRINT = 0.03   -- per collision while sprinting (~33 before exhausted)
local SPRINT_DAMAGE          = 0.15   -- direct health damage to zombie on sprint charge

-- Called when a zombie enters collision range while player is running/sprinting.
-- The hook already filters for movement state; double-check as safety.
local function onZombieCollision(player, zombie)
    local sprinting = player:isSprinting()
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not sprinting and not player:isRunning() then return false end

    -- Knock the zombie down. hitFromBehind=true selects the faster
    -- "slammed forward" animation — visually matches a charging impact.
    zombie:knockDown(true)

    -- Sprint bonus: direct impact damage from the charge
    if sprinting then
        pcall(function() zombie:setHealth(zombie:getHealth() - SPRINT_DAMAGE) end)
    end

    -- Drain endurance per collision — sprinting is more efficient (momentum)
    local stats = player:getStats()
    if not stats then return true end
    local drain = sprinting and ENDURANCE_DRAIN_SPRINT or ENDURANCE_DRAIN_RUN
    local endurance = stats:get(CharacterStat.ENDURANCE)
    endurance = math.max(0, endurance - drain)
    stats:set(CharacterStat.ENDURANCE, endurance)

    -- Martial arts synergy: delegate entirely to UT_martial so the formula stays in one place
    if UTCore.hasTrait(player, MARTIAL_TRAIT) then
        UT_martial.applyBonusDamage(player, zombie, endurance)
    end

    return true  -- signal: collision was handled
end

-- Declare collision handler — UTCore handles OnCreatePlayer registration,
-- save/load persistence, and integrity self-healing automatically.
UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)
