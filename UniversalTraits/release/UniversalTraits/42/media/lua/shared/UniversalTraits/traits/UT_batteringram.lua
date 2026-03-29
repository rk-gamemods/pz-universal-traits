-- UT_batteringram.lua
-- Intercepts actual zombie collisions (player physically bumps a zombie) while
-- sprinting or running, replacing the native stagger/trip with a knockdown.
-- Player is immune to the stagger and trip effects during these collisions.
-- Each collision drains a small amount of endurance (~20 before exhausted).
-- Synergy: if the player also has UT_martial, each collision applies martial arts
-- damage to the zombie in addition to the knockdown.
--
-- Uses UTCore_ZombieCollisionHook, which detects the real collision event from
-- the engine (player:isBumped() rising edge + player:getBumpedChr() == zombie).

local TRAIT_ID        = "UniversalTraits:UT_batteringram"
local MARTIAL_TRAIT   = "UniversalTraits:UT_martial"
local ENDURANCE_DRAIN = 0.05  -- per collision (~20 before fully exhausted)

-- Reuses the same crit/damage formula as UT_martial, accepting the already-drained
-- endurance value so the scaling reflects the current state.
local function getMartialBonusDamage(player, endurance)
    local smallBluntLevel = 0
    local ok, level = pcall(function()
        if Perks and Perks.SmallBlunt then
            return player:getPerkLevel(Perks.SmallBlunt)
        end
        return 0
    end)
    if ok and type(level) == "number" then
        smallBluntLevel = level
    end

    local critChance = (5 + smallBluntLevel * 5) * 0.01
    local damage
    if ZombRand(100) < (critChance * 100) then
        damage = 0.6  -- critical
    else
        damage = 0.2  -- normal
    end
    -- Scale 0.35x at 0 endurance → 1.35x at full endurance
    return damage * (endurance + 0.35)
end

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
    local endurance = stats:getEndurance()
    endurance = math.max(0, endurance - ENDURANCE_DRAIN)
    stats:setEndurance(endurance)

    -- Martial arts synergy: deal damage on top of the knockdown
    if UTCore.hasTrait(player, MARTIAL_TRAIT) then
        local damage = getMartialBonusDamage(player, endurance)
        pcall(function() zombie:setHealth(zombie:getHealth() - damage) end)
        pcall(function()
            if Perks and Perks.SmallBlunt then
                player:getXp():AddXP(Perks.SmallBlunt, damage * 2)
            end
        end)
    end
end

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.registerZombieCollisionHandler(TRAIT_ID, onZombieCollision)
end

Events.OnNewGame.Add(onNewGame)
