-- UTCore_ZombieCollisionHook.lua
-- Preemptive bump prevention for zombie collision traits.
--
-- STRATEGY (v3 — "work WITH the engine"):
--   TWO-LAYER prevention stops BumpedState from ever being entered:
--   1. Knockdown: callbacks knockDown() zombies on first contact → knocked-down
--      zombies don't trigger the bump condition in separate().
--   2. setBumpedChr guard: we call player:setBumpedChr(nearestZombie) each tick
--      when zombies are nearby. separate() checks getBumpedChr() != obj and
--      SKIPS the bump when they match → prevents re-bump from the guarded zombie.
--
-- HOW IT WORKS (verified from decompiled B42 source):
--   The engine's bump condition in IsoMovingObject.separate() (line ~1224):
--     bump = true when:
--       WalkSpeed > 0.2 AND runningTime > 0.5 AND getBumpedChr() != obj
--
--   We satisfy the third clause: setBumpedChr(zombie) makes getBumpedChr() == obj
--   → bump stays false. Combined with knockdown, the engine never enters BumpedState.
--
-- KAHLUA CONSTRAINT:
--   Kahlua VM cannot WRITE Java public fields from Lua (tableSet on a Java proxy
--   throws "attempted index of non-table"). This rules out setting runningTime
--   or walkSpeed directly. Java METHOD calls (setBumpedChr, knockDown) work fine.
--
-- WHY PREVIOUS APPROACHES FAILED:
--   v1: Cleared bumpType/bumpFall/blockMovement but BumpDone stayed false →
--       BumpedState never exited → animation drove zero-movement → freeze.
--   v2: Forced BumpDone=true + animation variables every tick → still froze
--       because the full BumpedState lifecycle (complexity 65 in separate())
--       has too many interdependent paths to manage from Lua.
--   v3a: Tried to zero runningTime directly — Kahlua can't write Java fields.
--   v3b (this): Uses method calls only. knockDown + setBumpedChr.
--
-- CALLBACK TRIGGER:
--   Callbacks fire when a NEW zombie enters collision range while the player
--   is running/sprinting, not on bump rising edge. Per-zombie dedup prevents
--   callbacks from re-firing while the same zombie stays in range.
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

-- Collision range: player width (0.3) + zombie width (0.3) = 0.6 tiles.
-- Slightly generous to catch zombies that separate() would check next.
local COLLISION_RANGE = 0.7

---------------------------------------------------------------------------
-- Debug logging
---------------------------------------------------------------------------
-- Toggle at runtime:
--   UTCore.setCollisionDebug(true)     — global toggle
--   player:getModData().UT_DEBUG_COLLISIONS = true  — per-save toggle

function UTCore.setCollisionDebug(enabled)
    UTCore._debugCollisions = enabled ~= false
    print("[UTCore:ZCollision] Debug " .. (UTCore._debugCollisions and "ON" or "OFF"))
end

local function dbg(msg)
    if not UTCore._debugCollisions then return end
    print("[UTCore:ZCollision] " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Declare a zombie collision handler for a trait. Call once at file-load time.
--- The handler is automatically registered on OnCreatePlayer (new game + save load)
--- and re-registered by the integrity check if the callbacks table is ever cleared.
---   traitId:   full trait ID, e.g. "UniversalTraits:UT_batteringram"
---   handlerFn: function(player, zombie) — called when zombie enters collision range
function UTCore.declareZombieCollisionHandler(traitId, handlerFn)
    _declarations[traitId] = handlerFn
end

function UTCore.registerZombieCollisionHandler(traitId, handlerFn)
    UTCore._zombieCollisionCallbacks[traitId] = handlerFn
end

function UTCore.unregisterZombieCollisionHandler(traitId)
    UTCore._zombieCollisionCallbacks[traitId] = nil
end

---------------------------------------------------------------------------
-- Zombie detection
---------------------------------------------------------------------------

-- Use PZ's instanceof() for a clean Java class check — no exceptions thrown.
-- The pcall(chr:isAlwaysKnockedDown) approach logged Java RuntimeExceptions
-- for every non-zombie MovingObject even though pcall caught them in Lua.
local function isZombie(chr)
    if not chr then return false end
    return instanceof(chr, "IsoZombie")
end

---------------------------------------------------------------------------
-- Per-tick update
---------------------------------------------------------------------------

local function onPlayerUpdate(player)
    if not player then return end
    if player:isDead() then return end
    if player:getVehicle() ~= nil then return end

    -- No handlers registered → nothing to do
    local hasHandlers = false
    for _ in pairs(UTCore._zombieCollisionCallbacks) do
        hasHandlers = true
        break
    end
    if not hasHandlers then return end

    -- Only active while running or sprinting (walking doesn't trigger bumps)
    local sprinting = player:isSprinting()
    local running = player:isRunning()
    if not sprinting and not running then
        -- Clear handled set when player stops (fresh start on next run)
        local md = player:getModData()
        if md.UT_handledZombies then md.UT_handledZombies = nil end
        -- One-time cleanup of old moddata from previous suppression approach
        if md.UT_bumpSuppress then
            md.UT_bumpSuppress = nil
            md.UT_bumpGuardZombie = nil
            md.UT_prevBumped = nil
            dbg("Cleaned up old suppression moddata")
        end
        return
    end

    local sq = player:getCurrentSquare()
    if not sq then return end
    local cell = getCell()
    if not cell then return end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local sqX, sqY, sqZ = sq:getX(), sq:getY(), sq:getZ()
    local md = player:getModData()
    local prevHandled = md.UT_handledZombies or {}
    local newHandled = {}
    local foundNearby = false
    local nearestZombie = nil
    local nearestDist = COLLISION_RANGE

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
                                foundNearby = true
                                if dist < nearestDist then
                                    nearestDist = dist
                                    nearestZombie = obj
                                end
                                local zKey = tostring(obj)
                                newHandled[zKey] = true

                                -- Fire callbacks for NEW zombies entering range
                                if not prevHandled[zKey] then
                                    dbg("Zombie in range: " .. zKey
                                        .. " dist=" .. string.format("%.2f", dist)
                                        .. (sprinting and " [SPRINT]" or " [RUN]"))
                                    for traitId, fn in pairs(UTCore._zombieCollisionCallbacks) do
                                        local ok, err = pcall(fn, player, obj)
                                        if not ok then
                                            dbg("Callback ERROR [" .. traitId .. "]: " .. tostring(err))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    md.UT_handledZombies = newHandled

    -- ===== PREEMPTIVE BUMP PREVENTION =====
    -- Kahlua VM cannot write Java public fields (runningTime, walkSpeed) from
    -- Lua — tableSet on a Java proxy throws "attempted index of non-table".
    -- Instead we use the engine's own re-bump guard: setBumpedChr(zombie).
    -- separate() checks getBumpedChr() != obj → skips bump for matching zombie.
    -- Combined with knockdown (callback knocks zombies down on contact),
    -- this prevents BumpedState entry → no stagger/trip/freeze.
    -- setBumpedChr self-heals: BumpedState.exit() clears it when appropriate.
    if foundNearby and nearestZombie then
        local ok, err = pcall(function()
            player:setBumpedChr(nearestZombie)
            dbg("setBumpedChr → " .. tostring(nearestZombie)
                .. " dist=" .. string.format("%.2f", nearestDist))
        end)
        if not ok then
            dbg("FAILED setBumpedChr: " .. tostring(err))
        end
    end

    if foundNearby and UTSmoke and UTSmoke.record then
        UTSmoke.record("combat.zombie-collision", "preempt")
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
