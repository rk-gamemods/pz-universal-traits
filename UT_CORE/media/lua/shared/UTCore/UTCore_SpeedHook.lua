-- UTCore_SpeedHook.lua
-- Applies the aggregated UT_speedMod to player movement by scaling the engine's
-- pending animation delta (nextX/nextY), NOT by rewriting absolute position.
--
-- ==================== ENGINE CONTRACT ====================
-- This hook depends on PZ's IsoMovingObject frame pipeline:
--
--   1. preupdate()          → nextX = x  (reset pending target)
--   2. doDeferredMovement() → nextX += animDelta  (animation writes here)
--   3. update()             → OnPlayerMove fires  ★ THIS HOOK RUNS HERE
--   4. postupdate()         → applies dx = nextX - x, commits into x
--
-- We read the pending delta (nextX - x) that doDeferredMovement() wrote,
-- scale it by (1 + UT_speedMod), and write the result back via setNextX().
--
-- CRITICAL: we use setNextX/setNextY, NOT setX/setY.
--   setX()     → clobbers x, nextX, AND scriptNextX (destroys pending movement)
--   setNextX() → only sets nextX (preserves x and scriptNextX)
--
-- This lets postupdate() see a scaled delta and commit it normally, preserving
-- the engine's collision checking, animation pipeline, and compatibility with
-- other mods that also write to nextX.
--
-- ==================== WHY NOT setX/setY? ====================
-- The previous implementation used setX/setY to rewrite absolute position.
-- This created a position-pinning feedback loop:
--   - getX() returns stale pre-movement x
--   - setX() clobbers nextX to equal x (zero delta)
--   - postupdate() sees dx=0, player never moves
-- See research/movement-bug/proof/P011 for the full kill-mechanism proof.
--
-- ==================== TRAITS DON'T NEED TO KNOW ====================
-- Traits call UTCore.applySpeedModifier(player, amount, sourceId) once.
-- That writes into the modifier bucket system (UTCore_StatModifiers.lua).
-- This hook reads the aggregated UT_speedMod from moddata and applies it.
-- Traits never touch position, nextX, or the frame pipeline directly.
-- =================================================================

UTCore = UTCore or {}
UTCore._speedHookLifecycle = UTCore._speedHookLifecycle or {}
local state = UTCore._speedHookLifecycle
UTSpeedHookLifecycle = state

if state.legacyRelaunchRequired and not state.dispatcher then
    return
end

local legacyHandler = state.onPlayerMove or UTCore._speedHookHandler
if legacyHandler and not state.dispatcher then
    state.implementation = legacyHandler
    state.onPlayerMove = legacyHandler
    state.legacyRelaunchRequired = true
    state.reloadRetry = {
        reason = "legacy anonymous handler requires a fresh process",
    }
    state.registration = {
        attempted = true,
        outcome = "legacy_registration_unknown",
        cardinality = "unknown",
    }
    return
end

-- Skip if pending animation delta exceeds this (teleport, map load, fast travel).
local TELEPORT_GUARD = 5.0

-- Per-frame movement cap in tiles. Prevents extreme jumps from corrupted moddata
-- or extreme modifier stacking. At 60 FPS, 1.5 tiles/frame = 90 tiles/sec
-- (~18x sprint). Will never trigger during normal gameplay.
local MAX_DELTA_PER_FRAME = 1.5

local function isFinite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function restorePendingTarget(player, originalX, originalY)
    -- B42 exposes only independent axis setters. Restore both axes independently
    -- so one hostile bridge call cannot prevent the other rollback attempt.
    pcall(player.setNextX, player, originalX)
    pcall(player.setNextY, player, originalY)

    -- One bounded verification retry covers transient bridge failures. A hostile
    -- receiver that persistently rejects restoration cannot be made atomic from Lua.
    local xOk, currentX = pcall(player.getNextX, player)
    if not xOk or currentX ~= originalX then
        pcall(player.setNextX, player, originalX)
    end
    local yOk, currentY = pcall(player.getNextY, player)
    if not yOk or currentY ~= originalY then
        pcall(player.setNextY, player, originalY)
    end
end

local function applyPendingTarget(player, targetX, targetY)
    player:setNextX(targetX)
    player:setNextY(targetY)
end

