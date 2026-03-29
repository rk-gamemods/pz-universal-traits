-- UTCore_ZombieCollisionHook.lua
-- Detects the rising edge of player:isBumped() with a zombie as the bump source.
-- Fires registered callbacks with (player, zombie), letting traits intercept the
-- collision before the native stagger/fall animation locks in.
--
-- What "zombie collision" means (verified against IsoMovingObject.java, B42):
--   When the player physically overlaps a zombie by more than the threshold, the engine
--   calls setBumpedChr(zombie), setBumpType(...), then reportEvent("wasBumped").
--   This transitions the player into BumpedState, which plays the stagger or trip
--   animation and optionally blocks movement.
--   player:isBumped() == true while bumpType is non-empty.
--   player:getBumpedChr() holds the zombie that caused the bump.
--
-- Cancelling a collision from inside a callback:
--   player:setBumpType("")   → clears isBumped(); disables stagger movement-block
--   player:setBumpFall(false) → prevents the trip/fall animation
--
-- API:
--   UTCore.registerZombieCollisionHandler(traitId, fn)
--     fn(player, zombie) — called once per collision (rising edge only)
--   UTCore.unregisterZombieCollisionHandler(traitId)

UTCore = UTCore or {}
UTCore._zombieCollisionCallbacks = UTCore._zombieCollisionCallbacks or {}

function UTCore.registerZombieCollisionHandler(traitId, handlerFn)
    UTCore._zombieCollisionCallbacks[traitId] = handlerFn
end

function UTCore.unregisterZombieCollisionHandler(traitId)
    UTCore._zombieCollisionCallbacks[traitId] = nil
end

-- isAlwaysKnockedDown() is declared on IsoZombie, not on IsoGameCharacter or IsoPlayer.
-- A successful pcall confirms the bumped entity is a zombie.
local function isZombie(chr)
    if not chr then return false end
    local ok = pcall(function() chr:isAlwaysKnockedDown() end)
    return ok
end

local function onPlayerUpdate(player)
    if not player then return end
    local md = player:getModData()

    local wasBumped = md.UT_prevBumped or false
    local nowBumped = player:isBumped()

    md.UT_prevBumped = nowBumped

    -- Only fire on the rising edge (false → true transition)
    if not (nowBumped and not wasBumped) then return end

    local bumpedChr = player:getBumpedChr()
    if not isZombie(bumpedChr) then return end

    for _, fn in pairs(UTCore._zombieCollisionCallbacks) do
        fn(player, bumpedChr)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
