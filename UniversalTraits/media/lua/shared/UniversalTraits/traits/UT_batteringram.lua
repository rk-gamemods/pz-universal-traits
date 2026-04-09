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
-- CRITICAL ENGINE CONSTRAINT (verified from decompiled source):
--   OnPlayerUpdate fires BEFORE separate() collision detection in the same tick.
--   Clearing bumpType here is futile — separate() re-detects the overlap and
--   re-enters BumpedState on the same tick. The player must be physically moved
--   past the zombie so separate() finds no overlap. We push the player ~0.6
--   tiles along their sprint direction using setX/setY.

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN = 0.05  -- per collision (~20 before fully exhausted)
local NUDGE_DISTANCE  = 0.6   -- tiles to push player past zombie (~overlap threshold)

-- Only registered when the trait is active — no hasTrait guard needed inside.
local function onZombieCollision(player, zombie)
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not player:isSprinting() and not player:isRunning() then return false end

    -- Cancel the native stagger/trip state
    player:setBumpType("")
    player:setBumpFall(false)
    player:setBumpedChr(nil)
    pcall(function() player:setBlockMovement(false) end)

    -- Push the player past the zombie so separate() finds no overlap on this tick.
    -- Use vector from zombie→player (the direction the player is charging through).
    local px, py = player:getX(), player:getY()
    local zx, zy = zombie:getX(), zombie:getY()
    local dx = px - zx
    local dy = py - zy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0.001 then
        -- Normalize and push along charge direction
        dx = dx / dist
        dy = dy / dist
    else
        -- Player and zombie at exact same position: push along X axis as fallback
        dx = 1
        dy = 0
    end
    player:setX(px + dx * NUDGE_DISTANCE)
    player:setY(py + dy * NUDGE_DISTANCE)

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
