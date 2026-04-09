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
local ENDURANCE_DRAIN = 0.05  -- per collision (~20 before fully exhausted)

-- Only registered when the trait is active — no hasTrait guard needed inside.
local function onZombieCollision(player, zombie)
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not player:isSprinting() and not player:isRunning() then return false end

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

    -- Drain endurance per collision
    local stats = player:getStats()
    if not stats then return true end
    local endurance = stats:get(CharacterStat.ENDURANCE)
    endurance = math.max(0, endurance - ENDURANCE_DRAIN)
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
