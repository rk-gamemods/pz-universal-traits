-- UT_batteringram.lua
-- Intercepts actual zombie collisions (player physically bumps a zombie) while
-- sprinting or running, replacing the native stagger/trip with a knockdown.
-- Player is immune to the stagger and trip effects during these collisions.
-- Each collision drains a small amount of endurance (~20 before exhausted).
-- Synergy: if the player also has UT_martial, delegates to UT_martial.applyBonusDamage
-- so the damage formula stays in one place.
--
-- Uses UTCore_ZombieCollisionHook, which detects the real collision event from
-- the engine (player:isBumped() rising edge + player:getBumpedChr() == zombie).
--
-- HOW THE FIX WORKS (verified from decompiled IsoMovingObject.separate()):
--   The engine's separate() collision detection has a built-in re-bump guard:
--     if player:getBumpedChr() != obj then bump = true
--   As long as bumpedChr still points at the zombie, the SAME zombie cannot
--   re-trigger a bump. By clearing bumpType/bumpFall/blockMovement but
--   PRESERVING bumpedChr, the player can move freely while the engine's own
--   guard prevents the infinite re-bump loop. No teleportation needed.
--   For zombie clusters (different zombies), the 8-tick suppression in
--   UTCore_ZombieCollisionHook handles clearing re-bumps from other zombies.

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN_RUN    = 0.05   -- per collision while running (~20 before exhausted)
local ENDURANCE_DRAIN_SPRINT = 0.03   -- per collision while sprinting (~33 before exhausted)
local SPRINT_DAMAGE          = 0.15   -- direct health damage to zombie on sprint charge

-- Only registered when the trait is active — no hasTrait guard needed inside.
local function onZombieCollision(player, zombie)
    local sprinting = player:isSprinting()
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not sprinting and not player:isRunning() then return false end

    -- Cancel the native stagger/trip flags so BumpedState.execute() unblocks movement.
    -- CRITICAL: Do NOT clear bumpedChr — the engine uses it as a re-bump guard
    -- (IsoMovingObject.separate() line 1222: getBumpedChr() != obj).
    -- Clearing it would let separate() re-bump us with the same zombie every tick.
    player:setBumpType("")
    player:setBumpFall(false)
    pcall(function() player:setBlockMovement(false) end)

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

    return true  -- signal: handled, activate bump suppression as safety net
end

-- Declare collision handler — UTCore handles OnCreatePlayer registration,
-- save/load persistence, and integrity self-healing automatically.
UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)
