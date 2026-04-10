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
-- Multi-zombie suppression (the battering-ram freeze fix):
--   The PRIMARY freeze cause is BumpedState never exiting. BumpedState.enter()
--   sets BumpDone=false. The animation state machine holds the player in the
--   stagger animation until BumpDone becomes true. While in BumpedState,
--   doDeferredMovement() drives position from animation root motion (which
--   yields zero forward movement), so the player is physically frozen even if
--   blockMovement is cleared per tick.
--   Fix: force BumpDone=true and animation completion variables (BumpAnimFinished,
--   BumpFallAnimFinished) on BOTH the initial callback tick and every suppression
--   tick. This triggers BumpedState.exit() during stateMachine.update().
--   Secondary: proactively knock down nearby standing zombies during suppression
--   to prevent separate() from re-bumping with different zombies.
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
-- for enough ticks that the player clears the zombie's collision radius.
--
-- ROOT CAUSE OF THE FREEZE (verified from decompiled B42 Java source):
--   BumpedState.enter() sets BumpDone=false.  The animation state machine
--   keeps the player IN BumpedState until BumpDone becomes true (set by an
--   animation event that fires when the stagger/trip animation finishes).
--   While in BumpedState, doDeferredMovement() (line 2076 in IsoPlayer.java)
--   drives position from the ANIMATION, not from input. The bump animation
--   yields zero forward motion, so the player is physically frozen even if
--   blockMovement is cleared.
--
--   Our callbacks clear bumpType/bumpFall/blockMovement, but BumpDone is
--   never set to true because the animation never reaches its normal end.
--   Result: BumpedState never exits → permanent freeze.
--
-- Fix: On the initial callback tick AND every suppression tick, we force
--   BumpDone=true plus the animation completion variables. This tells the
--   animation state machine the bump is done, triggering the exit transition.
--   BumpedState.exit() clears bumpedChr, so we re-assert the guard each
--   tick during suppression to prevent separate() from re-bumping.
--
-- Secondary defense (multi-zombie): separate() iterates ALL nearby objects
--   and bumps with each zombie where getBumpedChr() != obj. We proactively
--   knock down all standing zombies in collision range to prevent this.
local BUMP_SUPPRESSION_TICKS = 30

-- Collision range: player width (0.3) + zombie width (0.3) = 0.6 tiles.
-- Slightly generous to catch zombies that separate() would trigger next tick.
local COLLISION_RANGE = 0.7

--- Knock down every standing zombie within collision range of the player.
--- Called during suppression to prevent separate() from triggering new bumps.
--- Returns the number of zombies knocked down.
local function knockNearbyStandingZombies(player)
    local sq = player:getCurrentSquare()
    if not sq then return 0 end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local cell = getCell()
    if not cell then return 0 end
    local sqX, sqY, sqZ = sq:getX(), sq:getY(), sq:getZ()
    local count = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkSq = cell:getGridSquare(sqX + dx, sqY + dy, sqZ)
            if checkSq then
                local objects = checkSq:getMovingObjects()
                for j = 0, objects:size() - 1 do
                    local obj = objects:get(j)
                    if obj ~= player and isZombie(obj) then
                        local ox, oy, oz = obj:getX(), obj:getY(), obj:getZ()
                        if math.abs(pz - oz) <= 0.3 then
                            local ddx = px - ox
                            local ddy = py - oy
                            local dist = math.sqrt(ddx * ddx + ddy * ddy)
                            if dist < COLLISION_RANGE then
                                pcall(function() obj:knockDown(true) end)
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return count
end

local function onPlayerUpdate(player)
    if not player then return end
    local md = player:getModData()

    -- Bump suppression: clear bump flags each tick, proactively knock down
    -- nearby zombies to prevent separate() from re-triggering bumps, and
    -- fire callbacks for any new zombie bump that slipped through.
    local suppress = md.UT_bumpSuppress or 0
    if suppress > 0 then
        md.UT_bumpSuppress = suppress - 1

        -- If separate() bumped us with a NEW zombie since last tick,
        -- fire callbacks so traits can handle it (knockdown, endurance, etc.)
        if player:isBumped() then
            local newZombie = player:getBumpedChr()
            if newZombie and isZombie(newZombie) and newZombie ~= md.UT_bumpGuardZombie then
                for _, fn in pairs(UTCore._zombieCollisionCallbacks) do
                    pcall(fn, player, newZombie)
                end
                md.UT_bumpGuardZombie = newZombie
                md.UT_bumpSuppress = BUMP_SUPPRESSION_TICKS  -- reset timer
            end
        end

        -- Proactive: knock down any standing zombie in collision range
        -- so separate() finds nothing to bump with when it runs later
        knockNearbyStandingZombies(player)

        -- Clear all bump fields and force BumpedState to exit.
        -- BumpDone + animation variables tell the animation state machine
        -- the bump is complete → triggers exit transition on next
        -- stateMachine.update() (runs AFTER OnPlayerUpdate + separate()).
        player:setBumpType("")
        player:setBumpFall(false)
        pcall(function() player:setBlockMovement(false) end)
        pcall(function() player:setBumpDone(true) end)
        pcall(function() player:setVariable("BumpAnimFinished", true) end)
        pcall(function() player:setVariable("BumpFallAnimFinished", true) end)

        -- Always re-assert guard zombie (not just when nil — separate()
        -- overwrites bumpedChr to the new zombie but we need our guard)
        local guardZombie = md.UT_bumpGuardZombie
        if guardZombie then
            pcall(function() player:setBumpedChr(guardZombie) end)
        end

        md.UT_prevBumped = false
        return
    else
        -- Suppression just expired: clean up stored zombie reference
        md.UT_bumpGuardZombie = nil
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
        md.UT_bumpGuardZombie = bumpedChr

        -- CRITICAL: Force BumpedState to exit. Without this, the animation
        -- state machine keeps the player stuck in BumpedState forever because
        -- BumpDone is still false (enter() set it, animation never finished).
        -- doDeferredMovement() drives position from animation — the bump
        -- animation yields zero motion — so the player is physically frozen.
        pcall(function() player:setBumpDone(true) end)
        pcall(function() player:setVariable("BumpAnimFinished", true) end)
        pcall(function() player:setVariable("BumpFallAnimFinished", true) end)

        -- Immediately knock down nearby zombies so separate() (which runs
        -- AFTER OnPlayerUpdate in the same tick) finds no standing targets
        knockNearbyStandingZombies(player)
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
