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

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN = 0.05  -- per collision (~20 before fully exhausted)

-- Only registered when the trait is active — no hasTrait guard needed inside.
local function onZombieCollision(player, zombie)
    -- Only trigger while actively sprinting or running (walking into a zombie does nothing)
    if not player:isSprinting() and not player:isRunning() then return end

    -- Cancel the native stagger/trip: clear the bump state so BumpedState
    -- does not block movement and the fall animation does not play
    player:setBumpType("")
    player:setBumpFall(false)

    -- Knock the zombie down (player is charging from the front)
    zombie:knockDown(false)

    -- Drain endurance per collision
    local stats = player:getStats()
    if not stats then return end
    local endurance = stats:get(CharacterStat.ENDURANCE)
    endurance = math.max(0, endurance - ENDURANCE_DRAIN)
    stats:set(CharacterStat.ENDURANCE, endurance)

    -- Martial arts synergy: delegate entirely to UT_martial so the formula stays in one place
    if UTCore.hasTrait(player, MARTIAL_TRAIT) then
        UT_martial.applyBonusDamage(player, zombie, endurance)
    end
end

-- Declare collision handler — UTCore handles OnCreatePlayer registration,
-- save/load persistence, and integrity self-healing automatically.
UTCore.declareZombieCollisionHandler(TRAIT_ID, onZombieCollision)
