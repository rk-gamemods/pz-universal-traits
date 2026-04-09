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
-- Trait API (preferred):
--   UTCore.declareZombieCollisionHandler(traitId, fn)
--     Called at file-load time. Declares intent — the handler is automatically
--     registered via OnCreatePlayer when the player has the trait, and
--     self-healed by a periodic integrity check if ever cleared.
--
-- Low-level API (UTCore internal use):
--   UTCore.registerZombieCollisionHandler(traitId, fn)
--   UTCore.unregisterZombieCollisionHandler(traitId)

UTCore = UTCore or {}
UTCore._zombieCollisionCallbacks = UTCore._zombieCollisionCallbacks or {}

-- Declarations live in a local upvalue: trait files add to it via the public
-- declare function, but nothing can accidentally wipe it by clearing a UTCore field.
local _declarations = {}

--- Declare a zombie collision handler for a trait. Call once at file-load time.
--- The handler is automatically registered on OnCreatePlayer (new game + save load)
--- and re-registered by the integrity check if the callbacks table is ever cleared.
---   traitId:   full trait ID, e.g. "UniversalTraits:UT_batteringram"
---   handlerFn: function(player, zombie) — called once per collision rising edge
function UTCore.declareZombieCollisionHandler(traitId, handlerFn)
    _declarations[traitId] = handlerFn
end

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

-- After a collision callback handles a bump, suppress the engine's re-bump
-- for several ticks. Without this, the engine re-detects the overlap every
-- tick, re-enters BumpedState, and re-blocks movement before the player can
-- escape — causing a permanent freeze.
local BUMP_SUPPRESSION_TICKS = 8

local function onPlayerUpdate(player)
    if not player then return end
    local md = player:getModData()

    -- Bump suppression: keep clearing the engine's re-bump each tick so
    -- the player can move through the zombie after a charge collision.
    -- CRITICAL: Do NOT clear bumpedChr — the engine uses it as a re-bump
    -- guard in separate() (line 1222: getBumpedChr() != obj). Preserving it
    -- prevents the same zombie from re-triggering a bump. For different
    -- zombies in a cluster, suppression clears the flags each tick until
    -- the player sprints through.
    local suppress = md.UT_bumpSuppress or 0
    if suppress > 0 then
        md.UT_bumpSuppress = suppress - 1
        player:setBumpType("")
        player:setBumpFall(false)
        pcall(function() player:setBlockMovement(false) end)
        md.UT_prevBumped = false
        return
    end

    local wasBumped = md.UT_prevBumped or false
    local nowBumped = player:isBumped()

    md.UT_prevBumped = nowBumped

    -- Only fire on the rising edge (false → true transition)
    if not (nowBumped and not wasBumped) then return end

    local bumpedChr = player:getBumpedChr()
    if not isZombie(bumpedChr) then return end

    if UTSmoke and UTSmoke.record then
        UTSmoke.record("combat.zombie-collision", "bump")
    end

    local anyHandled = false
    for _, fn in pairs(UTCore._zombieCollisionCallbacks) do
        local handled = fn(player, bumpedChr)
        if handled then anyHandled = true end
    end

    -- Activate bump suppression if any callback handled the collision
    if anyHandled then
        md.UT_bumpSuppress = BUMP_SUPPRESSION_TICKS
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

---------------------------------------------------------------------------
-- Auto-registration from declarations
---------------------------------------------------------------------------

-- OnCreatePlayer fires on BOTH new game and save load.
-- Registers collision handlers for every declared trait the player actually has.
local function onCreatePlayer(_playerIndex, player)
    if not player then return end
    for traitId, fn in pairs(_declarations) do
        if UTCore.hasTrait(player, traitId) then
            UTCore._zombieCollisionCallbacks[traitId] = fn
        end
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)

-- Integrity check: every 10 game-minutes (~10 real seconds), verify that
-- declared handlers are still present in the live callbacks table.
-- Re-registers any missing ones. Cost: one pairs() over declarations
-- (typically < 5 entries) + one hasTrait + one table lookup each.
local _integrityCounter = 0

local function integrityCheck()
    _integrityCounter = _integrityCounter + 1
    if _integrityCounter < 10 then return end
    _integrityCounter = 0

    local player = getPlayer()
    if not player then return end

    for traitId, fn in pairs(_declarations) do
        if UTCore.hasTrait(player, traitId) then
            if not UTCore._zombieCollisionCallbacks[traitId] then
                UTCore._zombieCollisionCallbacks[traitId] = fn
            end
        end
    end
end

Events.EveryOneMinute.Add(integrityCheck)
