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
-- Returning true tells the hook to suppress re-bump for several ticks,
-- preventing the freeze caused by the engine re-entering BumpedState every tick
-- while the player still physically overlaps the zombie.

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN = 0.05  -- per collision (~20 before fully exhausted)

-- Only registered when the trait is active — no hasTrait guard needed inside.
local function onZombieCollision(player, zombie)
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not player:isSprinting() and not player:isRunning() then return false end

    -- Cancel the native stagger/trip: clear ALL bump state so BumpedState
    -- releases the movement lock. The hook's suppression system will keep
    -- clearing re-bumps for several ticks while the player moves through.
    player:setBumpType("")
    player:setBumpFall(false)
    player:setBumpedChr(nil)
    -- Explicitly unblock movement — BumpedState.enter() already called
    -- setBlockMovement(true) before our callback fired. pcall-guarded
    -- because setBlockMovement may not be Lua-exposed in all PZ builds.
    pcall(function() player:setBlockMovement(false) end)

    -- Knock the zombie down. hitFromBehind=true selects the faster
    -- "slammed forward" animation — visually matches a charging impact
    -- regardless of the zombie's facing direction.
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

    return true  -- signal: handled, activate bump suppression
end

-- Declare collision handler — UTCore handles OnCreatePlayer registration,
-- save/load persistence, and integrity self-healing automatically.
UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)
