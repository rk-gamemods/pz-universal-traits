-- UTCore_ZombieCollisionHook.lua
-- Zombie collision detection and trait callback dispatch.
--
-- STRATEGY (v4 — "knockdown only, never touch player bump state"):
--   Previous versions (v1–v3b) tried to PREVENT BumpedState entry by
--   calling player:setBumpedChr(zombie) each tick. This was architecturally
--   broken because:
--     1. The guard only protects against ONE zombie — separate() checks ALL
--        moving objects, so zombie B can trigger a bump while A is guarded.
--     2. Clearing setBumpedChr during an active BumpedState corrupts the
--        state machine — BumpDone never fires → permanent freeze.
--     3. Tick ordering: zombies can enter range between OnPlayerUpdate and
--        separate(), bypassing the guard entirely.
--
--   v4 removes ALL player bump state manipulation. The hook ONLY:
--     - Detects nearby zombies while the player is running/sprinting
--     - Fires trait callbacks (e.g. knockDown) when a zombie enters range
--     - Tracks per-zombie dedup so callbacks fire once per encounter
--   Trait callbacks operate on ZOMBIES only (knockDown, setStaggerBack).
--   Phantom/crawler bumps are handled by UTCore_BlockMovementGuard.lua,
--   which clears stuck BumpedState within 1 tick when the bumped character
--   is nil, dead, or crawling.
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
UTCore._zombieCollisionCallbackCount = UTCore._zombieCollisionCallbackCount or 0

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
    if UTCore._zombieCollisionCallbacks[traitId] == nil and handlerFn ~= nil then
        UTCore._zombieCollisionCallbackCount = UTCore._zombieCollisionCallbackCount + 1
    end
    UTCore._zombieCollisionCallbacks[traitId] = handlerFn
end

function UTCore.unregisterZombieCollisionHandler(traitId)
    if UTCore._zombieCollisionCallbacks[traitId] ~= nil then
        UTCore._zombieCollisionCallbackCount = UTCore._zombieCollisionCallbackCount - 1
        if UTCore._zombieCollisionCallbackCount < 0 then
            UTCore._zombieCollisionCallbackCount = 0
        end
    end
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

local function onPlayerUpdate(player, tick)
    -- No handlers registered → nothing to do (O(1) counter check)
    if UTCore._zombieCollisionCallbackCount == 0 then return end

    -- Only active while running or sprinting (walking doesn't trigger bumps)
    local sprinting = tick and tick.isSprinting or player:isSprinting()
    local running   = tick and tick.isRunning   or player:isRunning()
    if not sprinting and not running then
        -- Clear handled set when player stops (fresh start on next run)
        local md = tick and tick.modData or player:getModData()
        if md.UT_handledZombies then
            md.UT_handledZombies = nil
        end
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

    local px = tick and tick.x or player:getX()
    local py = tick and tick.y or player:getY()
    local pz = tick and tick.z or player:getZ()
    local sqX, sqY, sqZ = sq:getX(), sq:getY(), sq:getZ()
    local md = tick and tick.modData or player:getModData()
    local prevHandled = md.UT_handledZombies or {}
    local newHandled = {}
    local foundNearby = false

    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkSq = cell:getGridSquare(sqX + dx, sqY + dy, sqZ)
            if checkSq then
                local objects = checkSq:getMovingObjects()
                for j = 0, objects:size() - 1 do
                    local obj = objects:get(j)
                    if obj ~= player and isZombie(obj) and not obj:isDead() then
                        local ox, oy, oz = obj:getX(), obj:getY(), obj:getZ()
                        if math.abs(pz - oz) <= 0.3 then
                            local ddx = px - ox
                            local ddy = py - oy
                            local dist = math.sqrt(ddx * ddx + ddy * ddy)
                            if dist < COLLISION_RANGE then
                                foundNearby = true
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

    if foundNearby and UTSmoke and UTSmoke.record then
        UTSmoke.record("combat.zombie-collision", "preempt")
    end
end

if UTCore.registerCoreHandler then
    UTCore.registerCoreHandler("ZombieCollisionHook", onPlayerUpdate, { priority = 0 })
else
    if Events and Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
end

---------------------------------------------------------------------------
-- Auto-registration from declarations
---------------------------------------------------------------------------

-- OnCreatePlayer fires on BOTH new game and save load.
-- Registers collision handlers for every declared trait the player actually has.
local function onCreatePlayer(_playerIndex, player)
    if not player then return end
    for traitId, fn in pairs(_declarations) do
        if UTCore.hasTrait(player, traitId) then
            if UTCore._zombieCollisionCallbacks[traitId] == nil then
                UTCore._zombieCollisionCallbackCount = UTCore._zombieCollisionCallbackCount + 1
            end
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
                UTCore._zombieCollisionCallbackCount = UTCore._zombieCollisionCallbackCount + 1
            end
        end
    end

    -- Resync the counter from ground truth: drift-safe against any external mutation.
    local n = 0
    for _ in pairs(UTCore._zombieCollisionCallbacks) do n = n + 1 end
    UTCore._zombieCollisionCallbackCount = n
end

Events.EveryOneMinute.Add(integrityCheck)