local function onPlayerMove()
    local player = getPlayer()
    if not player then return end
    if type(player.isLocalPlayer) ~= "function"
        or type(player.getModData) ~= "function"
        or type(player.getX) ~= "function"
        or type(player.getY) ~= "function"
        or type(player.getNextX) ~= "function"
        or type(player.getNextY) ~= "function"
        or type(player.setNextX) ~= "function"
        or type(player.setNextY) ~= "function"
        or not player:isLocalPlayer() then
        return
    end

    local md = player:getModData()
    if type(md) ~= "table" then return end
    local mod = md["UT_speedMod"]

    -- No valid speed modifier active means there is nothing to do.
    -- characters without speed traits (UT_fast, UT_pacer, UT_gimp, etc.).
    if not isFinite(mod)
        or mod < -0.75
        or mod > 1.0
        or mod == 0 then
        return
    end

    -- Read the pending movement delta that doDeferredMovement() accumulated
    -- into nextX/nextY during this frame's update() phase.
    local x = player:getX()
    local y = player:getY()
    local nextX = player:getNextX()
    local nextY = player:getNextY()
    if not isFinite(x) or not isFinite(y)
        or not isFinite(nextX) or not isFinite(nextY) then
        return
    end

    local dx = nextX - x
    local dy = nextY - y
    if not isFinite(dx) or not isFinite(dy) then return end

    -- No pending movement this frame — nothing to scale.
    if dx == 0 and dy == 0 then return end

    -- Teleport guard: skip if the pending delta is unreasonably large.
    -- This fires on map loads, debug teleports, or vehicle entry/exit.
    if math.abs(dx) > TELEPORT_GUARD or math.abs(dy) > TELEPORT_GUARD then return end

    -- Scale the pending delta by the speed modifier.
    -- factor > 1.0 → faster (e.g., UT_fast +0.3 → factor 1.3)
    -- factor < 1.0 → slower (e.g., UT_gimp -0.5 → factor 0.5)
    -- factor is always > 0 because UT_speedMod is clamped to [-0.75, +1.0]
    -- in UTCore_StatModifiers.lua, giving a factor range of [0.25, 2.0].
    local factor = 1.0 + mod
    local scaledDx = dx * factor
    local scaledDy = dy * factor
    if not isFinite(factor) or not isFinite(scaledDx) or not isFinite(scaledDy) then return end

    -- Per-frame delta cap: clamp the scaled delta so no single frame moves
    -- the player more than MAX_DELTA_PER_FRAME tiles in any direction.
    local squaredLength = scaledDx * scaledDx + scaledDy * scaledDy
    if not isFinite(squaredLength) then return end
    local len = math.sqrt(squaredLength)
    if not isFinite(len) then return end
    if len > MAX_DELTA_PER_FRAME then
        local scale = MAX_DELTA_PER_FRAME / len
        if not isFinite(scale) then return end
        scaledDx = scaledDx * scale
        scaledDy = scaledDy * scale
        if not isFinite(scaledDx) or not isFinite(scaledDy) then return end
    end

    -- Write back to nextX/nextY ONLY.
    -- setNextX() only sets the nx field — it does NOT clobber x or scriptNextX.
    -- postupdate() will then see the scaled delta and commit it into x normally.
    local targetX = x + scaledDx
    local targetY = y + scaledDy
    if not isFinite(targetX) or not isFinite(targetY) then return end

    local applied = pcall(applyPendingTarget, player, targetX, targetY)
    if not applied then
        restorePendingTarget(player, nextX, nextY)
    end
end

state.implementation = onPlayerMove
state.onPlayerMove = onPlayerMove
state.reloadRetry = nil

if not state.dispatcher then
    state.dispatcher = function(...)
        local implementation = state.implementation
        if implementation then
            return implementation(...)
        end
    end
end

if state.registration and state.registration.attempted then
    return
end

local event = Events and Events.OnPlayerMove or nil
local add = event and event.Add or nil
if not add then
    state.registration = {
        attempted = false,
        outcome = "not_attempted",
        reason = "OnPlayerMove.Add unavailable",
        cardinality = "unknown",
    }
    return
end

local ok, result = pcall(add, state.dispatcher)
local outcome = "call_completed"
local registrationError = nil
if not ok then
    outcome = "outcome_unknown"
    registrationError = tostring(result)
elseif result == false then
    outcome = "outcome_unknown"
    registrationError = "explicit false"
end
state.registration = {
    attempted = true,
    callCompleted = ok,
    outcome = outcome,
    returnValue = ok and result or nil,
    error = registrationError,
    cardinality = "unknown",
}
